---
name: llama-cpp-inference
description: "Run GGUF models locally with llama.cpp ecosystem. Use when launching llama-server, running llama-cli, using llama-cpp-python bindings, configuring GGUF inference on CPU+GPU, tuning continuous batching, or setting up local GGUF model serving."
---

# llama.cpp Inference

Server launch patterns, CLI usage, and Python bindings for running GGUF models locally with llama.cpp. Covers llama-server (OpenAI-compatible API), llama-cli (interactive/batch), llama-cpp-python, CPU+GPU inference, continuous batching, and context management.

## Scope

This skill handles:
- Launching llama-server with OpenAI-compatible API endpoints for GGUF models
- Running llama-cli for interactive chat, batch completion, and benchmarking
- Using llama-cpp-python bindings for programmatic GGUF inference
- Configuring GPU offloading (-ngl), context size, and parallel slots
- Tuning continuous batching, flash attention, and speculative decoding
- Diagnosing CUDA detection failures, OOM, slow generation, and model format errors

Does NOT handle:
- Converting/quantizing models to GGUF format (convert_hf_to_gguf.py, llama-quantize) (→ model-quantization)
- Ollama model management and serving (uses llama.cpp internally but different interface) (→ ollama-local-llm)
- vLLM or TGI inference serving (→ vllm-tgi-inference)
- Building GPU-enabled Docker containers (→ docker-gpu-setup)

## When to Use

- Launching a local GGUF model server with OpenAI-compatible API
- Running interactive chat or batch inference with llama-cli
- Using llama-cpp-python for GGUF inference in Python applications
- Configuring GPU layer offloading for mixed CPU+GPU inference
- Setting up multi-user serving with continuous batching
- Tuning context size, parallel slots, and flash attention
- Choosing between llama.cpp, Ollama, and vLLM for local inference

## Tool Decision Table

| Scenario | Recommended Tool | Key Config | Why |
|---|---|---|---|
| Maximum control, custom builds | llama-server | `-m`, `-ngl`, `-c` | Full flag control, any GGUF, CPU+GPU mix |
| Easiest setup, model management | Ollama | `ollama run` | One-command setup, auto-downloads models |
| Highest GPU throughput, production | vLLM | `--model`, `--tensor-parallel-size` | PagedAttention, continuous batching at scale |
| Python app embedding | llama-cpp-python | `Llama()` class | Native Python API, no server needed |
| CPU-only inference | llama-server / llama-cli | `-ngl 0` | Optimized CPU kernels (AVX2/AVX512) |
| Embedding generation | llama-server | `--embedding` | Built-in `/v1/embeddings` endpoint |
| Edge / low-resource devices | llama-cli | `-ngl 0 -t 4` | Minimal footprint, no server overhead |

**Rules of thumb**:
- **llama.cpp** khi cần full control, custom build, hoặc CPU+GPU mix inference.
- **Ollama** khi cần setup nhanh, không cần tuning sâu.
- **vLLM** khi cần throughput cao nhất trên GPU, production batching.

## llama-server Quick Start

⚠️ **HARD GATE:** Do NOT launch server trước khi xác nhận GGUF file tồn tại và ước lượng VRAM. Rule of thumb: GGUF file size ≈ VRAM cần (Q4_K_M 7B ≈ 4.1 GB). Chạy `ls -lh model.gguf` và `nvidia-smi` trước.

```bash
# Download GGUF model
huggingface-cli download TheBloke/Llama-2-7B-Chat-GGUF \
  llama-2-7b-chat.Q4_K_M.gguf --local-dir ./models

# Launch server
llama-server -m ./models/llama-2-7b-chat.Q4_K_M.gguf \
  --host 0.0.0.0 --port 8080 \
  -c 4096 -ngl 99 --chat-template llama2
```

**Validate:** `curl -s http://localhost:8080/health` returns `{"status":"ok"}`. Nếu không → check server logs, verify GGUF path, và `nvidia-smi` cho VRAM.

### Test API

```bash
# Chat completion (OpenAI-compatible)
curl -s http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-2-7b-chat",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7,
    "max_tokens": 128
  }' | python -m json.tool
```

## Key Server Flags

