# AIE-Skills

Bộ Kiro Skills & Steering dành cho workflow AI/ML Engineering — từ setup Python project, fine-tune LLM, đến deploy inference server.

## Skills (19)

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
| `model-quantization` | Quantize LLMs với GGUF, GPTQ, AWQ, bitsandbytes |
| `notebook-workflows` | Tạo & chỉnh sửa Jupyter/Colab notebooks programmatically |
| `python-ml-deps` | Cài ML deps với uv, xử lý CUDA version conflicts |
| `python-project-setup` | Bootstrap Python projects với uv, ruff, pytest |
| `python-quality-testing` | Type annotations, Hypothesis testing, mutation testing |
| `sherpa-onnx` | Offline speech processing: ASR, TTS, VAD, speaker diarization, speech enhancement |
| `text-embeddings-inference` | Deploy embedding/reranker models với HuggingFace TEI |
| `text-embeddings-rag` | RAG pipelines với sentence-transformers, FAISS, ChromaDB, Qdrant |
| `triton-deployment` | Deploy models trên NVIDIA Triton Inference Server |
| `ultralytics-yolo` | Train, predict, export, deploy YOLO models (detect, segment, classify, pose, OBB) với Ultralytics |
| `vllm-tgi-inference` | Serve LLMs locally với vLLM hoặc TGI |

## Steering (2)

| File | Inclusion | Mô tả |
|------|-----------|--------|
| `kiro-component-creation.md` | `always` | Quy tắc tạo Steering, Skills, Hooks, Powers cho Kiro |
| `notebook-conventions.md` | `fileMatch` (`**/*.ipynb`) | Conventions khi làm việc với file `.ipynb` |

## Hooks (3)

| Hook | Event | Mô tả |
|------|-------|--------|
| `update-readme-index` | `fileEdited` | Auto-update README index khi edit component, commit + push (cần confirm) |
| `readme-index-on-create` | `fileCreated` | Auto-update README index khi tạo component mới, commit + push (cần confirm) |
| `readme-index-on-delete` | `fileDeleted` | Auto-update README index khi xóa component, commit + push (cần confirm) |

## Powers

_Chưa có power nào._

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
