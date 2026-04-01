---
name: vllm-tgi-inference
description: "Deploy and serve LLMs locally with vLLM or TGI. Use when launching vllm serve, running TGI Docker, configuring tensor parallelism, serving quantized models, using OpenAI-compatible API, tuning KV cache, or diagnosing OOM errors."
---

# vLLM & TGI Local Inference

Server launch patterns and configuration for deploying LLM inference locally using vLLM or HuggingFace Text Generation Inference (TGI). Covers engine selection, quantized model serving, OpenAI-compatible API usage, and performance diagnostics.

## Scope

This skill handles:
- Launching vLLM or TGI inference servers with correct flags and quantization options
- Configuring tensor parallelism across multiple GPUs for large model serving
- Tuning KV cache, batch scheduling, and `gpu-memory-utilization` for throughput
- Calling OpenAI-compatible `/v1/` endpoints from Python or curl
- Diagnosing model loading failures, OOM errors, and slow generation

Does NOT handle:
- Quantizing models before serving (GGUF, GPTQ, AWQ conversion) (→ model-quantization)
- Building GPU-enabled Docker containers or NGC base image selection (→ docker-gpu-setup)
- Resolving CUDA/cuDNN/driver version conflicts on host (→ python-ml-deps)
- Deploying models on Triton Inference Server (→ triton-deployment)

## When to Use

- Deploying a local LLM inference server with an OpenAI-compatible API
- Launching a vLLM server with tensor parallelism across multiple GPUs
- Running TGI in Docker for production-style model serving
- Serving AWQ, GPTQ, or GGUF quantized models for reduced VRAM usage
- Tuning throughput and latency for high-concurrency inference workloads
- Diagnosing model loading failures, OOM errors, or slow generation
- Choosing between vLLM and TGI for a specific deployment scenario

## Engine Decision Table

Choose the right engine for your deployment scenario:

| Scenario | Recommended Engine | Key Config | Why |
|---|---|---|---|
| Single GPU, quick setup | vLLM | `--model <id>` | Fastest startup, pip install, no Docker required |
| Single GPU, Docker preferred | TGI | `--model-id <id>` | Official HF container, simple Docker launch |
| Multi-GPU tensor parallel | vLLM | `--tensor-parallel-size N` | Mature TP support, automatic weight sharding |
| Multi-GPU with Docker | TGI | `--num-shard N` | Docker-native, built-in sharding |
| Low VRAM (quantized) | vLLM | `--quantization awq` | Broad quantization support (AWQ, GPTQ, GGUF) |
| Low VRAM (quantized, Docker) | TGI | `--quantize awq` | Docker + quantization in one command |
| High throughput batching | vLLM | `--max-num-seqs 256` | PagedAttention + continuous batching |
| Structured output / grammar | TGI | `--grammar-*` flags | Built-in grammar-constrained generation |
| OpenAI drop-in replacement | vLLM | default | Native OpenAI-compatible `/v1/` endpoints |
| Watermarking required | TGI | `--watermark` | Built-in text watermarking support |

**Rules of thumb**:
- **vLLM** excels at throughput, multi-GPU TP, and broad quantization format support.
- **TGI** excels at Docker-native deployment, grammar-constrained generation, and HuggingFace ecosystem integration.
- Both expose OpenAI-compatible APIs — client code is interchangeable.

## vLLM Quick Start

### Installation

```bash
pip install vllm
```

⚠️ **HARD GATE:** Do NOT launch a vLLM server before estimating VRAM requirements for model + KV cache. Rule of thumb: FP16 ≈ 2 GB per 1B params, 4-bit ≈ 0.5 GB per 1B params, plus 1-2 GB for KV cache overhead. Run `nvidia-smi` to confirm available VRAM exceeds the estimate.

### Basic Server Launch

```bash
# Serve a model with OpenAI-compatible API
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --host 0.0.0.0 \
  --port 8000
```

**Validate:** `curl -s http://localhost:8000/v1/models | python -m json.tool` returns a model list. If not → check `nvidia-smi` for VRAM availability and server logs for loading errors.

### Tensor Parallelism (Multi-GPU)

```bash
# Shard model across 2 GPUs
vllm serve meta-llama/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 2 \
  --host 0.0.0.0 \
  --port 8000
```

**Validate:** `curl -s http://localhost:8000/v1/models` returns the model AND `nvidia-smi` shows VRAM usage on all TP GPUs. If not → verify TP size evenly divides attention heads and all GPUs have equal VRAM.

### Serving Quantized Models

