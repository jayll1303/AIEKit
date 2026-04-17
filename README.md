<p align="center">
  <img src="assets/banner.png" alt="AIE-Skills Banner" width="100%" />
</p>

<p align="center">
  <video src="https://github.com/user-attachments/assets/ad39c9c4-da5b-429a-8301-4ca6fb6c3c81" width="100%" autoplay loop muted playsinline></video>
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/Kiro-Skills-6C5CE7?style=for-the-badge&logoColor=white" alt="Kiro Skills" /></a>
  <a href="#"><img src="https://img.shields.io/badge/AI%2FML-Engineering-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white" alt="AI/ML Engineering" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" /></a>
  <a href="#"><img src="https://img.shields.io/badge/CUDA-76B900?style=for-the-badge&logo=nvidia&logoColor=white" alt="CUDA" /></a>
  <a href="#"><img src="https://img.shields.io/badge/HuggingFace-FFD21E?style=for-the-badge&logo=huggingface&logoColor=black" alt="HuggingFace" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" /></a>
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/Core_Skills-6-blue?style=flat-square" alt="Core Skills" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Total_Skills-32-blue?style=flat-square" alt="Total Skills" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Profiles-6-teal?style=flat-square" alt="Profiles" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Steering-6-green?style=flat-square" alt="Steering" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Powers-4-purple?style=flat-square" alt="Powers" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg?style=flat-square" alt="Maintained" /></a>
  <a href="#"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License" /></a>
</p>

<h1 align="center">AIE-Skills</h1>

<p align="center">
  Bộ Kiro Skills & Steering cho workflow AI/ML Engineering — từ setup Python project, fine-tune LLM, đến deploy inference server.
</p>

---

## Quickstart

### One-liner Install

Install core skills (6 skills — default):

```bash
curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash
```

Install core + a specific profile:

```bash
curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash -s -- --profile llm
```

Combine multiple profiles:

```bash
curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash -s -- --profile llm,inference
```

Install ALL 32 skills:

```bash
curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash -s -- --all
```

Install vào thư mục cụ thể:

```bash
curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash -s -- /path/to/project
```

Install globally (vào ~/.kiro/):

```bash
curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash -s -- --global
```

Include Powers (MCP integrations, disabled by default):

```bash
curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash -s -- -p
```

Install specific skills (comma-separated):

```bash
curl -fsSL https://raw.githubusercontent.com/jayll1303/AIEKit/main/install.sh | bash -s -- --skill ultralytics-yolo,paddleocr
```

- Mặc định chỉ cài **6 core skills** — đủ dùng cho hầu hết project
- Dùng `--profile` để thêm skills theo domain, `--skill` để cài skills cụ thể, hoặc `--all` để cài toàn bộ 32 skills
- `--skill` tự động cài steering files tương ứng theo skill-level mapping
- `--json` flag cho machine-readable output (dùng cho agent/programmatic integration)
- Script chỉ copy components chưa tồn tại — không overwrite file đã có
- Powers (MCP) không được cài mặc định

### Smart Install (recommended)

Dùng skill `aie-skills-installer` trong Kiro — nó sẽ:

1. Scan codebase target (deps, imports, Dockerfiles, notebooks...)
2. Recommend chỉ skills có signal cụ thể từ project (bổ sung thêm vào Core_Set đã cài)
3. Chờ user confirm trước khi cài
4. Gọi `install.sh --skill <skills> --json` để cài selective + steering files tương ứng

### Manual Install

```bash
git clone https://github.com/jayll1303/AIEKit.git /tmp/aie-skills
bash /tmp/aie-skills/install.sh          # core only
bash /tmp/aie-skills/install.sh --profile llm   # core + llm
bash /tmp/aie-skills/install.sh --all     # all 32 skills
rm -rf /tmp/aie-skills
```

---

## Installation Profiles

Mặc định, installer cài 6 **core skills** — foundation cho mọi AI/ML project:

| Core Skill | Mô tả |
|------------|--------|
| `aie-skills-installer` | Analyze project và đề xuất skills cần thiết |
| `python-project-setup` | Bootstrap Python projects với uv, ruff, pytest |
| `python-ml-deps` | Cài ML deps với uv, xử lý CUDA version conflicts |
| `hf-hub-datasets` | Download, upload, stream models & datasets từ HuggingFace Hub |
| `docker-gpu-setup` | Dockerfile & docker-compose cho GPU/CUDA workloads |
| `notebook-workflows` | Tạo & chỉnh sửa Jupyter/Colab notebooks programmatically |

