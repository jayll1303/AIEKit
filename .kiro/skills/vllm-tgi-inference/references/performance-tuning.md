# Performance Tuning

VRAM estimation, KV cache sizing, batch scheduling, throughput optimization, and latency profiling for vLLM and TGI deployments.

## VRAM Estimation

### Model Weight Memory

Estimate VRAM needed for model weights alone:

| Precision | Formula | 7B Model | 13B Model | 70B Model |
|---|---|---|---|---|
| FP32 | params × 4 bytes | ~28 GB | ~52 GB | ~280 GB |
| FP16 / BF16 | params × 2 bytes | ~14 GB | ~26 GB | ~140 GB |
| INT8 | params × 1 byte | ~7 GB | ~13 GB | ~70 GB |
| INT4 (GPTQ/AWQ) | params × 0.5 bytes | ~3.5 GB | ~6.5 GB | ~35 GB |

### Total VRAM Budget

```
Total VRAM = Model Weights + KV Cache + Activation Memory + Overhead

Where:
- Model Weights: See table above
- KV Cache: Depends on context length, batch size, model architecture
- Activation Memory: ~1-2 GB typical
- Overhead: ~0.5-1 GB (CUDA context, framework)
```

### KV Cache Memory Estimation

```
KV Cache per token = 2 × num_layers × num_kv_heads × head_dim × dtype_bytes

Example (Llama-3.1-8B, FP16):
  = 2 × 32 × 8 × 128 × 2 bytes
  = 131,072 bytes ≈ 0.125 MB per token

For 4096 context × 32 concurrent sequences:
  = 0.125 MB × 4096 × 32 ≈ 16 GB KV cache
```

### Quick VRAM Calculator

| Model | Precision | Max Context | Concurrent Seqs | Est. Total VRAM |
|---|---|---|---|---|
| 7B | FP16 | 4096 | 32 | ~22 GB |
| 7B | AWQ 4-bit | 4096 | 64 | ~12 GB |
| 7B | FP16 | 8192 | 16 | ~20 GB |
| 13B | FP16 | 4096 | 16 | ~34 GB |
| 13B | AWQ 4-bit | 4096 | 32 | ~16 GB |
| 70B | FP16 | 4096 | 8 | ~160 GB (multi-GPU) |
| 70B | AWQ 4-bit | 4096 | 16 | ~50 GB (multi-GPU) |

## KV Cache Sizing

### vLLM KV Cache Tuning

vLLM automatically allocates KV cache based on `--gpu-memory-utilization`:

```bash
# Default: 90% of GPU memory for model + KV cache
vllm serve model-id --gpu-memory-utilization 0.9

# Conservative: leave more headroom
vllm serve model-id --gpu-memory-utilization 0.8

# Aggressive: maximize KV cache (risk of OOM under load)
vllm serve model-id --gpu-memory-utilization 0.95
```

**Reducing KV cache pressure**:

```bash
# Limit context window
vllm serve model-id --max-model-len 4096  # Instead of model's full 128K

# Reduce concurrent sequences
vllm serve model-id --max-num-seqs 64  # Instead of default 256
```

### TGI KV Cache Tuning

TGI controls KV cache indirectly through token limits:

```bash
# Limit total tokens (input + output) per request
docker run ... --max-total-tokens 4096

# Limit concurrent requests
docker run ... --max-concurrent-requests 64

# Limit prefill batch size
docker run ... --max-batch-prefill-tokens 4096
```

## Batch Scheduling

### vLLM Continuous Batching

vLLM uses iteration-level scheduling — new requests join immediately when slots open.

```bash
# High throughput config
vllm serve model-id \
  --max-num-seqs 256 \          # More concurrent sequences
  --max-num-batched-tokens 8192  # More tokens per iteration

# Low latency config
vllm serve model-id \
  --max-num-seqs 16 \           # Fewer sequences, less queuing
  --max-num-batched-tokens 2048
```

### TGI Batch Scheduling

```bash
# High throughput
docker run ... \
  --max-concurrent-requests 256 \
  --max-batch-prefill-tokens 8192 \
  --waiting-served-ratio 0.5

# Low latency
docker run ... \
  --max-concurrent-requests 32 \
  --max-batch-prefill-tokens 2048 \
  --waiting-served-ratio 0.2
```

