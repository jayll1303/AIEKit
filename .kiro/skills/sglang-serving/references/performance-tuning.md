# Performance Tuning for SGLang

RadixAttention deep dive, chunked prefill configuration, tensor parallelism, quantized model serving, memory tuning, and benchmarking SGLang vs vLLM.

## RadixAttention Explained

### What is RadixAttention?

RadixAttention là core innovation của SGLang — sử dụng radix tree (prefix tree) để cache và reuse KV cache across requests. Khi nhiều requests share cùng prefix (system prompt, few-shot examples), KV cache cho prefix đó chỉ compute 1 lần.

```
Traditional (vLLM PagedAttention):
  Request 1: [system prompt] + [user query 1] → compute full KV cache
  Request 2: [system prompt] + [user query 2] → compute full KV cache (duplicate!)
  Request 3: [system prompt] + [user query 3] → compute full KV cache (duplicate!)

RadixAttention (SGLang):
  Request 1: [system prompt] + [user query 1] → compute & cache prefix KV
  Request 2: [system prompt] + [user query 2] → reuse cached prefix KV ✓
  Request 3: [system prompt] + [user query 3] → reuse cached prefix KV ✓
```

### When RadixAttention Helps Most

| Workload | Prefix Sharing | Speedup vs vLLM |
|---|---|---|
| Chat with long system prompt | High (same system prompt) | 1.5-2× |
| Few-shot classification | Very high (same examples) | 2-3× |
| RAG with shared context | High (same retrieved docs) | 1.5-2.5× |
| Code completion (same file context) | High | 1.5-2× |
| Unique prompts, no sharing | None | ~1× (no benefit) |
| Multi-turn conversation | Moderate (growing prefix) | 1.3-1.8× |

### Radix Cache Behavior

```
Radix Tree Structure:
                    [root]
                   /      \
          [system_A]      [system_B]
          /    \              |
    [few_shot] [query_1]  [query_2]
       |
    [query_3]

- Mỗi node = cached KV cache segment
- Shared prefixes chỉ store 1 lần
- LRU eviction khi memory đầy
- Automatic — không cần config
```

### Monitoring Cache Hit Rate

```bash
# Check server metrics
curl -s http://localhost:30000/get_server_info | python -m json.tool

# Key metrics:
# - cache_hit_rate: tỷ lệ prefix cache hit (target: > 0.5 cho shared-prefix workloads)
# - cache_total_tokens: total tokens trong radix cache
# - num_running_requests: concurrent requests đang xử lý
```

### Khi nào KHÔNG nên dùng RadixAttention

- Mỗi request có prompt hoàn toàn khác nhau → cache hit rate ≈ 0
- Very short prompts (< 100 tokens) → overhead > benefit
- Single request at a time → không có sharing opportunity

Trong các trường hợp này, vLLM PagedAttention có thể ngang hoặc nhanh hơn.

## Chunked Prefill Configuration

### What is Chunked Prefill?

Chunked prefill chia long prompt thành chunks nhỏ, xen kẽ prefill và decode. Giảm Time to First Token (TTFT) cho requests đang chờ.

```
Without chunked prefill:
  Long prompt (8K tokens) → prefill ALL 8K → then decode
  Other requests: blocked during 8K prefill ❌

With chunked prefill:
  Long prompt → prefill chunk 1 (2K) → decode other requests
                → prefill chunk 2 (2K) → decode other requests
                → prefill chunk 3 (2K) → decode other requests
                → prefill chunk 4 (2K) → start decoding
  Other requests: interleaved, lower TTFT ✓
```

### Configuration

```bash
# Default: automatic chunk size
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --port 30000

# Custom chunk size (tokens per chunk)
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --chunked-prefill-size 4096 \
  --port 30000

# Smaller chunks = lower TTFT, slightly lower throughput
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --chunked-prefill-size 2048 \
  --port 30000
```

### Chunk Size Tradeoffs

| Chunk Size | TTFT | Throughput | Best For |
|---|---|---|---|
| 2048 | Lowest | Slightly lower | Interactive chat, real-time |
| 4096 | Low | Balanced | General purpose |
| 8192 | Moderate | Higher | Batch processing |
| Disabled | Highest | Maximum | Offline batch, no latency requirement |

## Tensor Parallelism Setup

### Basic TP Configuration

```bash
# 2 GPUs
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-70B-Instruct \
  --tp 2 \
  --port 30000

# 4 GPUs
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-70B-Instruct \
  --tp 4 \
  --port 30000

# 8 GPUs (full node)
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.3-70B-Instruct \
  --tp 8 \
  --port 30000
```

### TP Size Guidelines

| Model Size | Min GPUs (FP16) | Min GPUs (4-bit) | Recommended TP |
|---|---|---|---|
| 7-8B | 1× 24GB | 1× 12GB | 1 |
| 13B | 1× 40GB | 1× 24GB | 1-2 |
| 34B | 2× 40GB | 1× 40GB | 2 |
| 70B | 4× 40GB hoặc 2× 80GB | 2× 40GB | 2-4 |
| 405B | 8× 80GB | 4× 80GB | 8 |

### TP Requirements

- TP size phải chia hết số attention heads của model
- Tất cả GPU phải cùng model (mixing A100 + RTX không work)
- NVLink preferred cho TP > 2 (PCIe bottleneck)
- NCCL phải hoạt động: test với `python -c "import torch.distributed"`

### Data Parallelism (DP)

Khi có nhiều GPU hơn cần thiết cho TP:

```bash
# DP=2, TP=2 trên 4 GPUs → 2 replicas, mỗi replica 2 GPUs
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-70B-Instruct \
  --tp 2 \
  --dp 2 \
  --port 30000
```

