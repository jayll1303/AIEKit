# TensorRT-LLM Serving Configuration

Detailed reference cho Triton backend setup, in-flight batching, paged KV cache, streaming, và benchmarking với TensorRT-LLM engines.

## Triton Backend Setup (tensorrtllm_backend)

TensorRT-LLM engines được serve production qua Triton Inference Server với `tensorrtllm_backend`.

### Directory Structure

```
model_repository/
├── preprocessing/
│   ├── config.pbtxt
│   └── 1/
│       └── model.py
├── tensorrt_llm/
│   ├── config.pbtxt
│   └── 1/
│       ├── config.json        # copy từ engine build output
│       ├── rank0.engine       # copy từ engine build output
│       └── ...
├── postprocessing/
│   ├── config.pbtxt
│   └── 1/
│       └── model.py
└── ensemble/
    └── config.pbtxt
```

### Quick Setup với fill_template.py

```bash
# Clone tensorrtllm_backend repo
git clone https://github.com/triton-inference-server/tensorrtllm_backend.git
cd tensorrtllm_backend

# Fill config templates
python3 tools/fill_template.py -i all_models/inflight_batcher_llm/ \
  tokenizer_dir:/models/Llama-3.1-8B-Instruct \
  engine_dir:/engines/llama-8b/engine \
  max_batch_size:64 \
  batching_type:inflight \
  decoupled_mode:true \
  max_queue_delay_microseconds:100
```

**Validate:** Mỗi thư mục trong `model_repository/` phải có `config.pbtxt` hợp lệ. Check `engine_dir` path trong `tensorrt_llm/config.pbtxt` trỏ đúng.

### Launch Triton Server

```bash
# Launch với model repository
docker run --gpus all --rm -it \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v /engines:/engines \
  -v /models:/models \
  -v $PWD/all_models/inflight_batcher_llm:/model_repository \
  nvcr.io/nvidia/tritonserver:24.07-trtllm-python-py3 \
  tritonserver --model-repository=/model_repository

# Hoặc nếu đã install local
tritonserver --model-repository=/model_repository
```

**Validate:** `curl -s http://localhost:8000/v2/health/ready` returns 200. `curl -s http://localhost:8000/v2/models` lists all 4 models (preprocessing, tensorrt_llm, postprocessing, ensemble).

### Triton config.pbtxt cho tensorrt_llm model

Key parameters trong `tensorrt_llm/config.pbtxt`:

```protobuf
parameters: {
  key: "gpt_model_type"
  value: { string_value: "inflight_fused_batching" }
}
parameters: {
  key: "gpt_model_path"
  value: { string_value: "/engines/llama-8b/engine" }
}
parameters: {
  key: "max_beam_width"
  value: { string_value: "1" }
}
parameters: {
  key: "batch_scheduler_policy"
  value: { string_value: "max_utilization" }
}
parameters: {
  key: "kv_cache_free_gpu_mem_fraction"
  value: { string_value: "0.85" }
}
parameters: {
  key: "enable_chunked_context"
  value: { string_value: "true" }
}
```

## In-Flight Batching Configuration

In-flight batching (IFB) cho phép requests mới join batch ngay khi có slot trống, không cần đợi cả batch hoàn thành. Đây là key feature cho high-throughput serving.

### Requirements

- Engine PHẢI được build với `--gpt_attention_plugin` (bắt buộc cho IFB)
- `batching_type` set thành `inflight` trong config

### Key Parameters

| Parameter | Default | Description |
|---|---|---|
| `batching_type` | `inflight` | `inflight` (recommended) hoặc `static` |
| `batch_scheduler_policy` | `max_utilization` | `max_utilization` (throughput) hoặc `guaranteed_no_evict` (latency) |
| `max_num_sequences` | auto | Max concurrent sequences. Bounded by engine's max_batch_size |
| `max_queue_delay_microseconds` | 0 | Delay trước khi schedule batch. Tăng → better batching, higher latency |
| `enable_chunked_context` | false | Chunk long prefills để không block decode. Recommended cho long context |

### Scheduler Policies

**max_utilization** (default, recommended cho throughput):
- Pack nhiều requests nhất có thể vào mỗi iteration
- Có thể evict (pause) requests nếu KV cache đầy
- Best cho high-concurrency workloads

