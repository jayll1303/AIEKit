# AIE-Skills

Bộ Kiro Skills & Steering dành cho workflow AI/ML Engineering — từ setup Python project, fine-tune LLM, đến deploy inference server.

## Skills (25)

| Skill | Mô tả |
|-------|--------|
| `aie-skills-installer` | Install AIE-Skills (skills, steering, hooks) vào bất kỳ Kiro project nào |
| `arxiv-reader` | Đọc và phân tích paper arXiv qua HTML |
| `docker-gpu-setup` | Dockerfile & docker-compose cho GPU/CUDA workloads |
| `experiment-tracking` | Selfhosted experiment tracking với MLflow / W&B |
| `freqtrade` | Phát triển crypto trading strategies với Freqtrade |
| `hf-hub-datasets` | Download, upload, stream models & datasets từ HuggingFace Hub |
| `hf-transformers-trainer` | Fine-tune & align LLMs với Trainer, TRL, PEFT (LoRA/QLoRA) |
| `k2-training-pipeline` | Train speech models với Next-gen Kaldi: k2 (FSA/FST loss), icefall (Zipformer/Conformer recipes), lhotse (data prep) |
| `llama-cpp-inference` | Chạy GGUF models locally với llama-server, llama-cli, llama-cpp-python (CPU+GPU) |
| `model-quantization` | Quantize LLMs với GGUF, GPTQ, AWQ, bitsandbytes |
| `notebook-workflows` | Tạo & chỉnh sửa Jupyter/Colab notebooks programmatically |
| `ollama-local-llm` | Chạy và quản lý local LLMs với Ollama: pull, run, Modelfile, REST API |
| `paddleocr` | OCR với PaddlePaddle: text detection, recognition, fine-tuning, dataset prep, PP-OCRv5, PP-StructureV3 |
| `python-ml-deps` | Cài ML deps với uv, xử lý CUDA version conflicts |
| `python-project-setup` | Bootstrap Python projects với uv, ruff, pytest |
| `python-quality-testing` | Type annotations, Hypothesis testing, mutation testing |
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
| `kiro-component-creation.md` | `always` | Quy tắc tạo Steering, Skills, Hooks, Powers cho Kiro |
| `notebook-conventions.md` | `fileMatch` (`**/*.ipynb`) | Conventions khi làm việc với file `.ipynb` |
| `ml-training-workflow.md` | `auto` | Conventions cho ML training & fine-tuning workflows |
| `inference-deployment.md` | `auto` | Conventions cho model serving & deployment |
| `python-project-conventions.md` | `auto` | Conventions cho Python projects: uv, ruff, pytest, CUDA deps |
| `gpu-environment.md` | `fileMatch` (`Dockerfile*`, `docker-compose*`) | Conventions cho GPU Docker containers |

## Hooks (6)

| Hook | Event | Mô tả |
|------|-------|--------|
| `update-readme-index` | `fileEdited` | Auto-update README index khi edit component, commit + push (cần confirm) |
| `readme-index-on-create` | `fileCreated` | Auto-update README index khi tạo component mới, commit + push (cần confirm) |
| `readme-index-on-delete` | `fileDeleted` | Auto-update README index khi xóa component, commit + push (cần confirm) |
| `skill-quality-gate` | `fileCreated` | Check SKILL.md mới theo best practices + update interconnection map |
| `skill-quality-on-edit` | `fileEdited` | Check SKILL.md đã sửa theo best practices + interconnection map |
| `steering-consistency` | `fileCreated` | Check steering mới: frontmatter, domain overlap, cross-references |

## Powers (2)

| Power | MCP Server | Mô tả |
|-------|------------|--------|
| `power-huggingface` | [HF MCP Server](https://huggingface.co/mcp) (remote HTTP) | Search models, datasets, papers, spaces trên HuggingFace Hub. Compare models, check configs, discover trending papers |
| `power-gpu-monitor` | [mcp-system-monitor](https://github.com/huhabla/mcp-system-monitor) (local Python) | Monitor GPU/VRAM/CPU real-time, estimate memory cho ML models, diagnose OOM errors |

Mỗi power bao gồm: `POWER.md` + `mcp.json` + `steering/` workflows.

## Installation (inspired from [everything-claude-code](https://github.com/affaan-m/everything-claude-code/blob/main/.kiro/install.sh))

Copy toàn bộ skills, steering, hooks vào project khác:

```bash
# Clone repo
git clone <repo-url> /tmp/aie-skills

# Install vào project hiện tại
bash /tmp/aie-skills/.kiro/install.sh

# Hoặc install vào thư mục cụ thể
bash /tmp/aie-skills/.kiro/install.sh /path/to/your/project

# Install globally (vào ~/.kiro/)
bash /tmp/aie-skills/.kiro/install.sh ~
```

Script chỉ copy components chưa tồn tại — không overwrite file đã có.

## Docs

| File | Mô tả |
|------|--------|
| `docs/kiro-compatible.md` | Tài liệu tham khảo về Kiro components |
| `docs/skill-creation-best-practices.md` | Best practices khi tạo skills |
| `docs/skill-interconnection-map.md` | Bản đồ quan hệ giữa 25 skills — layers, dependencies, workflow chains |