## FP8 / INT4 Quantization Serving

### FP8 Models

```bash
# Pre-quantized FP8 model (recommended)
python -m sglang.launch_server \
  --model-path neuralmagic/Meta-Llama-3.1-8B-Instruct-FP8 \
  --port 30000

# FP8 with explicit flag
python -m sglang.launch_server \
  --model-path neuralmagic/Meta-Llama-3.1-70B-Instruct-FP8 \
  --quantization fp8 \
  --tp 2 \
  --port 30000
```

### AWQ Models

```bash
python -m sglang.launch_server \
  --model-path TheBloke/Llama-2-7B-AWQ \
  --quantization awq \
  --port 30000
```

### GPTQ Models

```bash
python -m sglang.launch_server \
  --model-path TheBloke/Llama-2-7B-GPTQ \
  --quantization gptq \
  --port 30000
```

### Quantization Performance Comparison

| Method | VRAM Savings | Speed vs FP16 | Quality Loss | Best For |
|---|---|---|---|---|
| FP8 | ~50% | 1.2-1.5× faster | Minimal | Production, best quality/speed ratio |
| AWQ 4-bit | ~75% | 1.0-1.3× faster | Small | Low VRAM, good quality |
| GPTQ 4-bit | ~75% | 0.9-1.2× faster | Small | Low VRAM, broad model support |
| Marlin (GPTQ) | ~75% | 1.3-1.6× faster | Small | Maximum 4-bit speed |

## Memory Fraction Tuning

### `--mem-fraction-static`

Controls fraction of GPU memory allocated cho KV cache (static allocation):

```bash
# Default: 88% cho KV cache
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --mem-fraction-static 0.88

# Conservative: nhiều headroom hơn
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --mem-fraction-static 0.80

# Aggressive: max KV cache (risk OOM under load)
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --mem-fraction-static 0.92
```

### Memory Fraction Guidelines

| Scenario | Recommended | Why |
|---|---|---|
| Default / general | 0.88 | Balanced, safe default |
| OOM under concurrent load | 0.80-0.85 | More headroom cho spikes |
| Single user, max context | 0.90-0.92 | Maximize KV cache |
| Quantized model (less weight memory) | 0.90 | More free memory available |
| Multi-modal (vision) | 0.80-0.85 | Image tokens cần extra memory |

### Other Memory Controls

```bash
# Limit context length → giảm max KV cache per request
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --context-length 4096  # Instead of model's 128K

# Limit concurrent requests
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --max-running-requests 32
```

## Benchmarking: SGLang vs vLLM

### Quick Benchmark Setup

```bash
# Start SGLang server
python -m sglang.launch_server \
  --model-path meta-llama/Llama-3.1-8B-Instruct \
  --port 30000 &

# Benchmark with sglang built-in tool
python -m sglang.bench_serving \
  --backend sglang \
  --port 30000 \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --num-prompts 200 \
  --request-rate 10
```

### Benchmark Comparison (Approximate)

Shared prefix workload (same system prompt, 500 tokens):

| Engine | GPU | Throughput (tok/s) | TTFT (P50) | Config |
|---|---|---|---|---|
| SGLang | A100 80GB | ~4000-5500 | ~80ms | Default (RadixAttention on) |
| vLLM | A100 80GB | ~2500-3500 | ~120ms | Default (PagedAttention) |
| SGLang | RTX 4090 | ~2500-3500 | ~100ms | Default |
| vLLM | RTX 4090 | ~1500-2500 | ~150ms | Default |

Unique prompts (no prefix sharing):

| Engine | GPU | Throughput (tok/s) | TTFT (P50) | Config |
|---|---|---|---|---|
| SGLang | A100 80GB | ~2800-3800 | ~100ms | Default |
| vLLM | A100 80GB | ~2500-3500 | ~110ms | Default |

**Key insight**: SGLang advantage lớn nhất khi có shared prefixes. Với unique prompts, performance gần tương đương vLLM.

⚠️ **Note**: Benchmarks are approximate, vary significantly with batch size, sequence length, model, and hardware. Always benchmark on your specific setup.

### Latency Profiling

```python
import time
from openai import OpenAI

client = OpenAI(base_url="http://localhost:30000/v1", api_key="none")

start = time.perf_counter()
first_token_time = None
tokens = 0

stream = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Explain RadixAttention briefly."}],
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
itl = (end - first_token_time) / max(tokens - 1, 1)

print(f"TTFT: {ttft*1000:.0f}ms")
print(f"ITL:  {itl*1000:.1f}ms")
print(f"Throughput: {tokens/(end-start):.1f} tokens/sec")
```

## Common Performance Issues

| Symptom | Likely Cause | Fix |
|---|---|---|
| High TTFT | Long prompt, no chunked prefill | `--chunked-prefill-size 4096` |
| Low cache hit rate | Unique prompts, no prefix sharing | Expected — RadixAttention benefit minimal |
| OOM under load | KV cache overflow | Giảm `--mem-fraction-static` hoặc `--max-running-requests` |
| Slow multi-GPU | PCIe bottleneck | NVLink, hoặc giảm TP size |
| First request slow | Cache cold start | Normal — subsequent requests nhanh hơn |
| Throughput lower than expected | Small batch size | Tăng concurrent requests, check `--max-running-requests` |
| Quantized model slower than FP16 | GPTQ overhead | Thử AWQ hoặc FP8 (thường nhanh hơn GPTQ) |

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for CUDA driver compatibility, [model-quantization](../../model-quantization/SKILL.md) for creating quantized models
