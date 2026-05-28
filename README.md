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
  <a href="#"><img src="https://img.shields.io/badge/Total_Skills-34-blue?style=flat-square" alt="Total Skills" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Profiles-7-teal?style=flat-square" alt="Profiles" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg?style=flat-square" alt="Maintained" /></a>
  <a href="#"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License" /></a>
</p>

<h1 align="center">AIE-Skills</h1>

<p align="center">
  Agent Skills cho AI/ML Engineering — từ setup Python project, fine-tune LLM, đến deploy inference server.
</p>

---

## Install

```bash
npx skills add jayll1303/AIEKit
```

Install specific skills:

```bash
npx skills add jayll1303/AIEKit --skill ultralytics-yolo --skill vllm-tgi-inference
```

Install globally (available across all projects):

```bash
npx skills add jayll1303/AIEKit -g
```

List available skills:

```bash
npx skills add jayll1303/AIEKit --list
```

> Requires Node.js >= 18. Uses [skills.sh](https://skills.sh) ecosystem.

---

## Skills (34)

| Skill | Mô tả |
|-------|--------|
| `aie-skills-installer` | Analyze target project codebase và đề xuất chỉ cài skills cần thiết |
| `arxiv-reader` | Đọc và phân tích paper arXiv qua HTML |
| `disk-cleanup` | Diagnose and clean disk space on Linux/ML servers with Docker |
| `docker-gpu-setup` | Dockerfile & docker-compose cho GPU/CUDA workloads |
| `experiment-tracking` | Selfhosted experiment tracking với MLflow / W&B |
| `fastapi-at-scale` | Production-grade FastAPI: async SQLAlchemy, Alembic, JWT, rate limiting, testing |
| `freqtrade` | Crypto trading strategies với Freqtrade |
| `hf-hub-datasets` | Download, upload, stream models & datasets từ HuggingFace Hub |
| `hf-speech-to-speech-pipeline` | Queue-chained speech pipeline: STT/LLM/TTS handlers, VAD, streaming |
| `hf-transformers-trainer` | Fine-tune & align LLMs với Trainer, TRL, PEFT (LoRA/QLoRA) |
| `k2-training-pipeline` | Train speech models với Next-gen Kaldi: k2, icefall, lhotse |
| `llama-cpp-inference` | Chạy GGUF models locally với llama-server, llama-cli, llama-cpp-python |
| `ml-brainstorm` | Brainstorm ML/AI decisions: training, model selection, serving, quantization |
| `modal-batch-processing` | Modal job orchestration: `.map`, `.starmap`, `.spawn`, `.spawn_map`, `@modal.batched` |
| `modal-sandbox` | Modal Sandbox lifecycle: isolated execution, tunnels, snapshots, file IO |
| `model-quantization` | Quantize LLMs với GGUF, GPTQ, AWQ, bitsandbytes |
| `notebook-workflows` | Tạo & chỉnh sửa Jupyter/Colab notebooks programmatically |
| `ollama-local-llm` | Chạy local LLMs với Ollama: pull, run, Modelfile, REST API |
| `openai-audio-api` | OpenAI-compatible audio/speech APIs với FastAPI, dynamic batching |
| `opentelemetry` | Distributed tracing, metrics, logs với OpenTelemetry |
| `paddleocr` | OCR với PaddlePaddle: detection, recognition, fine-tuning, PP-OCRv5 |
| `python-ml-deps` | Cài ML deps với uv, xử lý CUDA version conflicts |
| `python-project-setup` | Bootstrap Python projects với uv, ruff, pytest |
| `python-quality-testing` | Type annotations, Hypothesis testing, mutation testing |
| `semantic-router` | Superfast AI decision layers: Route, SemanticRouter, HybridRouter |
| `sglang-serving` | Serve LLMs với SGLang: RadixAttention, structured output |
| `sherpa-onnx` | Offline speech: ASR, TTS, VAD, speaker diarization |
| `tensorrt-llm` | Optimize LLM inference với TensorRT-LLM: FP8/INT4, kernel fusion |
| `text-embeddings-inference` | Deploy embedding/reranker models với HuggingFace TEI |
| `text-embeddings-rag` | RAG pipelines với sentence-transformers, FAISS, ChromaDB, Qdrant |
| `triton-deployment` | Deploy models trên NVIDIA Triton Inference Server |
| `ultralytics-yolo` | Train, predict, export YOLO models (detect, segment, pose, OBB) |
| `unsloth-training` | Fine-tune LLMs 2x faster, 70% less VRAM: SFT/DPO/GRPO |
| `vllm-tgi-inference` | Serve LLMs locally với vLLM hoặc TGI |

---

## Profiles

Skills được nhóm theo domain:

| Profile | Skills | Mô tả |
|---------|--------|--------|
| **Core** | `aie-skills-installer`, `python-project-setup`, `python-ml-deps`, `hf-hub-datasets`, `docker-gpu-setup`, `notebook-workflows` | Foundation cho mọi AI/ML project |
| **LLM** | `hf-transformers-trainer`, `unsloth-training`, `model-quantization`, `experiment-tracking` | Fine-tune LLMs |
| **Inference** | `vllm-tgi-inference`, `sglang-serving`, `llama-cpp-inference`, `ollama-local-llm`, `tensorrt-llm`, `triton-deployment` | Deploy LLM servers |
| **Speech** | `k2-training-pipeline`, `sherpa-onnx`, `hf-speech-to-speech-pipeline`, `openai-audio-api` | Speech processing |
| **CV** | `ultralytics-yolo`, `paddleocr` | Computer vision |
| **RAG** | `text-embeddings-rag`, `text-embeddings-inference`, `semantic-router` | RAG pipelines |
| **Backend** | `fastapi-at-scale`, `opentelemetry`, `python-quality-testing` | API & observability |
| **Modal** | `modal-batch-processing`, `modal-sandbox` | Modal platform orchestration |

**Standalone**: `arxiv-reader`, `disk-cleanup`, `freqtrade`, `ml-brainstorm`

---

## Smart Install

Sau khi cài, dùng skill `aie-skills-installer` trong agent — nó sẽ:

1. Scan codebase (deps, imports, Dockerfiles, notebooks...)
2. Recommend chỉ skills phù hợp với project
3. Chờ confirm trước khi cài thêm

---

## License

MIT