### Batch Size vs Latency Tradeoff

| Batch Size | Throughput | Latency (P50) | Latency (P99) | Best For |
|---|---|---|---|---|
| Small (8-32) | Lower | Low | Low | Interactive chat, real-time |
| Medium (64-128) | Moderate | Moderate | Moderate | Balanced workloads |
| Large (256-512) | Highest | Higher | Much higher | Batch processing, offline |

## Throughput Optimization

### Step 1: Baseline Measurement

```bash
# Install benchmarking tool
pip install vllm  # Includes benchmark scripts

# Run vLLM benchmark
python -m vllm.entrypoints.openai.api_server &
python benchmarks/benchmark_serving.py \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --num-prompts 100 \
  --request-rate 10
```

### Step 2: Optimize Model Loading

```bash
# Use quantized models for better throughput/VRAM ratio
vllm serve TheBloke/Llama-2-7B-AWQ --quantization awq

# Enable tensor parallelism if multiple GPUs available
vllm serve model-id --tensor-parallel-size 2
```

### Step 3: Tune Batching

```bash
# Increase batch size for throughput
vllm serve model-id --max-num-seqs 512

# Increase GPU memory utilization
vllm serve model-id --gpu-memory-utilization 0.95
```

### Step 4: Hardware Optimization

| Optimization | Impact | How |
|---|---|---|
| NVLink between GPUs | 2-5× TP communication speed | Use NVLink-connected GPU pairs |
| PCIe Gen4/5 | Faster model loading | Hardware upgrade |
| More VRAM | Larger batches, longer context | A100 80GB vs 40GB |
| Flash Attention | Faster attention computation | Enabled by default in both engines |

## Latency Profiling

### Key Latency Metrics

| Metric | Description | Target (Interactive) |
|---|---|---|
| Time to First Token (TTFT) | Time from request to first generated token | < 500ms |
| Inter-Token Latency (ITL) | Time between consecutive tokens | < 50ms |
| End-to-End Latency | Total time for complete response | Depends on output length |
| Queue Wait Time | Time spent waiting in batch queue | < 100ms |

### Measuring Latency

```python
import time
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8000/v1", api_key="none")

# Measure TTFT with streaming
start = time.perf_counter()
first_token_time = None
tokens = 0

stream = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Explain transformers briefly."}],
    max_tokens=256,
    stream=True,
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        if first_token_time is None:
            first_token_time = time.perf_counter()
        tokens += 1

end = time.perf_counter()

ttft = first_token_time - start
total = end - start
itl = (end - first_token_time) / max(tokens - 1, 1)

print(f"TTFT: {ttft*1000:.0f}ms")
print(f"ITL:  {itl*1000:.1f}ms")
print(f"Total: {total:.2f}s ({tokens} tokens)")
print(f"Throughput: {tokens/total:.1f} tokens/sec")
```

### Prometheus Metrics

Both engines expose Prometheus metrics for production monitoring:

```bash
# vLLM metrics
curl http://localhost:8000/metrics

# TGI metrics
curl http://localhost:8080/metrics
```

Key metrics to monitor:

| Metric | Description |
|---|---|
| `vllm:num_requests_running` | Currently processing requests |
| `vllm:num_requests_waiting` | Queued requests |
| `vllm:gpu_cache_usage_perc` | KV cache utilization |
| `tgi_request_duration_*` | Request latency histogram |
| `tgi_batch_current_size` | Current batch size |
| `tgi_queue_size` | Queue depth |

## Common Performance Issues

| Symptom | Likely Cause | Fix |
|---|---|---|
| High TTFT | Large prefill batch | Reduce `--max-batch-prefill-tokens` |
| High ITL | GPU underutilized | Increase batch size, check GPU clock |
| Intermittent OOM | KV cache overflow under load | Reduce `--max-num-seqs` or `--gpu-memory-utilization` |
| Low throughput | Small batch size | Increase `--max-num-seqs` |
| Slow multi-GPU | PCIe bottleneck | Use NVLink, reduce TP size |
| High P99 latency | Long sequences blocking batch | Set `--max-model-len` to limit context |

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for ensuring CUDA driver compatibility with vLLM/TGI