```bash
# AWQ quantized model
vllm serve TheBloke/Llama-2-7B-AWQ \
  --quantization awq \
  --dtype half

# GPTQ quantized model
vllm serve TheBloke/Llama-2-7B-GPTQ \
  --quantization gptq \
  --dtype half

# GGUF model
vllm serve ./models/llama-3.1-8b.Q4_K_M.gguf \
  --tokenizer meta-llama/Llama-3.1-8B-Instruct
```

### Key vLLM Flags

| Flag | Default | Description |
|---|---|---|
| `--model` | required | HuggingFace model ID or local path |
| `--tensor-parallel-size` | 1 | Number of GPUs for tensor parallelism |
| `--quantization` | none | Quantization method: `awq`, `gptq`, `squeezellm` |
| `--dtype` | auto | Data type: `auto`, `half`, `bfloat16`, `float16` |
| `--max-model-len` | auto | Maximum sequence length (context window) |
| `--gpu-memory-utilization` | 0.9 | Fraction of GPU memory to use (0.0-1.0) |
| `--max-num-seqs` | 256 | Maximum concurrent sequences for batching |
| `--enforce-eager` | false | Disable CUDA graphs (debug/compat mode) |
| `--trust-remote-code` | false | Allow custom model code from HuggingFace |

> For detailed vLLM configuration including PagedAttention tuning, continuous batching, and advanced flags, see [vLLM Config Guide](references/vllm-config-guide.md)

## TGI Quick Start

### Docker Launch (Recommended)

```bash
# Basic TGI server
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-8B-Instruct
```

**Validate:** `curl -s http://localhost:8080/health` returns `{"status":"ok"}` or 200. If not → check `docker logs <container>` for model loading errors and verify `--gpus all` is passed.

### Multi-GPU Sharding

```bash
# Shard across 2 GPUs
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id meta-llama/Llama-3.1-70B-Instruct \
  --num-shard 2
```

### Serving Quantized Models

```bash
# AWQ quantized
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id TheBloke/Llama-2-7B-AWQ \
  --quantize awq

# GPTQ quantized
docker run --gpus all -p 8080:80 \
  -v $PWD/models:/data \
  ghcr.io/huggingface/text-generation-inference:latest \
  --model-id TheBloke/Llama-2-7B-GPTQ \
  --quantize gptq
```

### Key TGI Flags

| Flag | Default | Description |
|---|---|---|
| `--model-id` | required | HuggingFace model ID or path in `/data` |
| `--num-shard` | 1 | Number of GPU shards |
| `--quantize` | none | Quantization: `awq`, `gptq`, `bitsandbytes`, `eetq` |
| `--max-input-tokens` | 1024 | Maximum input token length |
| `--max-total-tokens` | 2048 | Maximum total tokens (input + output) |
| `--max-batch-prefill-tokens` | 4096 | Max tokens in a prefill batch |
| `--max-concurrent-requests` | 128 | Max concurrent requests |
| `--watermark` | false | Enable text watermarking |
| `--trust-remote-code` | false | Allow custom model code |

> For detailed TGI configuration including grammar-constrained generation and watermarking, see [TGI Config Guide](references/tgi-config-guide.md)

## Client Code Patterns

Both vLLM and TGI expose OpenAI-compatible APIs. Client code works with either engine.

### Python (openai library)

```python
from openai import OpenAI

# Point to local server (vLLM default: 8000, TGI default: 8080)
client = OpenAI(
    base_url="http://localhost:8000/v1",  # vLLM
    # base_url="http://localhost:8080/v1",  # TGI
    api_key="not-needed",  # Local server, no auth required
)

# Chat completion
response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain PagedAttention in one paragraph."},
    ],
    temperature=0.7,
    max_tokens=256,
)
print(response.choices[0].message.content)

# Streaming
stream = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[{"role": "user", "content": "Write a haiku about GPUs."}],
    stream=True,
)
for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

### curl

```bash
# Chat completion (vLLM)
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7,
    "max_tokens": 128
  }' | python -m json.tool

# List available models
curl -s http://localhost:8000/v1/models | python -m json.tool