| Flag | Default | Description |
|---|---|---|
| `-m, --model` | required | Path to GGUF model file |
| `-c, --ctx-size` | 4096 | Context size (tokens). Ảnh hưởng trực tiếp đến VRAM |
| `-ngl, --n-gpu-layers` | 0 | Số layers offload lên GPU. `99` = full offload |
| `-np, --parallel` | 1 | Số parallel slots cho multi-user serving |
| `--host` | 127.0.0.1 | Bind address |
| `--port` | 8080 | Listen port |
| `-t, --threads` | auto | Số CPU threads cho inference |
| `--chat-template` | auto | Chat template: llama2, chatml, phi, gemma, etc. |
| `--embedding` | false | Enable embedding endpoint `/v1/embeddings` |
| `-fa, --flash-attn` | false | Enable flash attention (giảm VRAM, tăng speed) |
| `-cb, --cont-batching` | true | Continuous batching (auto-enabled khi `-np > 1`) |
| `--no-mmap` | false | Disable memory mapping (dùng khi mmap gây issues) |

> For detailed server flags, continuous batching, chat templates, and API endpoints, see [Server Config reference](references/server-config.md)

## llama-cpp-python Quick Start

```python
from llama_cpp import Llama

# Load model
llm = Llama(
    model_path="./models/model.Q4_K_M.gguf",
    n_gpu_layers=-1,   # -1 = offload tất cả layers lên GPU
    n_ctx=4096,         # Context window
    verbose=False,
)

# Chat completion
output = llm.create_chat_completion(
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello!"},
    ],
    temperature=0.7,
    max_tokens=256,
)
print(output["choices"][0]["message"]["content"])

# Streaming
for chunk in llm.create_chat_completion(
    messages=[{"role": "user", "content": "Write a haiku about code."}],
    stream=True,
):
    delta = chunk["choices"][0]["delta"]
    if "content" in delta:
        print(delta["content"], end="", flush=True)
```

### OpenAI-Compatible Server (Python)

```python
from llama_cpp.server.app import create_app, Settings

settings = Settings(
    model="./models/model.Q4_K_M.gguf",
    n_gpu_layers=-1,
    n_ctx=4096,
    chat_format="llama-2",
)
app = create_app(settings=settings)
# Run with: uvicorn main:app --host 0.0.0.0 --port 8080
```

> For build instructions and GPU backend setup, see [Build & Backends reference](references/build-and-backends.md)

## GPU Offloading

`-ngl` (number of GPU layers) controls bao nhiêu transformer layers chạy trên GPU:

| Setting | Behavior | When to Use |
|---|---|---|
| `-ngl 0` | CPU only | Không có GPU hoặc VRAM quá nhỏ |
| `-ngl 20` | Partial offload | GPU VRAM không đủ cho full model |
| `-ngl 99` | Full offload (all layers) | GPU VRAM đủ cho toàn bộ model |
| `-ngl -1` | Auto (llama-cpp-python) | Python bindings: offload tất cả |

**Ước lượng VRAM cho GPU offload:**
- GGUF file size ≈ tổng VRAM cần khi full offload
- Partial offload: `(ngl / total_layers) × file_size` + context overhead
- Thêm ~200-500 MB cho context buffer tùy `-c` setting

## Performance Tuning

| Parameter | Flag | Impact | Recommendation |
|---|---|---|---|
| Context size | `-c` | Lớn hơn = nhiều VRAM hơn | Bắt đầu 4096, tăng nếu cần |
| Parallel slots | `-np` | Multi-user, chia sẻ KV cache | 2-8 cho multi-user serving |
| Flash attention | `-fa` | Giảm VRAM, tăng speed | Luôn bật nếu hardware hỗ trợ |
| Threads | `-t` | CPU inference speed | = số physical cores (không phải logical) |
| Batch size | `-b` | Prompt processing speed | 512-2048, tăng nếu prompt dài |
| Continuous batching | `-cb` | Multi-request throughput | Auto khi `-np > 1` |

## Diagnostic Checklist

