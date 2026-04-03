---
name: tensorrt-llm
description: "Optimize LLM inference with NVIDIA TensorRT-LLM. Use when building TensorRT engines, running trtllm-build, converting HF checkpoints, serving with FP8/INT4 quantization, or maximizing GPU throughput on NVIDIA hardware."
---

# TensorRT-LLM Engine Building & Serving

Checkpoint conversion, engine building, and high-performance serving for LLMs on NVIDIA GPUs using TensorRT-LLM. Covers trtllm-build workflow, FP8/INT4/INT8 quantization, in-flight batching, paged KV cache, and Triton backend integration.

## Scope

This skill handles:
- Converting HuggingFace checkpoints to TensorRT-LLM format (`convert_checkpoint.py`)
- Building optimized TensorRT engines with `trtllm-build`
- FP8/INT4/INT8 quantization during engine build (NVIDIA Hopper/Ada)
- In-flight batching and paged KV cache configuration
- Kernel fusion and GEMM plugin optimization
- Multi-GPU engine building with tensor parallelism (TP) and pipeline parallelism (PP)
- Triton Inference Server backend integration (`tensorrtllm_backend`)

Does NOT handle:
- Model training or fine-tuning (→ hf-transformers-trainer)
- Non-NVIDIA inference engines like vLLM, TGI, llama.cpp (→ vllm-tgi-inference, llama-cpp-inference)
- Triton server setup, config.pbtxt, model repository structure (→ triton-deployment)
- Building GPU-enabled Docker containers or NGC base image selection (→ docker-gpu-setup)
- Quantizing models to GGUF/GPTQ/AWQ format (→ model-quantization)

## When to Use

- Building a TensorRT engine from a HuggingFace checkpoint
- Running `trtllm-build` with specific flags for max throughput
- Applying FP8 or INT4 quantization during engine build on Hopper/Ada GPUs
- Configuring in-flight batching and paged KV cache for production serving
- Deploying TensorRT-LLM engines behind Triton Inference Server
- Maximizing tokens/sec throughput on NVIDIA hardware
- Choosing between TensorRT-LLM and vLLM/SGLang for a deployment scenario

## Engine Decision Table

| Scenario | Recommended | Key Advantage | Trade-off |
|---|---|---|---|
| Max throughput on NVIDIA GPUs | TensorRT-LLM | Kernel fusion, FP8, 2-4x vs PyTorch | Longer build time, NVIDIA-only |
| Quick setup, broad model support | vLLM | pip install, no build step | ~20-40% slower than TRT-LLM on same HW |
| Structured output, prefix caching | SGLang | RadixAttention, grammar support | Smaller community |
| Multi-backend production serving | TRT-LLM + Triton | Ensemble pipelines, A/B testing | Complex setup |
| Low VRAM, CPU+GPU hybrid | llama-cpp | GGUF, partial offload | Lower throughput |

**Rules of thumb**:
- **TensorRT-LLM** khi cần max throughput trên NVIDIA GPU và chấp nhận build time.
- **vLLM** khi cần quick setup hoặc model chưa được TRT-LLM support.
- Build step là trade-off chính: TRT-LLM cần convert + build trước khi serve.

## Quick Start

### Installation

```bash
# Option 1: pip install (requires CUDA 12.x + TensorRT)
pip install tensorrt-llm

# Option 2: NGC container (recommended — all deps included)
docker run --gpus all -it --rm nvcr.io/nvidia/tritonserver:24.07-trtllm-python-py3
```

⚠️ **HARD GATE:** Trước khi build engine, PHẢI xác nhận: (1) GPU architecture — FP8 cần Hopper/Ada trở lên, (2) VRAM đủ cho model + build overhead (~2x model size), (3) TensorRT-LLM version compatible với model. Run `nvidia-smi` và `python -c "import tensorrt_llm; print(tensorrt_llm.__version__)"`.

