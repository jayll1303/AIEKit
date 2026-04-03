---
name: ollama-local-llm
description: "Run and manage local LLMs with Ollama. Use when running ollama run, ollama pull, creating Modelfiles, serving local LLM APIs, using ollama serve, or integrating Ollama REST/OpenAI-compatible API."
---

# Ollama — Local LLM Runner

CLI-first local LLM management: pull, run, create custom models via Modelfile, serve REST API and OpenAI-compatible endpoints. Covers model management, GPU/CPU configuration, and client integration patterns.

## Scope

This skill handles:
- Ollama CLI commands: pull, run, create, list, show, cp, rm, push, serve, ps
- Creating and customizing models via Modelfile (FROM, PARAMETER, SYSTEM, TEMPLATE)
- REST API usage: /api/generate, /api/chat, /api/embed, /api/tags
- OpenAI-compatible endpoint /v1/chat/completions for drop-in replacement
- GPU/CPU configuration: OLLAMA_NUM_GPU, OLLAMA_GPU_LAYERS, OLLAMA_HOST
- Importing GGUF models into Ollama
- Model management: tagging, copying, pushing to registry

Does NOT handle:
- Training or fine-tuning models (→ hf-transformers-trainer)
- Quantizing models to GGUF format from HuggingFace (→ model-quantization)
- Running llama.cpp server directly without Ollama wrapper (→ llama-cpp-inference)
- Docker GPU passthrough and NVIDIA Container Toolkit setup (→ docker-gpu-setup)

## When to Use

- Running a local LLM with a single `ollama run` command
- Pulling models from the Ollama library (llama3, mistral, codellama, etc.)
- Creating custom models with Modelfile (system prompts, parameters, templates)
- Serving a local OpenAI-compatible API for application integration
- Importing a GGUF file into Ollama for easy management
- Configuring GPU layer offloading for mixed CPU/GPU inference
- Building applications that call Ollama REST API or use the Python/JS client

## Decision Table: Ollama vs llama.cpp vs vLLM

| Scenario | Recommended | Why |
|---|---|---|
| Quick local chat, single user | Ollama | One command: `ollama run llama3` |
| Custom system prompt + params | Ollama | Modelfile bundles everything |
| App integration (OpenAI API) | Ollama | Built-in `/v1/chat/completions` |
| Import existing GGUF | Ollama | `FROM ./model.gguf` in Modelfile |
| Max throughput, multi-GPU | vLLM | PagedAttention, tensor parallelism |
| High-concurrency production | vLLM / TGI | Continuous batching, better scaling |
| Custom quantization levels | llama.cpp | Direct control over quant params |
| Embedding-only workload | Ollama or TEI | Ollama: `/api/embed`, TEI: dedicated |
| Fine-grained llama.cpp flags | llama.cpp | Ollama abstracts away low-level flags |

## Quick Start

### Step 1: Install

```bash
# Linux / WSL
curl -fsSL https://ollama.com/install.sh | sh

# macOS
brew install ollama

# Verify
ollama --version
```

⚠️ **HARD GATE:** Do NOT proceed trước khi verify: (1) `ollama --version` trả về version ≥ 0.1, (2) `nvidia-smi` hiển thị GPU nếu muốn GPU inference. Nếu không có GPU → Ollama tự fallback CPU nhưng sẽ chậm hơn nhiều.

**Validate:** `ollama --version` prints version ≥ 0.1. If not → check PATH or reinstall.

### Step 2: Pull and Run

```bash
# Pull a model
ollama pull llama3.1:8b

# Interactive chat
ollama run llama3.1:8b

# One-shot prompt
ollama run llama3.1:8b "Explain Docker in 3 sentences"
```
**Validate:** Model responds with text. If "model not found" → check `ollama list` and model name spelling.

### Step 3: Create Custom Model (Modelfile)

```dockerfile
# Modelfile
FROM llama3.1:8b

PARAMETER temperature 0.7
PARAMETER num_ctx 4096

SYSTEM """You are a senior Python developer. Answer concisely with code examples."""
```

```bash
ollama create python-assistant -f Modelfile
ollama run python-assistant
```
**Validate:** `ollama list` shows `python-assistant`. If create fails → check FROM model exists locally.

### Step 4: API Usage

```bash
# Start server (if not already running)
ollama serve &

# Chat completion
curl -s http://localhost:11434/api/chat -d '{
  "model": "llama3.1:8b",
  "messages": [{"role": "user", "content": "Hello!"}],
  "stream": false
}' | python -m json.tool

# OpenAI-compatible endpoint
curl -s http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }' | python -m json.tool
```
**Validate:** JSON response with `message.content`. If connection refused → `ollama serve` not running.

## CLI Commands Reference

| Command | Description | Example |
|---|---|---|
| `ollama pull` | Download model from library | `ollama pull llama3.1:8b` |
| `ollama run` | Run model (pull if needed) | `ollama run mistral "Hi"` |
| `ollama create` | Create model from Modelfile | `ollama create mymodel -f Modelfile` |
| `ollama list` | List local models | `ollama list` |
| `ollama show` | Show model info (params, template) | `ollama show llama3.1:8b` |
| `ollama cp` | Copy/tag a model | `ollama cp llama3.1:8b my-llama` |
| `ollama rm` | Delete a model | `ollama rm my-llama` |
| `ollama push` | Push model to registry | `ollama push user/mymodel` |
| `ollama serve` | Start API server | `ollama serve` |
| `ollama ps` | Show running models | `ollama ps` |

## REST API Quick Reference