```
Model fails to load or slow generation?
├─ CUDA / GPU not detected?
│   ├─ Check: nvidia-smi → GPU visible?
│   ├─ llama-server built with CUDA? → Check build log for GGML_CUDA
│   ├─ llama-cpp-python: CMAKE_ARGS="-DGGML_CUDA=on" pip install llama-cpp-python
│   └─ Verify: server log shows "offloading N layers to GPU"
│
├─ OOM (Out of Memory)?
│   ├─ Giảm -ngl (partial offload thay vì full)
│   ├─ Giảm -c (context size nhỏ hơn)
│   ├─ Giảm -np (ít parallel slots hơn)
│   ├─ Bật -fa (flash attention giảm VRAM)
│   └─ Dùng quantization level thấp hơn (Q4_K_M → Q3_K_M)
│
├─ Slow generation?
│   ├─ GPU offload đang hoạt động? → Check log "offloading N layers"
│   ├─ -t quá cao? → Set = số physical cores, không phải logical
│   ├─ mmap disabled? → Bật lại nếu không cần --no-mmap
│   ├─ Flash attention chưa bật? → Thêm -fa
│   └─ Context quá lớn? → Giảm -c nếu không cần full context
│
├─ Model format error?
│   ├─ "invalid model file" → File không phải GGUF hoặc bị corrupt
│   ├─ "unsupported model architecture" → llama.cpp chưa support architecture này
│   ├─ Download lại: huggingface-cli download --force
│   └─ Check GGUF version compatibility với llama.cpp version
│
└─ Chat template issues?
    ├─ Output lạ / không follow instructions → Sai chat template
    ├─ Dùng --chat-template phù hợp: llama2, chatml, phi, gemma
    └─ Check model card trên HuggingFace cho đúng template
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "GGUF nào cũng chạy được, cứ download rồi serve" | Phải check architecture support trong llama.cpp. Không phải mọi model đều có GGUF, và GGUF version phải compatible với llama.cpp version đang dùng. |
| "-ngl 99 luôn cho nhanh nhất" | Chỉ đúng khi GPU VRAM đủ. Nếu VRAM không đủ → OOM hoặc swap chậm hơn CPU. Ước lượng VRAM trước, dùng partial offload nếu cần. |
| "Không cần chat template, model tự hiểu" | Sai template = output garbage. Mỗi model family cần đúng template (llama2, chatml, phi...). Check model card. |
| "Tăng -c lên max cho flexible" | Context size ảnh hưởng trực tiếp đến VRAM. -c 32768 trên GPU 8GB = OOM. Bắt đầu nhỏ (4096), tăng dần. |
| "llama-cpp-python chậm → chuyển sang vLLM" | Có thể chưa build với CUDA. Check `CMAKE_ARGS="-DGGML_CUDA=on"`. Nếu đã có GPU offload mà vẫn chậm → mới consider alternatives. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to convert/quantize model to GGUF format | model-quantization | Handles convert_hf_to_gguf.py, llama-quantize, imatrix workflows |
| Want Ollama instead of raw llama.cpp | ollama-local-llm | Simpler model management, auto-downloads, less config |
| Need high-throughput GPU serving (vLLM/TGI) | vllm-tgi-inference | PagedAttention, tensor parallelism, production batching |
| CUDA/cuDNN issues when building llama.cpp or llama-cpp-python | python-ml-deps | Resolves CUDA toolkit, driver version conflicts |
| Need to download GGUF models from HuggingFace Hub | hf-hub-datasets | Handles huggingface-cli download, private repos, gated models |
| Need GPU Docker container for llama-server | docker-gpu-setup | NVIDIA Container Toolkit, docker-compose GPU passthrough |

## References

- [Server Config](references/server-config.md) — All llama-server flags, continuous batching, chat templates, embedding mode, multi-user config, speculative decoding, and API endpoints
  **Load when:** configuring llama-server beyond basic launch, setting up multi-user serving, or using embedding/speculative decoding features
- [Build & Backends](references/build-and-backends.md) — Building from source with CMake, CUDA/Metal/Vulkan backends, llama-cpp-python GPU installation, pre-built binaries, and performance flags
  **Load when:** building llama.cpp from source, enabling GPU backends, installing llama-cpp-python with CUDA/Metal support, or troubleshooting build errors
