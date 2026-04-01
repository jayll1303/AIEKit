# vLLM Configuration Guide

Detailed configuration reference for vLLM server deployment, covering tensor parallelism, quantization, PagedAttention, continuous batching, and advanced tuning.

## Installation

```bash
# Standard install (requires CUDA 12.x)
pip install vllm

# With specific CUDA version
pip install vllm --extra-index-url https://download.pytorch.org/whl/cu121
```

**Requirements**:
- Python 3.9+
- CUDA 12.1+ (recommended) or CUDA 11.8
- GPU with compute capability ≥ 7.0 (Volta or newer)

## Tensor Parallelism

Tensor parallelism (TP) shards model weights across multiple GPUs, enabling serving of models that don't fit on a single GPU.

### Configuration

```bash
# 2-GPU tensor parallelism
vllm serve meta-llama/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 2

# 4-GPU tensor parallelism
vllm serve meta-llama/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 4

# 8-GPU for very large models
vllm serve meta-llama/Llama-3.1-405B-Instruct \
  --tensor-parallel-size 8 \
  --dtype bfloat16
```

### TP Requirements

| Requirement | Detail |
|---|---|
| GPU count | TP size must evenly divide the number of attention heads |
| VRAM | All GPUs must have sufficient VRAM for their shard |
| Interconnect | NVLink preferred for TP > 2; PCIe works but slower |
| Homogeneous | All GPUs should be the same model and VRAM size |

### TP Size Selection

| Model Size | Min TP Size (FP16) | Min TP Size (4-bit) |
|---|---|---|
| 7-8B | 1 (24 GB GPU) | 1 (8 GB GPU) |
| 13B | 1 (40 GB GPU) or 2 | 1 (16 GB GPU) |
| 34B | 2 (24 GB GPUs) | 1 (24 GB GPU) |
| 70B | 4 (24 GB GPUs) or 2 (80 GB) | 2 (24 GB GPUs) |
| 405B | 8 (80 GB GPUs) | 4 (80 GB GPUs) |

## Quantization Options

vLLM supports multiple quantization formats for reduced VRAM usage and faster inference.

### Supported Methods

| Method | Flag | Format | Notes |
|---|---|---|---|
| AWQ | `--quantization awq` | Safetensors | Best inference speed, widely supported |
| GPTQ | `--quantization gptq` | Safetensors | Good quality, broad model availability |
| GGUF | (auto-detected) | GGUF file | Pass GGUF file path as `--model` |
| SqueezeLLM | `--quantization squeezellm` | Safetensors | Sparse quantization |
| FP8 | `--quantization fp8` | Safetensors | H100/Ada Lovelace GPUs only |
| Marlin | `--quantization marlin` | Safetensors | Optimized GPTQ kernel |

### AWQ Serving

```bash
vllm serve TheBloke/Llama-2-7B-AWQ \
  --quantization awq \
  --dtype half \
  --max-model-len 4096
```

### GPTQ Serving

```bash
vllm serve TheBloke/Llama-2-7B-GPTQ \
  --quantization gptq \
  --dtype half
```

### GGUF Serving

```bash
# GGUF requires specifying the tokenizer separately
vllm serve ./models/llama-3.1-8b.Q4_K_M.gguf \
  --tokenizer meta-llama/Llama-3.1-8B-Instruct
```

### FP8 Quantization (H100/Ada)

```bash
# FP8 on supported hardware
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --quantization fp8 \
  --dtype auto
```

## PagedAttention Configuration

PagedAttention is vLLM's core memory management system. It manages KV cache in fixed-size pages, eliminating memory fragmentation and enabling efficient batching.

### Key Parameters

| Parameter | Flag | Default | Effect |
|---|---|---|---|
| GPU memory utilization | `--gpu-memory-utilization` | 0.9 | Fraction of GPU memory for model + KV cache |
| Max model length | `--max-model-len` | auto | Maximum context window; directly affects KV cache size |
| Block size | `--block-size` | 16 | KV cache block size in tokens |
| Swap space | `--swap-space` | 4 | CPU swap space in GB for offloaded KV blocks |

### Tuning KV Cache

```bash
# Reduce GPU memory utilization if OOM
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --gpu-memory-utilization 0.85

# Limit context window to save KV cache memory
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --max-model-len 4096

# Enable CPU swap for overflow
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --swap-space 8
```

### Memory Breakdown

For a given model, vLLM allocates GPU memory as:
1. **Model weights**: Fixed, determined by model size and dtype
2. **KV cache**: Dynamic, grows with `gpu-memory-utilization` minus model weight size
3. **Activation memory**: Small overhead for computation

```
Available KV cache memory = GPU VRAM × gpu-memory-utilization − model weight size
```

## Continuous Batching

vLLM uses continuous (iteration-level) batching — new requests join the batch as soon as a slot opens, without waiting for the entire batch to complete.

### Batching Parameters

| Parameter | Flag | Default | Description |
|---|---|---|---|
| Max sequences | `--max-num-seqs` | 256 | Max concurrent sequences in a batch |
| Max num batched tokens | `--max-num-batched-tokens` | auto | Max tokens processed per iteration |

### Tuning for Throughput

```bash
# High throughput: increase batch size
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --max-num-seqs 512 \
  --gpu-memory-utilization 0.95

# Low latency: reduce batch size
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --max-num-seqs 32 \
  --gpu-memory-utilization 0.9
```

## Advanced Configuration

### CUDA Graphs

```bash
# Disable CUDA graphs for debugging or compatibility
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --enforce-eager

# In production, keep CUDA graphs enabled (default) for best performance
```

### Speculative Decoding

```bash
# Use a smaller draft model for speculative decoding
vllm serve meta-llama/Llama-3.1-70B-Instruct \
  --speculative-model meta-llama/Llama-3.1-8B-Instruct \
  --num-speculative-tokens 5
```

### API Server Options

```bash
# Full server configuration
vllm serve meta-llama/Llama-3.1-8B-Instruct \
  --host 0.0.0.0 \
  --port 8000 \
  --api-key my-secret-key \
  --served-model-name my-llama \
  --response-role assistant \
  --chat-template ./chat_template.jinja
```

### Environment Variables

| Variable | Description |
|---|---|
| `VLLM_ATTENTION_BACKEND` | Override attention backend (e.g., `FLASH_ATTN`, `XFORMERS`) |
| `CUDA_VISIBLE_DEVICES` | Restrict visible GPUs (e.g., `0,1`) |
| `NCCL_P2P_DISABLE` | Set to `1` if NCCL P2P fails on PCIe setups |
| `VLLM_WORKER_MULTIPROC_METHOD` | Set to `spawn` if fork causes issues |

## Docker Deployment

```bash
# vLLM also supports Docker deployment
docker run --gpus all -p 8000:8000 \
  -v $PWD/models:/models \
  vllm/vllm-openai:latest \
  --model meta-llama/Llama-3.1-8B-Instruct \
  --host 0.0.0.0 --port 8000
```

> **See also**: [docker-gpu-setup](../../docker-gpu-setup/SKILL.md) for GPU Docker prerequisites and NVIDIA Container Toolkit setup