| Endpoint | Method | Description |
|---|---|---|
| `/api/generate` | POST | Text completion (single turn) |
| `/api/chat` | POST | Chat completion (multi-turn) |
| `/api/embed` | POST | Generate embeddings |
| `/api/tags` | GET | List local models |
| `/api/show` | POST | Show model details |
| `/api/pull` | POST | Pull a model |
| `/api/push` | POST | Push a model |
| `/api/create` | POST | Create model from Modelfile |
| `/api/delete` | DELETE | Delete a model |
| `/v1/chat/completions` | POST | OpenAI-compatible chat |
| `/v1/models` | GET | OpenAI-compatible model list |

## Modelfile Basics

```dockerfile
FROM llama3.1:8b              # Base model (required)

PARAMETER temperature 0.7      # Sampling temperature
PARAMETER top_p 0.9            # Nucleus sampling
PARAMETER num_ctx 8192         # Context window size
PARAMETER num_gpu 99           # GPU layers (-1 = auto, 0 = CPU only)

SYSTEM """You are a helpful coding assistant."""

TEMPLATE """{{ if .System }}<|system|>{{ .System }}<|end|>
{{ end }}<|user|>{{ .Prompt }}<|end|>
<|assistant|>"""
```

> For full Modelfile syntax, all PARAMETER options, templates for different use cases, and GGUF import patterns, see [Modelfile Guide](references/modelfile-guide.md)

## GPU Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `OLLAMA_NUM_GPU` | auto | Number of GPUs to use |
| `OLLAMA_GPU_LAYERS` | auto | Layers to offload to GPU (0 = CPU only) |
| `OLLAMA_HOST` | `127.0.0.1:11434` | Server bind address |
| `OLLAMA_MODELS` | `~/.ollama/models` | Model storage directory |
| `OLLAMA_MAX_LOADED_MODELS` | auto | Max models loaded simultaneously |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long to keep model in memory |

```bash
# Force CPU-only inference
OLLAMA_GPU_LAYERS=0 ollama serve

# Use specific GPU count
OLLAMA_NUM_GPU=1 ollama serve

# Bind to all interfaces (remote access)
OLLAMA_HOST=0.0.0.0:11434 ollama serve

# Custom model storage
OLLAMA_MODELS=/mnt/ssd/ollama ollama serve
```

## Troubleshooting

```
Model not found?
├─ Typo in model name → ollama list to check local models
├─ Not pulled yet → ollama pull <model>
└─ Tag mismatch → use exact tag: ollama pull llama3.1:8b

OOM / killed during inference?
├─ Model too large for VRAM → use smaller quant (e.g., :8b-q4_0)
├─ Context too long → reduce num_ctx in Modelfile
├─ Multiple models loaded → set OLLAMA_MAX_LOADED_MODELS=1
└─ CPU fallback → OLLAMA_GPU_LAYERS=0 ollama serve

Slow generation?
├─ Running on CPU → check ollama ps for GPU offload status
├─ Low GPU layers → increase num_gpu in Modelfile or OLLAMA_GPU_LAYERS
├─ Large context → reduce num_ctx if not needed
└─ Thermal throttling → check GPU temp with nvidia-smi

GPU not detected?
├─ NVIDIA driver not installed → nvidia-smi should show GPU
├─ CUDA not available → check nvidia-smi and driver version
├─ Docker without --gpus → use docker-gpu-setup skill
└─ AMD GPU → ensure ROCm is installed and supported

Connection refused on API?
├─ Server not running → ollama serve
├─ Wrong port → check OLLAMA_HOST setting
└─ Firewall blocking → check OLLAMA_HOST binds to 0.0.0.0 for remote
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Ollama chạy được mọi model HuggingFace" | Ollama chỉ chạy GGUF format. Model HF cần convert sang GGUF trước (→ model-quantization), hoặc dùng model có sẵn trên Ollama library. |
| "Cứ dùng model lớn nhất cho chất lượng tốt nhất" | Model 70B cần ~40 GB VRAM (Q4). Kiểm tra `ollama ps` và `nvidia-smi` trước. Model 8B Q4 chạy tốt trên 8 GB VRAM. |
| "Ollama thay thế được vLLM cho production" | Ollama tối ưu cho single-user/dev. Production high-concurrency cần vLLM/TGI với continuous batching và tensor parallelism. |
| "Không cần Modelfile, cứ ollama run là đủ" | Modelfile giúp fix system prompt, temperature, context length. Không dùng Modelfile = mỗi lần chạy phải set lại params. |
| "OLLAMA_GPU_LAYERS=999 để dùng hết GPU" | Dùng `num_gpu 99` trong Modelfile hoặc `-1` cho auto. Set quá cao không gây lỗi nhưng misleading. Ollama tự cap theo model size. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to convert HF model to GGUF for Ollama import | model-quantization | Handles convert_hf_to_gguf.py, llama-quantize workflows |
| Need high-concurrency production serving | vllm-tgi-inference | vLLM/TGI with continuous batching, tensor parallelism |
| Need Docker GPU setup for containerized Ollama | docker-gpu-setup | NVIDIA Container Toolkit, docker-compose GPU passthrough |
| Need to fine-tune a model before running in Ollama | hf-transformers-trainer | SFTTrainer, LoRA/QLoRA, then export → GGUF → Ollama |
| Need embeddings for RAG pipeline | text-embeddings-rag | Chunking, indexing, retrieval with FAISS/ChromaDB |

## References

- [Modelfile Guide](references/modelfile-guide.md) — Full Modelfile syntax, all PARAMETER options, chat/code/RAG templates, GGUF import, multi-stage builds
  **Load when:** creating or customizing Modelfiles, importing GGUF models, or configuring advanced parameters
- [API Integration](references/api-integration.md) — Full REST API reference, OpenAI-compatible endpoints, Python/JS clients, streaming, embeddings for RAG
  **Load when:** integrating Ollama API into applications, using Python/JS clients, or building RAG pipelines with Ollama embeddings
