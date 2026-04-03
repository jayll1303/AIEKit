# TensorRT-LLM Build Workflow

Detailed reference cho checkpoint conversion, engine building, quantization, và multi-GPU configuration với TensorRT-LLM.

## Checkpoint Conversion per Model Family

Mỗi model family có script convert riêng trong TensorRT-LLM repo. Pattern chung:

```bash
cd TensorRT-LLM/examples/<model_family>
python convert_checkpoint.py \
  --model_dir <hf_model_path> \
  --output_dir <checkpoint_output> \
  --dtype float16 \
  --tp_size <N>
```

### Llama / Llama 2 / Llama 3 / Code Llama

```bash
cd TensorRT-LLM/examples/llama
python convert_checkpoint.py \
  --model_dir /models/Llama-3.1-8B-Instruct \
  --output_dir /engines/llama-8b/ckpt \
  --dtype float16
```

### Mistral / Mixtral

```bash
cd TensorRT-LLM/examples/llama  # Mistral dùng chung script với Llama
python convert_checkpoint.py \
  --model_dir /models/Mistral-7B-Instruct-v0.3 \
  --output_dir /engines/mistral-7b/ckpt \
  --dtype float16
```

Mixtral (MoE) cần thêm flag:

```bash
python convert_checkpoint.py \
  --model_dir /models/Mixtral-8x7B-Instruct-v0.1 \
  --output_dir /engines/mixtral-8x7b/ckpt \
  --dtype float16 \
  --tp_size 2
```

### Qwen / Qwen2

```bash
cd TensorRT-LLM/examples/qwen
python convert_checkpoint.py \
  --model_dir /models/Qwen2-7B-Instruct \
  --output_dir /engines/qwen2-7b/ckpt \
  --dtype float16
```

### GPT-J / GPT-NeoX / Falcon

```bash
cd TensorRT-LLM/examples/gptj  # hoặc gptneox, falcon
python convert_checkpoint.py \
  --model_dir /models/gpt-j-6b \
  --output_dir /engines/gptj-6b/ckpt \
  --dtype float16
```

### Phi-3 / Phi-2

```bash
cd TensorRT-LLM/examples/phi
python convert_checkpoint.py \
  --model_dir /models/Phi-3-mini-4k-instruct \
  --output_dir /engines/phi3-mini/ckpt \
  --dtype float16
```

### Gemma / Gemma 2

```bash
cd TensorRT-LLM/examples/gemma
python convert_checkpoint.py \
  --model_dir /models/gemma-2-9b-it \
  --output_dir /engines/gemma2-9b/ckpt \
  --dtype float16
```

**Validate conversion:** Kiểm tra output dir chứa `config.json` + `rank0.safetensors` (hoặc `rank*.safetensors` nếu TP > 1). File `config.json` phải có `architecture`, `dtype`, `num_attention_heads` đúng.

## trtllm-build Flags Deep Dive

### Core Flags

| Flag | Required | Description |
|---|---|---|
| `--checkpoint_dir` | ✅ | Path to converted checkpoint |
| `--output_dir` | ✅ | Path to save built engine |
| `--gemm_plugin` | ⚠️ Strongly recommended | GEMM kernel fusion. Values: `float16`, `bfloat16`. LUÔN enable. |
| `--gpt_attention_plugin` | ⚠️ Strongly recommended | Attention kernel fusion + enables in-flight batching. LUÔN enable. |

### Sequence Length Flags

| Flag | Default | Description |
|---|---|---|
| `--max_input_len` | 1024 | Max input tokens. Set theo use case (chat: 2048-4096, RAG: 8192+) |
| `--max_seq_len` | 2048 | Max total tokens (input + output). Ảnh hưởng trực tiếp KV cache size |
| `--max_num_tokens` | auto | Max tokens per batch iteration. Dùng cho in-flight batching tuning |

### Batch Size Flags

| Flag | Default | Description |
|---|---|---|
| `--max_batch_size` | 1 | Max concurrent requests. Production: 32-256 tùy VRAM |
| `--max_beam_width` | 1 | Beam search width. Thường giữ 1 cho chat/generation |

