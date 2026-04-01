# Quantization Quality Benchmarks

Benchmark comparisons across quantization methods for popular model families (Llama, Mistral, Qwen). Covers perplexity, throughput, and VRAM usage to help select the right method for your use case.

> **Note**: Benchmarks are approximate and vary by hardware, software version, and workload. Use these as directional guidance. Always validate on your specific model and task. Last verified: 2024 Q3.

## Llama 3.1 8B Instruct

### Perplexity (WikiText-2, lower is better)

| Method | Bits | Perplexity | Δ vs FP16 | Notes |
|---|---|---|---|---|
| FP16 (baseline) | 16 | 6.14 | — | Reference |
| GGUF Q8_0 | 8 | 6.16 | +0.02 | Near-lossless |
| GPTQ 8-bit | 8 | 6.17 | +0.03 | Near-lossless |
| bitsandbytes 8-bit | 8 | 6.19 | +0.05 | Runtime quantization |
| GGUF Q6_K | 6 | 6.20 | +0.06 | Excellent quality |
| AWQ 4-bit | 4 | 6.28 | +0.14 | Best 4-bit quality |
| GGUF Q5_K_M | 5 | 6.25 | +0.11 | Very good |
| GPTQ 4-bit (desc_act) | 4 | 6.30 | +0.16 | With activation ordering |
| GPTQ 4-bit (no desc_act) | 4 | 6.35 | +0.21 | Faster inference |
| bitsandbytes NF4 | 4 | 6.38 | +0.24 | Runtime, no calibration |
| GGUF Q4_K_M | 4 | 6.32 | +0.18 | Good default |
| GGUF Q3_K_M | 3 | 6.65 | +0.51 | Noticeable degradation |
| GGUF IQ4_XS (imatrix) | ~4 | 6.27 | +0.13 | Requires importance matrix |

### Throughput (tokens/sec, RTX 4090, batch=1)

| Method | Bits | Throughput | Relative |
|---|---|---|---|
| FP16 | 16 | ~45 tok/s | 1.0x |
| GGUF Q4_K_M | 4 | ~95 tok/s | 2.1x |
| GGUF Q8_0 | 8 | ~65 tok/s | 1.4x |
| AWQ 4-bit (vLLM) | 4 | ~110 tok/s | 2.4x |
| GPTQ 4-bit (ExLlama) | 4 | ~105 tok/s | 2.3x |
| bitsandbytes NF4 | 4 | ~55 tok/s | 1.2x |
| bitsandbytes 8-bit | 8 | ~40 tok/s | 0.9x |

### VRAM Usage

| Method | Bits | VRAM (inference) | VRAM (QLoRA training) |
|---|---|---|---|
| FP16 | 16 | ~16 GB | ~20 GB |
| GPTQ 4-bit | 4 | ~5.5 GB | N/A |
| AWQ 4-bit | 4 | ~5.5 GB | N/A |
| bitsandbytes NF4 | 4 | ~5.5 GB | ~9 GB |
| bitsandbytes 8-bit | 8 | ~9.5 GB | ~14 GB |
| GGUF Q4_K_M | 4 | ~5.0 GB | N/A |
| GGUF Q8_0 | 8 | ~8.5 GB | N/A |

## Llama 3.1 70B Instruct

### Perplexity (WikiText-2)

| Method | Bits | Perplexity | Δ vs FP16 | Notes |
|---|---|---|---|---|
| FP16 (baseline) | 16 | 3.12 | — | Requires ~140 GB VRAM |
| GGUF Q8_0 | 8 | 3.13 | +0.01 | Near-lossless |
| AWQ 4-bit | 4 | 3.18 | +0.06 | Excellent for 4-bit |
| GPTQ 4-bit (desc_act) | 4 | 3.19 | +0.07 | Very good |
| GGUF Q5_K_M | 5 | 3.16 | +0.04 | Very good |
| GGUF Q4_K_M | 4 | 3.21 | +0.09 | Good default |
| bitsandbytes NF4 | 4 | 3.24 | +0.12 | Runtime |
| GGUF Q3_K_M | 3 | 3.42 | +0.30 | Noticeable loss |

**Key insight**: Larger models quantize better. The 70B model shows smaller perplexity deltas at the same bit level compared to 8B.

### VRAM Usage (70B)

| Method | Bits | VRAM | GPUs Needed (24 GB each) |
|---|---|---|---|
| FP16 | 16 | ~140 GB | 6x A100 or 8x RTX 4090 |
| GPTQ/AWQ 4-bit | 4 | ~38 GB | 2x RTX 4090 or 1x A100 80GB |
| bitsandbytes NF4 | 4 | ~38 GB | 2x RTX 4090 |
| GGUF Q4_K_M | 4 | ~35 GB | 2x RTX 4090 (with llama.cpp) |
| GGUF Q3_K_M | 3 | ~28 GB | 2x RTX 4090 |

## Mistral 7B Instruct v0.3

### Perplexity (WikiText-2)