### Step 1: Convert HuggingFace Checkpoint

```bash
# Llama family
python convert_checkpoint.py \
  --model_dir /models/Llama-3.1-8B-Instruct \
  --output_dir /engines/llama-8b/checkpoint \
  --dtype float16

# With tensor parallelism
python convert_checkpoint.py \
  --model_dir /models/Llama-3.1-70B-Instruct \
  --output_dir /engines/llama-70b/checkpoint \
  --dtype float16 \
  --tp_size 4
```

**Validate:** Thư mục `--output_dir` chứa `config.json` + `rank*.safetensors`. Nếu thiếu → check model architecture có được support không.

### Step 2: Build TensorRT Engine

```bash
trtllm-build \
  --checkpoint_dir /engines/llama-8b/checkpoint \
  --output_dir /engines/llama-8b/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 64 \
  --max_input_len 2048 \
  --max_seq_len 4096
```

**Validate:** `--output_dir` chứa `rank*.engine` + `config.json`. Nếu build fail → check VRAM (cần ~2x model size during build), giảm `--max_batch_size` hoặc `--max_seq_len`.

### Step 3: Run Inference

```bash
# Quick test with run.py
python run.py \
  --engine_dir /engines/llama-8b/engine \
  --tokenizer_dir /models/Llama-3.1-8B-Instruct \
  --max_output_len 256 \
  --input_text "What is TensorRT-LLM?"

# Or serve via Triton backend (production)
# See references/serving-config.md
```

**Validate:** Output text hợp lý, không gibberish. Nếu output lỗi → check tokenizer path khớp với model đã convert.

## Key trtllm-build Flags

| Flag | Default | Description |
|---|---|---|
| `--checkpoint_dir` | required | Converted checkpoint directory |
| `--output_dir` | required | Output engine directory |
| `--gemm_plugin` | none | GEMM plugin dtype: `float16`, `bfloat16`, `float32` |
| `--gpt_attention_plugin` | none | Attention plugin dtype (enables in-flight batching) |
| `--max_batch_size` | 1 | Maximum batch size at runtime |
| `--max_input_len` | 1024 | Maximum input sequence length |
| `--max_seq_len` | 2048 | Maximum total sequence length (input + output) |
| `--tp_size` | 1 | Tensor parallelism degree |
| `--pp_size` | 1 | Pipeline parallelism degree |
| `--max_num_tokens` | auto | Max tokens per batch (for in-flight batching) |
| `--strongly_typed` | false | Enable strongly typed network (faster build) |
| `--use_paged_context_fmha` | false | Enable paged KV cache with FlashAttention |

> For detailed flag reference, multi-GPU build, and optimization tips, see [Build Workflow](references/build-workflow.md)

## FP8 Quantization (Hopper/Ada)

```bash
# Step 1: Quantize checkpoint to FP8
python ../quantization/quantize.py \
  --model_dir /models/Llama-3.1-8B-Instruct \
  --output_dir /engines/llama-8b-fp8/checkpoint \
  --dtype float16 \
  --qformat fp8 \
  --calib_size 512

# Step 2: Build engine from FP8 checkpoint
trtllm-build \
  --checkpoint_dir /engines/llama-8b-fp8/checkpoint \
  --output_dir /engines/llama-8b-fp8/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 128 \
  --max_input_len 2048 \
  --max_seq_len 4096
```

⚠️ FP8 chỉ hoạt động trên GPU Hopper (H100, H200) hoặc Ada Lovelace (L40S, RTX 4090). Trên Ampere trở xuống sẽ fail.

> For INT4/INT8 quantization workflows, see [Build Workflow](references/build-workflow.md)

## Troubleshooting Flowchart