Thêm skills theo domain bằng `--profile`:

| Profile | Flag | Skills | Mô tả |
|---------|------|--------|--------|
| **llm** | `--profile llm` | `hf-transformers-trainer`, `unsloth-training`, `model-quantization`, `experiment-tracking` | Fine-tune LLMs (Trainer, Unsloth, LoRA) |
| **inference** | `--profile inference` | `vllm-tgi-inference`, `sglang-serving`, `llama-cpp-inference`, `ollama-local-llm`, `tensorrt-llm`, `triton-deployment` | Deploy LLM servers (vLLM, SGLang, Ollama) |
| **speech** | `--profile speech` | `k2-training-pipeline`, `sherpa-onnx`, `hf-speech-to-speech-pipeline`, `openai-audio-api` | Speech processing (Kaldi, sherpa-onnx) |
| **cv** | `--profile cv` | `ultralytics-yolo`, `paddleocr` | Computer vision (YOLO, PaddleOCR) |
| **rag** | `--profile rag` | `text-embeddings-rag`, `text-embeddings-inference`, `semantic-router` | RAG pipelines (embeddings, vector DB, routing) |
| **backend** | `--profile backend` | `fastapi-at-scale`, `opentelemetry`, `python-quality-testing` | FastAPI, OpenTelemetry, testing |

Combine profiles: `install.sh --profile llm,inference` — cài core + cả hai profiles, tự deduplicate.

**Standalone skills** (chỉ có qua `--all` hoặc Kiro smart installer): `arxiv-reader`, `freqtrade`, `ml-brainstorm`

---

## Skills (32)

| Skill | Mô tả |
|-------|--------|
| `aie-skills-installer` | Analyze target project codebase và đề xuất chỉ cài skills cần thiết (tránh cài toàn bộ tốn context) |
| `arxiv-reader` | Đọc và phân tích paper arXiv qua HTML |
| `disk-cleanup` | Diagnose and clean disk space on Linux servers, especially ML/LLM servers with Docker |
| `docker-gpu-setup` | Dockerfile & docker-compose cho GPU/CUDA workloads |
| `experiment-tracking` | Selfhosted experiment tracking với MLflow / W&B |
| `fastapi-at-scale` | Build production-grade FastAPI at scale: project structure, async SQLAlchemy, Alembic migrations, JWT auth, rate limiting, testing với httpx, deploy uvicorn/gunicorn/Docker |
| `freqtrade` | Phát triển crypto trading strategies với Freqtrade |
| `hf-hub-datasets` | Download, upload, stream models & datasets từ HuggingFace Hub |
| `hf-speech-to-speech-pipeline` | Architecture patterns cho huggingface/speech-to-speech queue-chained pipeline: STT/LLM/TTS handlers, VAD, progressive streaming |
| `hf-transformers-trainer` | Fine-tune & align LLMs với Trainer, TRL, PEFT (LoRA/QLoRA) |
| `k2-training-pipeline` | Train speech models với Next-gen Kaldi: k2 (FSA/FST loss), icefall (Zipformer/Conformer recipes), lhotse (data prep) |
| `llama-cpp-inference` | Chạy GGUF models locally với llama-server, llama-cli, llama-cpp-python (CPU+GPU) |
| `ml-brainstorm` | Brainstorm ML/AI technical decisions: training strategy, model selection, serving engine, quantization, pipeline architecture |
| `model-quantization` | Quantize LLMs với GGUF, GPTQ, AWQ, bitsandbytes |
| `notebook-workflows` | Tạo & chỉnh sửa Jupyter/Colab notebooks programmatically |
| `ollama-local-llm` | Chạy và quản lý local LLMs với Ollama: pull, run, Modelfile, REST API |
| `openai-audio-api` | Build OpenAI-compatible audio/speech APIs với FastAPI: concurrency control, dynamic batching, streaming synthesis, adapter pattern |
| `opentelemetry` | Instrument apps với OpenTelemetry cho distributed tracing, metrics, logs. Auto/manual instrumentation Python/Node.js, OTel Collector pipelines, sampling strategies, K8s deployment |
| `paddleocr` | OCR với PaddlePaddle: text detection, recognition, fine-tuning, dataset prep, PP-OCRv5, PP-StructureV3 |
| `python-ml-deps` | Cài ML deps với uv, xử lý CUDA version conflicts |
| `python-project-setup` | Bootstrap Python projects với uv, ruff, pytest |
| `python-quality-testing` | Type annotations, Hypothesis testing, mutation testing |
| `semantic-router` | Build superfast AI decision layers: Route, SemanticRouter, HybridRouter, dynamic routes với function calling, intent classification, Pinecone/Qdrant index |
| `sglang-serving` | Serve LLMs với SGLang: RadixAttention prefix caching, structured output (JSON/regex/EBNF) |
| `sherpa-onnx` | Offline speech processing: ASR, TTS, VAD, speaker diarization, speech enhancement |
| `tensorrt-llm` | Optimize LLM inference với NVIDIA TensorRT-LLM: engine building, FP8/INT4, kernel fusion |
| `text-embeddings-inference` | Deploy embedding/reranker models với HuggingFace TEI |
| `text-embeddings-rag` | RAG pipelines với sentence-transformers, FAISS, ChromaDB, Qdrant |
| `triton-deployment` | Deploy models trên NVIDIA Triton Inference Server |
| `ultralytics-yolo` | Train, predict, export, deploy YOLO models (detect, segment, classify, pose, OBB) với Ultralytics |
| `unsloth-training` | Fine-tune LLMs 2x faster, 70% less VRAM với Unsloth: SFT/DPO/GRPO, export GGUF/vLLM |
| `vllm-tgi-inference` | Serve LLMs locally với vLLM hoặc TGI |