**guaranteed_no_evict** (recommended cho latency-sensitive):
- Không bao giờ evict running requests
- Chỉ schedule request mới nếu guaranteed đủ KV cache
- Lower throughput nhưng predictable latency

```bash
# High throughput config
python3 tools/fill_template.py -i all_models/inflight_batcher_llm/ \
  batching_type:inflight \
  batch_scheduler_policy:max_utilization \
  max_queue_delay_microseconds:1000 \
  enable_chunked_context:true

# Low latency config
python3 tools/fill_template.py -i all_models/inflight_batcher_llm/ \
  batching_type:inflight \
  batch_scheduler_policy:guaranteed_no_evict \
  max_queue_delay_microseconds:0 \
  enable_chunked_context:false
```

## Paged KV Cache Tuning

Paged KV cache quản lý memory theo pages (giống virtual memory), giảm fragmentation và tăng concurrent requests.

### Key Parameters

| Parameter | Default | Description |
|---|---|---|
| `kv_cache_free_gpu_mem_fraction` | 0.85 | Fraction of free GPU memory dành cho KV cache |
| `kv_cache_host_memory_bytes` | 0 | CPU memory cho KV cache offload (bytes) |
| `kv_cache_onboard_blocks` | true | Pre-allocate KV cache blocks on GPU |
| `enable_kv_cache_reuse` | false | Reuse KV cache cho shared prefixes (prompt caching) |

### Tuning Guidelines

```
KV cache memory = Free GPU VRAM × kv_cache_free_gpu_mem_fraction
```

**Tăng `kv_cache_free_gpu_mem_fraction`** (0.85 → 0.95):
- Nhiều concurrent requests hơn
- Risk: OOM nếu model + runtime overhead lớn

**Giảm `kv_cache_free_gpu_mem_fraction`** (0.85 → 0.70):
- Ít concurrent requests
- Safer, ít risk OOM

**Enable KV cache reuse** cho chatbot/RAG (shared system prompt):

```bash
python3 tools/fill_template.py -i all_models/inflight_batcher_llm/ \
  enable_kv_cache_reuse:true
```

**Enable CPU offload** khi GPU VRAM hạn chế:

```bash
python3 tools/fill_template.py -i all_models/inflight_batcher_llm/ \
  kv_cache_host_memory_bytes:10737418240  # 10 GB CPU memory
```

### VRAM Budget Estimation

```
Total GPU VRAM usage:
  = Model weights (fixed)
  + KV cache (dynamic, controlled by kv_cache_free_gpu_mem_fraction)
  + Runtime overhead (~500MB-1GB)

Example: Llama-3.1-8B FP16 on 24GB GPU
  Model weights: ~16 GB
  Available for KV cache: (24 - 16 - 1) × 0.85 ≈ 5.95 GB
  Approx concurrent requests: depends on max_seq_len
```

## Streaming Responses

TensorRT-LLM + Triton support streaming qua gRPC decoupled mode.

### Enable Streaming

Trong `ensemble/config.pbtxt`:

```protobuf
model_transaction_policy {
  decoupled: true
}
```

Trong `fill_template.py`:

```bash
python3 tools/fill_template.py -i all_models/inflight_batcher_llm/ \
  decoupled_mode:true
```

### Client Code (Streaming)

```python
import tritonclient.grpc as grpcclient
import numpy as np

client = grpcclient.InferenceServerClient("localhost:8001")

# Prepare inputs
text_input = grpcclient.InferInput("text_input", [1, 1], "BYTES")
text_input.set_data_from_numpy(
    np.array([["What is TensorRT-LLM?"]], dtype=object)
)

max_tokens = grpcclient.InferInput("max_tokens", [1, 1], "INT32")
max_tokens.set_data_from_numpy(np.array([[256]], dtype=np.int32))

stream_output = grpcclient.InferInput("stream", [1, 1], "BOOL")
stream_output.set_data_from_numpy(np.array([[True]], dtype=bool))

# Streaming callback
def callback(result, error):
    if error:
        print(f"Error: {error}")
    else:
        output = result.as_numpy("text_output")
        print(output[0].decode("utf-8"), end="", flush=True)

# Send request
client.start_stream(callback=callback)
client.async_stream_infer(
    model_name="ensemble",
    inputs=[text_input, max_tokens, stream_output],
)
client.stop_stream()
```

### HTTP Streaming (SSE)