```
Build hoặc runtime gặp lỗi?
├─ Build fails
│   ├─ OOM during build → Giảm --max_batch_size, --max_seq_len
│   ├─ "Unsupported model" → Check TRT-LLM version, model architecture support
│   ├─ CUDA/TensorRT version mismatch → Dùng NGC container thay vì pip install
│   └─ Build quá chậm (>1h cho 7B) → Thêm --strongly_typed, check GPU utilization
│
├─ Engine loads nhưng output sai
│   ├─ Gibberish output → Tokenizer path sai, hoặc dtype mismatch khi convert
│   ├─ Repetitive output → Check max_seq_len đủ lớn, temperature > 0
│   └─ Truncated output → Tăng --max_output_len khi run
│
├─ Runtime OOM
│   ├─ Giảm --max_batch_size trong engine build
│   ├─ Giảm --max_seq_len (ảnh hưởng KV cache size)
│   ├─ Enable paged KV cache: --use_paged_context_fmha
│   └─ Dùng FP8/INT4 quantization để giảm memory footprint
│
└─ Throughput thấp hơn expected
    ├─ Thiếu --gemm_plugin → kernel fusion bị disable
    ├─ Thiếu --gpt_attention_plugin → in-flight batching bị disable
    ├─ max_batch_size quá nhỏ → rebuild với batch size lớn hơn
    └─ PCIe bottleneck với multi-GPU → check NVLink, giảm TP size
```

> For Triton backend setup, in-flight batching config, and benchmarking, see [Serving Config](references/serving-config.md)

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Cứ pip install tensorrt-llm là xong" | TRT-LLM có nhiều native deps (TensorRT, cuDNN, NCCL). NGC container là cách reliable nhất. pip install thường gặp version conflict trên host. |
| "Build engine 1 lần, dùng mãi" | Engine bị tied vào GPU architecture + TRT-LLM version + max_batch_size/max_seq_len. Đổi GPU hoặc upgrade TRT-LLM → phải rebuild. |
| "Không cần --gemm_plugin, model vẫn chạy" | Thiếu GEMM plugin = không có kernel fusion = throughput giảm 30-50%. LUÔN enable `--gemm_plugin` và `--gpt_attention_plugin`. |
| "FP8 chạy trên mọi GPU" | FP8 chỉ support Hopper (H100/H200) và Ada Lovelace (L40S/RTX 4090). Ampere (A100) chỉ support INT8/FP16. |
| "max_batch_size càng lớn càng tốt" | max_batch_size lớn = VRAM reserved cho KV cache lớn. Set quá cao → OOM khi load engine. Estimate VRAM trước khi build. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to fine-tune model before building TRT engine | hf-transformers-trainer | Handles SFT/DPO/GRPO training workflows |
| Want vLLM/TGI instead of TRT-LLM (easier setup) | vllm-tgi-inference | No build step, pip install, OpenAI-compatible API |
| Need GGUF/GPTQ/AWQ quantization (not TRT-LLM native) | model-quantization | Handles llama-quantize, AutoGPTQ, AutoAWQ conversion |
| Setting up Triton server, config.pbtxt, model repository | triton-deployment | Covers Triton config, ensemble pipelines, dynamic batching |
| GPU not visible in Docker or need NGC base image | docker-gpu-setup | NVIDIA Container Toolkit, docker-compose GPU passthrough |
| CUDA/cuDNN version mismatch when installing TRT-LLM | python-ml-deps | Resolves PyTorch CUDA index URLs, driver/toolkit compatibility |

## References

- [Build Workflow](references/build-workflow.md) — Checkpoint conversion per model family, trtllm-build flags deep dive, FP8/INT4/INT8 quantization, multi-GPU build, engine optimization
  **Load when:** converting checkpoints, building engines with non-default flags, applying quantization, or configuring multi-GPU tensor/pipeline parallelism
- [Serving Config](references/serving-config.md) — Triton backend setup, in-flight batching, paged KV cache tuning, streaming, benchmarking with trtllm-bench
  **Load when:** deploying TRT-LLM engines behind Triton, configuring in-flight batching, tuning KV cache, or benchmarking throughput