### Performance Flags

| Flag | Default | Description |
|---|---|---|
| `--strongly_typed` | false | Strongly typed network — faster build, same runtime perf |
| `--use_paged_context_fmha` | false | Paged KV cache với FlashAttention. Giảm memory fragmentation |
| `--multiple_profiles` | false | Multiple optimization profiles cho different batch sizes |
| `--reduce_fusion` | false | Enable AllReduce fusion cho multi-GPU |

### Build Command Templates

**Single GPU, chat workload:**

```bash
trtllm-build \
  --checkpoint_dir /engines/llama-8b/ckpt \
  --output_dir /engines/llama-8b/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 64 \
  --max_input_len 2048 \
  --max_seq_len 4096
```

**Single GPU, long context (RAG):**

```bash
trtllm-build \
  --checkpoint_dir /engines/llama-8b/ckpt \
  --output_dir /engines/llama-8b-longctx/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 16 \
  --max_input_len 16384 \
  --max_seq_len 32768 \
  --use_paged_context_fmha
```

**Multi-GPU production:**

```bash
trtllm-build \
  --checkpoint_dir /engines/llama-70b-tp4/ckpt \
  --output_dir /engines/llama-70b-tp4/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 128 \
  --max_input_len 4096 \
  --max_seq_len 8192 \
  --use_paged_context_fmha \
  --reduce_fusion \
  --strongly_typed
```

## FP8 Quantization Workflow

FP8 giảm ~50% memory so với FP16, throughput tăng ~1.5-2x trên Hopper. Chất lượng gần như lossless.

### Requirements

- GPU: Hopper (H100, H200) hoặc Ada Lovelace (L40S, RTX 4090)
- TensorRT-LLM ≥ 0.9.0
- Calibration dataset (512-1024 samples đủ)

### Quantize + Build

```bash
# Step 1: Quantize (cần calibration data)
python ../quantization/quantize.py \
  --model_dir /models/Llama-3.1-8B-Instruct \
  --output_dir /engines/llama-8b-fp8/ckpt \
  --dtype float16 \
  --qformat fp8 \
  --calib_size 512

# Step 2: Build engine
trtllm-build \
  --checkpoint_dir /engines/llama-8b-fp8/ckpt \
  --output_dir /engines/llama-8b-fp8/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 128 \
  --max_input_len 2048 \
  --max_seq_len 4096
```

## INT4 AWQ Quantization Workflow

INT4 AWQ giảm ~75% memory so với FP16. Phù hợp khi VRAM hạn chế.

### Quantize + Build

```bash
# Step 1: Quantize to INT4 AWQ
python ../quantization/quantize.py \
  --model_dir /models/Llama-3.1-8B-Instruct \
  --output_dir /engines/llama-8b-int4/ckpt \
  --dtype float16 \
  --qformat int4_awq \
  --calib_size 512

# Step 2: Build engine
trtllm-build \
  --checkpoint_dir /engines/llama-8b-int4/ckpt \
  --output_dir /engines/llama-8b-int4/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 128 \
  --max_input_len 2048 \
  --max_seq_len 4096
```

## INT8 SmoothQuant Workflow

INT8 SmoothQuant — balance giữa quality và compression. Chạy trên Ampere trở lên.

```bash
# Quantize to INT8 SmoothQuant
python ../quantization/quantize.py \
  --model_dir /models/Llama-3.1-8B-Instruct \
  --output_dir /engines/llama-8b-int8/ckpt \
  --dtype float16 \
  --qformat int8_sq \
  --calib_size 512

# Build engine
trtllm-build \
  --checkpoint_dir /engines/llama-8b-int8/ckpt \
  --output_dir /engines/llama-8b-int8/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 64 \
  --max_input_len 2048 \
  --max_seq_len 4096
```

## Quantization Comparison