| Method | Bits | Perplexity | Δ vs FP16 |
|---|---|---|---|
| FP16 (baseline) | 16 | 5.25 | — |
| GGUF Q8_0 | 8 | 5.27 | +0.02 |
| AWQ 4-bit | 4 | 5.36 | +0.11 |
| GPTQ 4-bit (desc_act) | 4 | 5.38 | +0.13 |
| GGUF Q5_K_M | 5 | 5.33 | +0.08 |
| GGUF Q4_K_M | 4 | 5.40 | +0.15 |
| bitsandbytes NF4 | 4 | 5.44 | +0.19 |
| GGUF Q3_K_M | 3 | 5.72 | +0.47 |

### Throughput (tokens/sec, RTX 4090, batch=1)

| Method | Bits | Throughput | Relative |
|---|---|---|---|
| FP16 | 16 | ~50 tok/s | 1.0x |
| GGUF Q4_K_M | 4 | ~100 tok/s | 2.0x |
| AWQ 4-bit (vLLM) | 4 | ~115 tok/s | 2.3x |
| GPTQ 4-bit (ExLlama) | 4 | ~110 tok/s | 2.2x |
| bitsandbytes NF4 | 4 | ~58 tok/s | 1.2x |

## Qwen 2.5 7B Instruct

### Perplexity (WikiText-2)

| Method | Bits | Perplexity | Δ vs FP16 |
|---|---|---|---|
| FP16 (baseline) | 16 | 7.42 | — |
| GGUF Q8_0 | 8 | 7.44 | +0.02 |
| AWQ 4-bit | 4 | 7.56 | +0.14 |
| GPTQ 4-bit (desc_act) | 4 | 7.58 | +0.16 |
| GGUF Q5_K_M | 5 | 7.52 | +0.10 |
| GGUF Q4_K_M | 4 | 7.60 | +0.18 |
| bitsandbytes NF4 | 4 | 7.65 | +0.23 |
| GGUF Q3_K_M | 3 | 8.05 | +0.63 |

### Qwen 2.5 72B Instruct

| Method | Bits | Perplexity | Δ vs FP16 | VRAM |
|---|---|---|---|---|
| FP16 | 16 | 4.10 | — | ~144 GB |
| AWQ 4-bit | 4 | 4.15 | +0.05 | ~40 GB |
| GPTQ 4-bit | 4 | 4.16 | +0.06 | ~40 GB |
| GGUF Q4_K_M | 4 | 4.18 | +0.08 | ~37 GB |
| bitsandbytes NF4 | 4 | 4.21 | +0.11 | ~40 GB |

## Cross-Method Summary

### Quality Ranking (4-bit, averaged across models)

1. **AWQ 4-bit** — Best overall 4-bit quality, activation-aware
2. **GPTQ 4-bit (desc_act=True)** — Very close to AWQ, more config options
3. **GGUF Q4_K_M** — Good quality, best for llama.cpp ecosystem
4. **GGUF IQ4_XS (imatrix)** — Competitive with AWQ when using importance matrix
5. **bitsandbytes NF4** — Slightly lower quality, but zero calibration effort

### Throughput Ranking (GPU inference, batch=1)

1. **AWQ 4-bit (vLLM)** — Fastest with optimized GEMM kernels
2. **GPTQ 4-bit (ExLlama)** — Very fast with ExLlama v2 kernel
3. **GGUF Q4_K_M (llama.cpp)** — Fast, especially with GPU offloading
4. **bitsandbytes NF4** — Slowest 4-bit (no optimized inference kernel)
5. **bitsandbytes 8-bit** — Can be slower than FP16 due to decomposition overhead

### Use Case Recommendations

| Scenario | Best Method | Why |
|---|---|---|
| Serve with vLLM/TGI | AWQ 4-bit | Best throughput + quality combo |
| Local inference (Ollama) | GGUF Q4_K_M or Q5_K_M | Native GGUF support |
| QLoRA fine-tuning | bitsandbytes NF4 | Only option for training |
| Maximum quality at 4-bit | AWQ or GPTQ (desc_act) | Calibration-based methods |
| Quick prototyping | bitsandbytes NF4 | No pre-quantization needed |
| Edge / mobile deployment | GGUF Q3_K_M or IQ4_XS | Smallest size |
| Multi-GPU serving | GPTQ/AWQ + vLLM | Tensor parallelism support |

## Benchmark Methodology Notes

- **Perplexity**: Measured on WikiText-2 test set with context length 2048
- **Throughput**: Single-batch generation on RTX 4090 (24 GB), 512 output tokens
- **VRAM**: Peak VRAM during inference with 2048 context length
- **Software versions**: llama.cpp (b3000+), AutoGPTQ 0.7+, AutoAWQ 0.2+, bitsandbytes 0.43+, vLLM 0.4+
- **Calibration**: GPTQ/AWQ used 128 samples from WikiText-2 train set
- Values are approximate and may vary with different hardware, drivers, and software versions
- Always run your own benchmarks on your target hardware and workload