```bash
curl -X POST http://localhost:8000/v2/models/ensemble/generate_stream \
  -H "Content-Type: application/json" \
  -d '{
    "text_input": "Explain TensorRT-LLM in one paragraph.",
    "max_tokens": 256,
    "stream": true
  }'
```

## Benchmarking với trtllm-bench

### Basic Throughput Benchmark

```bash
# Benchmark engine throughput
python benchmarks/python/benchmark.py \
  --engine_dir /engines/llama-8b/engine \
  --tokenizer_dir /models/Llama-3.1-8B-Instruct \
  --dataset_type synthetic \
  --num_requests 100 \
  --max_input_len 512 \
  --max_output_len 256
```

### trtllm-bench (newer versions)

```bash
# Prepare dataset
trtllm-bench --model llama \
  prepare_dataset \
  --dataset_type synthetic \
  --num_requests 1000 \
  --max_input_len 512 \
  --max_output_len 256 \
  --output dataset.json

# Run throughput benchmark
trtllm-bench --model llama \
  throughput \
  --engine_dir /engines/llama-8b/engine \
  --dataset dataset.json \
  --num_requests 500
```

### Key Metrics

| Metric | Description | Target |
|---|---|---|
| Throughput (tokens/sec) | Total output tokens per second | Higher = better |
| Time to First Token (TTFT) | Latency from request to first token | < 100ms cho chat |
| Inter-Token Latency (ITL) | Time between consecutive tokens | < 30ms cho streaming |
| Request throughput (req/sec) | Completed requests per second | Depends on workload |

### Benchmark Comparison Template

```bash
# FP16 baseline
trtllm-bench --model llama throughput \
  --engine_dir /engines/llama-8b-fp16/engine \
  --dataset dataset.json --num_requests 500

# FP8 comparison
trtllm-bench --model llama throughput \
  --engine_dir /engines/llama-8b-fp8/engine \
  --dataset dataset.json --num_requests 500

# So sánh: FP8 thường cho ~1.5-2x throughput vs FP16 trên Hopper
```

## NVIDIA TensorRT-LLM Dynamo (Preview)

TensorRT-LLM Dynamo là integration mới cho phép dùng TRT-LLM engines trong PyTorch workflow thông qua `torch.compile`.

### Overview

- Compile PyTorch models sang TensorRT engines tự động
- Không cần manual checkpoint conversion
- Đang ở preview stage — API có thể thay đổi

```python
import torch
import tensorrt_llm

# Dynamo integration (preview API)
# Cho phép torch.compile() tự động optimize với TensorRT
# Check TRT-LLM docs cho latest API
```

**Lưu ý:** Dynamo integration đang phát triển nhanh. Luôn check [TensorRT-LLM GitHub](https://github.com/NVIDIA/TensorRT-LLM) cho latest API và supported models.

## Troubleshooting Serving

```
Triton server không start?
├─ "Model not found" → Check model_repository structure, mỗi model cần config.pbtxt + version folder
├─ "Engine load failed" → Verify engine files exist, GPU architecture match
├─ Port conflict → Check 8000/8001/8002 không bị occupied
└─ GPU not visible → Verify --gpus all flag, check nvidia-smi trong container

Throughput thấp hơn expected?
├─ Check batching_type = inflight (không phải static)
├─ Check --gpt_attention_plugin đã enable khi build engine
├─ Tăng max_queue_delay_microseconds (100-1000μs) cho better batching
├─ Enable chunked_context cho long input sequences
└─ Check GPU utilization: nvidia-smi -l 1 (target > 80%)

Requests bị timeout?
├─ max_queue_delay quá cao → giảm xuống
├─ KV cache đầy → tăng kv_cache_free_gpu_mem_fraction hoặc giảm max_seq_len
├─ Batch scheduler evicting → switch sang guaranteed_no_evict
└─ Network bottleneck → check gRPC vs HTTP, prefer gRPC cho high throughput

Memory leak / VRAM tăng dần?
├─ KV cache reuse enabled nhưng cache không được free → restart server
├─ Check TRT-LLM version — older versions có known memory leaks
└─ Monitor với nvidia-smi -l 1, check VRAM trend over time
```

> **See also**: [triton-deployment](../../triton-deployment/SKILL.md) cho Triton server setup chi tiết, config.pbtxt reference, và ensemble pipeline patterns