## Steering (6)

| File | Inclusion | Mô tả |
|------|-----------|--------|
| `kiro-component-creation.md` | `always` → `auto` khi install | Quy tắc tạo Steering, Skills, Hooks, Powers cho Kiro |
| `notebook-conventions.md` | `fileMatch` (`**/*.ipynb`) | Conventions khi làm việc với file `.ipynb` |
| `ml-training-workflow.md` | `auto` | Conventions cho ML training & fine-tuning workflows |
| `inference-deployment.md` | `auto` | Conventions cho model serving & deployment |
| `python-project-conventions.md` | `auto` | Conventions cho Python projects: uv, ruff, pytest, CUDA deps |
| `gpu-environment.md` | `fileMatch` (`Dockerfile*`, `docker-compose*`, `.dockerignore`) | Conventions cho GPU Docker containers |

## Hooks (6) — Development only

> **Note:** Hooks là development-only — dùng cho việc phát triển repo AIE-Skills. Chúng **KHÔNG** được cài vào target projects bởi installer. Hooks chỉ tồn tại trong repo gốc để hỗ trợ quy trình phát triển.

| Hook | Event | Mô tả |
|------|-------|--------|
| `update-readme-index` | `fileEdited` | Auto-update README index khi edit component, commit + push (cần confirm) |
| `readme-index-on-create` | `fileCreated` | Auto-update README index khi tạo component mới, commit + push (cần confirm) |
| `readme-index-on-delete` | `fileDeleted` | Auto-update README index khi xóa component, commit + push (cần confirm) |
| `skill-quality-gate` | `fileCreated` | Check SKILL.md mới theo best practices + update interconnection map |
| `skill-quality-on-edit` | `fileEdited` | Check SKILL.md đã sửa theo best practices + interconnection map |
| `steering-consistency` | `fileCreated` | Check steering mới: frontmatter, domain overlap, cross-references |

## Powers (4) — Optional, not installed by default

Powers require MCP server auth/API keys. Install via `aie-skills-installer` skill or manual copy.
MCP servers ship `"disabled": true` — enable after configuring credentials.

| Power | MCP Server | Mô tả |
|-------|------------|--------|
| `power-huggingface` | [HF MCP Server](https://huggingface.co/mcp) (remote HTTP) | Search models, datasets, papers, spaces trên HuggingFace Hub. Compare models, check configs, discover trending papers |
| `power-gpu-monitor` | [mcp-system-monitor](https://github.com/huhabla/mcp-system-monitor) (local Python) | Monitor GPU/VRAM/CPU real-time, estimate memory cho ML models, diagnose OOM errors |
| `power-remotion` | [@remotion/mcp](https://www.remotion.dev/) (local npx) | Remotion documentation và video creation workflows via MCP |
| `power-sentry` | [@sentry/mcp-server](https://github.com/getsentry/sentry-mcp) (local npx) | Integrate Sentry SDK cho error tracking, performance monitoring, debug production issues via MCP. Setup patterns cho JS, Python, React, Next.js, FastAPI |

Mỗi power bao gồm: `POWER.md` + `mcp.json` (disabled) + optional `steering/` workflows.