# Health check (TGI)
curl -s http://localhost:8080/health
```

## Diagnostic Checklist

When encountering model loading failures or performance issues:

```
Model fails to load or OOM?
├─ VRAM estimation
│   ├─ FP16 model: ~2 GB per 1B parameters
│   ├─ 4-bit quantized: ~0.5 GB per 1B parameters
│   ├─ Add ~1-2 GB overhead for KV cache and runtime
│   └─ Check: nvidia-smi before and during load
│
├─ Tensor parallel config
│   ├─ TP size must evenly divide attention heads
│   ├─ All GPUs must have same VRAM capacity
│   ├─ Check: NCCL errors → verify GPU interconnect (NVLink vs PCIe)
│   └─ Try: --enforce-eager (vLLM) to disable CUDA graphs for debugging
│
├─ KV cache sizing
│   ├─ vLLM: --gpu-memory-utilization 0.9 (default) — lower if OOM
│   ├─ vLLM: --max-model-len to limit context window → reduces KV cache
│   ├─ TGI: --max-total-tokens controls max KV cache allocation
│   └─ Rule: longer context = more KV cache VRAM
│
├─ Batch scheduling
│   ├─ vLLM: --max-num-seqs (default 256) — lower for less memory pressure
│   ├─ TGI: --max-concurrent-requests (default 128)
│   ├─ TGI: --max-batch-prefill-tokens — lower to reduce prefill spikes
│   └─ Symptom: intermittent OOM under load → reduce batch limits
│
├─ Slow generation?
│   ├─ Check GPU utilization: nvidia-smi -l 1
│   ├─ vLLM: ensure CUDA graphs enabled (don't use --enforce-eager in prod)
│   ├─ Quantized models: AWQ generally faster than GPTQ for inference
│   └─ PCIe bottleneck with multi-GPU? → Consider NVLink or reduce TP size
│
└─ Model architecture not supported?
    ├─ Check vLLM supported models: vllm.readthedocs.io
    ├─ Check TGI supported models: HuggingFace TGI docs
    └─ Custom architectures: --trust-remote-code (both engines)
```

> For detailed performance tuning including VRAM estimation formulas, throughput optimization, and latency profiling, see [Performance Tuning reference](references/performance-tuning.md)

> For a detailed comparison of vLLM vs TGI features, see [Engine Comparison reference](references/engine-comparison.md)

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "The model is 7B params, any GPU can handle it" | A 7B FP16 model needs ~14 GB VRAM plus 1-2 GB for KV cache. A 16 GB GPU will OOM under load. Always estimate: params × bytes-per-param + KV cache overhead, then compare to `nvidia-smi` free VRAM before launching. |
| "I'll set `--gpu-memory-utilization 1.0` for maximum throughput" | Reserving 100% VRAM leaves no room for KV cache growth under concurrent requests. Default 0.9 exists for a reason. Going above 0.95 causes intermittent OOM under load. |
| "Tensor parallelism always makes inference faster" | TP adds inter-GPU communication overhead (especially over PCIe). For models that fit on a single GPU, TP=1 is faster. Only use TP when the model doesn't fit in one GPU's VRAM. |
| "TGI and vLLM support the same models" | Model architecture support differs. vLLM supports GGUF natively; TGI does not. Some newer architectures land in one engine first. Always check the engine's supported model list before choosing. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to quantize a model to GGUF/GPTQ/AWQ before serving | model-quantization | Handles llama-quantize, AutoGPTQ, AutoAWQ conversion workflows |
| GPU not visible in Docker or need NGC base image for TGI | docker-gpu-setup | Covers NVIDIA Container Toolkit, docker-compose GPU passthrough |
| CUDA/cuDNN version mismatch when installing vLLM | python-ml-deps | Resolves PyTorch CUDA index URLs, driver/toolkit compatibility |
| Want to deploy model behind Triton instead of vLLM/TGI | triton-deployment | Covers config.pbtxt, model repository, ensemble pipelines |

## References

- [vLLM Config Guide](references/vllm-config-guide.md) — Tensor parallelism, quantization options, PagedAttention configuration, continuous batching, and advanced vLLM flags
  **Load when:** configuring advanced vLLM flags beyond basic `vllm serve`, tuning PagedAttention, or setting up continuous batching parameters
- [TGI Config Guide](references/tgi-config-guide.md) — Docker launch patterns, sharding, quantization, watermarking, and grammar-constrained generation
  **Load when:** launching TGI with non-default options like grammar-constrained generation, watermarking, or custom sharding configuration
- [Engine Comparison](references/engine-comparison.md) — Feature-by-feature comparison of vLLM vs TGI: performance, model support, quantization, and API compatibility
  **Load when:** choosing between vLLM and TGI for a new deployment and need detailed feature/performance comparison
- [Performance Tuning](references/performance-tuning.md) — VRAM estimation formulas, KV cache sizing, batch scheduling, throughput optimization, and latency profiling
  **Load when:** experiencing OOM errors, slow generation, or need to optimize throughput for high-concurrency workloads