| Method | Memory Reduction | Throughput Gain | Quality Impact | Min GPU |
|---|---|---|---|---|
| FP8 | ~50% vs FP16 | ~1.5-2x | Near lossless | Hopper/Ada |
| INT4 AWQ | ~75% vs FP16 | ~2-3x | Slight degradation | Ampere+ |
| INT8 SmoothQuant | ~50% vs FP16 | ~1.3-1.5x | Minimal | Ampere+ |
| FP16 (baseline) | — | 1x | — | Volta+ |

## Multi-GPU Build

### Tensor Parallelism (TP)

TP chia model weights theo attention heads. Dùng khi model không fit 1 GPU.

```bash
# Convert với TP=4
python convert_checkpoint.py \
  --model_dir /models/Llama-3.1-70B-Instruct \
  --output_dir /engines/llama-70b-tp4/ckpt \
  --dtype float16 \
  --tp_size 4

# Build (trtllm-build tự detect TP từ checkpoint)
trtllm-build \
  --checkpoint_dir /engines/llama-70b-tp4/ckpt \
  --output_dir /engines/llama-70b-tp4/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 64 \
  --max_input_len 4096 \
  --max_seq_len 8192
```

### Pipeline Parallelism (PP)

PP chia model layers theo stages. Dùng khi TP không đủ hoặc muốn scale beyond NVLink domain.

```bash
# Convert với TP=4, PP=2 (tổng 8 GPUs)
python convert_checkpoint.py \
  --model_dir /models/Llama-3.1-405B-Instruct \
  --output_dir /engines/llama-405b-tp4pp2/ckpt \
  --dtype float16 \
  --tp_size 4 \
  --pp_size 2

# Build
trtllm-build \
  --checkpoint_dir /engines/llama-405b-tp4pp2/ckpt \
  --output_dir /engines/llama-405b-tp4pp2/engine \
  --gemm_plugin float16 \
  --gpt_attention_plugin float16 \
  --max_batch_size 32 \
  --max_input_len 4096 \
  --max_seq_len 8192 \
  --reduce_fusion
```

### TP/PP Size Selection

| Model Size | TP Size | PP Size | Total GPUs | GPU Type |
|---|---|---|---|---|
| 7-8B | 1 | 1 | 1 | 1x 24GB+ |
| 13B | 1-2 | 1 | 1-2 | 1x 40GB+ or 2x 24GB |
| 34B | 2 | 1 | 2 | 2x 24GB+ |
| 70B | 4 | 1 | 4 | 4x 24GB or 2x 80GB |
| 70B (FP8) | 2 | 1 | 2 | 2x 80GB (Hopper) |
| 405B | 4 | 2 | 8 | 8x 80GB |

## Build Time Estimation

Build time phụ thuộc vào model size, max_seq_len, và GPU. Rough estimates:

| Model Size | GPU | Approx Build Time |
|---|---|---|
| 7-8B | A100 80GB | 5-15 min |
| 13B | A100 80GB | 10-25 min |
| 70B (TP=4) | 4x A100 80GB | 20-45 min |
| 70B (FP8, TP=2) | 2x H100 80GB | 15-30 min |
| 405B (TP=4, PP=2) | 8x H100 80GB | 45-90 min |

Tips giảm build time:
- `--strongly_typed` giảm ~20-30% build time
- NGC container thường build nhanh hơn pip install (optimized TensorRT)
- Build trên cùng GPU architecture sẽ deploy (cross-arch build không support)

## Engine File Structure

Sau khi build thành công, output dir chứa:

```
/engines/llama-8b/engine/
├── config.json          # Engine metadata (max_batch_size, max_seq_len, dtype, TP/PP)
├── rank0.engine         # TensorRT engine file (1 per GPU rank)
├── rank1.engine         # (nếu TP > 1)
└── ...
```

**Lưu ý quan trọng:**
- Engine files KHÔNG portable giữa GPU architectures (A100 engine ≠ H100 engine)
- Engine files tied vào TensorRT-LLM version — upgrade TRT-LLM → rebuild
- `config.json` chứa max_batch_size/max_seq_len — runtime không thể exceed giá trị này
