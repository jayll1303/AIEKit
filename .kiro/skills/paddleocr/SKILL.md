---
name: paddleocr
description: "OCR with PaddlePaddle: PaddleOCR text detection, recognition, fine-tuning, dataset prep, PP-OCRv5, PP-StructureV3. Use when training OCR models, preparing OCR datasets, fine-tuning detection/recognition, exporting PaddleOCR inference models, or deploying OCR pipelines."
---

# PaddleOCR

Train, fine-tune, and deploy OCR models using PaddlePaddle's PaddleOCR toolkit. Covers PP-OCRv5 (detection + recognition), dataset preparation, fine-tuning workflows, model export, and deployment.

## Scope

This skill handles:
- Installing PaddlePaddle + PaddleOCR (CPU/GPU, CUDA versions)
- Preparing datasets for text detection and recognition (annotation format, PPOCRLabel)
- Fine-tuning text detection models (DB, PP-OCRv3/v5 det)
- Fine-tuning text recognition models (SVTR, PP-OCRv3/v5 rec)
- Configuring YAML training configs (learning rate, batch size, pretrained model)
- Exporting trained models to inference format
- Running inference with PaddleOCR Python API and CLI
- PP-StructureV3 for document parsing (layout, tables, formulas)

Does NOT handle:
- General Python project setup, ruff, pytest (→ python-project-setup)
- Installing CUDA-aware deps outside PaddlePaddle ecosystem (→ python-ml-deps)
- Building GPU Docker containers (→ docker-gpu-setup)
- Deploying on Triton Inference Server (→ triton-deployment)
- Non-OCR computer vision tasks like object detection (→ ultralytics-yolo)

## When to Use

- Installing PaddlePaddle and PaddleOCR for OCR tasks
- Preparing a custom dataset for text detection or recognition training
- Fine-tuning PP-OCR detection model on domain-specific images
- Fine-tuning PP-OCR recognition model on custom text/fonts
- Choosing between PP-OCRv3, v4, v5 models for a use case
- Exporting a trained PaddleOCR model to inference format
- Running OCR inference on images via Python API or CLI
- Parsing documents with PP-StructureV3 (layout, tables)
- Setting up PaddleOCR MCP server for LLM integration

## Installation Quick Reference

```bash
# CPU only
pip install paddlepaddle==3.2.0
pip install "paddleocr[all]"

# GPU (CUDA 11.8) — Linux
pip install paddlepaddle-gpu==3.2.0 -i https://www.paddlepaddle.org.cn/packages/stable/cu118/

# GPU (CUDA 12.6) — Linux
pip install paddlepaddle-gpu==3.2.0 -i https://www.paddlepaddle.org.cn/packages/stable/cu126/

# Verify
python -c "import paddle; print(paddle.__version__); print(paddle.device.is_compiled_with_cuda())"
```

**Validate:** `paddle.__version__` returns `3.x.x`. For GPU: `is_compiled_with_cuda()` returns `True`.

## PP-OCR Pipeline Architecture

```
Input Image
    │
    ├─ [Optional] Image Orientation Classification (PP-LCNet)
    ├─ [Optional] Text Image Unwarping (UVDoc)
    │
    ▼
Text Detection (DB / PP-HGNetV2)
    │
    ▼
Text Line Orientation Classification
    │
    ▼
Text Recognition (SVTR / PP-HGNetV2 + CTC)
    │
    ▼
Structured Text Output
```

## Model Selection Table

| Model | Type | Size | Best For |
|-------|------|------|----------|
| PP-OCRv5_mobile_det | Detection | ~4MB | Edge/mobile, fast inference |
| PP-OCRv5_server_det | Detection | ~100MB | High accuracy, GPU server |
| PP-OCRv5_mobile_rec | Recognition | ~15MB | Edge/mobile, CJK+EN+JP |
| PP-OCRv5_server_rec | Recognition | ~90MB | High accuracy, CJK+EN+JP |
| PP-OCRv3_mobile_det | Detection | ~3MB | Legacy, lighter |
| PP-OCRv3_mobile_rec | Recognition | ~12MB | Legacy, lighter |

**Decision guide:**
- Mobile/edge deployment → `mobile` variants
- Maximum accuracy on server → `server` variants
- Fine-tuning with limited data → PP-OCRv3 (simpler architecture, easier to tune)
- Production multilingual (CN/EN/JP) → PP-OCRv5

## Quick Start: Inference

```python
from paddleocr import PaddleOCR

ocr = PaddleOCR(
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False
)

result = ocr.predict(input="test.png")
for res in result:
    res.print()
    res.save_to_img("output")
```

CLI:
```bash
paddleocr ocr -i test.png
```

## Fine-tuning Decision Table

| Scenario | Task | Min Data | Pretrained Model | Config |
|----------|------|----------|-----------------|--------|
| Custom text regions | Detection | ≥500 images | PP-OCRv3_det_distill | PP-OCRv3_mobile_det.yml |
| Custom fonts/language | Recognition | ≥5000 images | PP-OCRv3_rec_train | PP-OCRv3_mobile_rec.yml |
| Domain-specific (receipts, IDs) | Both | Det ≥500 + Rec ≥5000 | Both pretrained | Separate configs |
| New dictionary/charset | Recognition | ≥10000 images | PP-OCRv3_rec_train | Custom dict + config |

## Fine-tuning Workflow

### Step 1: Prepare Dataset
See [references/dataset-preparation.md](references/dataset-preparation.md)
**Validate:** Label files exist, format matches PaddleOCR spec (tab-separated for rec, JSON for det).

### Step 2: Download Pretrained Model
```bash
# Detection
wget https://paddleocr.bj.bcebos.com/PP-OCRv3/chinese/ch_PP-OCRv3_det_distill_train.tar
tar xf ch_PP-OCRv3_det_distill_train.tar

# Recognition
wget https://paddleocr.bj.bcebos.com/PP-OCRv3/chinese/ch_PP-OCRv3_rec_train.tar
tar xf ch_PP-OCRv3_rec_train.tar
```

### Step 3: Configure & Train
See [references/detection-training.md](references/detection-training.md) or [references/recognition-training.md](references/recognition-training.md)
**Validate:** Loss decreasing, eval metrics improving.

### Step 4: Export & Deploy
See [references/deployment-export.md](references/deployment-export.md)
**Validate:** Inference model produces correct predictions on test images.

## Learning Rate Scaling Rule — HARD GATE

PaddleOCR configs assume 8-GPU training. MUST scale learning rate linearly:

```
lr_actual = lr_config × (your_total_batch_size / config_total_batch_size)
```

| Your Setup | Det batch_size | Det lr | Rec batch_size | Rec lr |
|-----------|---------------|--------|---------------|--------|
| 1 GPU | 8 | 1e-4 | 128 | [1e-4, 2e-5] |
| 1 GPU (low VRAM) | 4 | 5e-5 | 64 | [5e-5, 1e-5] |
| 4 GPUs | 8×4=32 | 5e-4 | 128×4=512 | [5e-4, 1e-4] |
| 8 GPUs (default) | 8×8=64 | 1e-3 | 128×8=1024 | [1e-3, 1e-4] |

## Troubleshooting

```
Training fails?
├─ OOM error?
│   ├─ Reduce batch_size_per_card
│   ├─ Enable mixed precision: Global.use_amp=True
│   └─ Reduce image size in config
│
├─ Loss not decreasing?
│   ├─ Check pretrained_model path is correct
│   ├─ Check learning rate (too high → diverge, too low → stuck)
│   └─ Verify dataset labels are correct
│
├─ Acc stays 0 after changing dict?
│   └─ Normal — last FC layer can't load. Keep training, it will converge.
│
└─ Inference results differ from training?
    ├─ Check pre/post-processing params match between train and inference
    └─ Check image_shape is same in train config and inference
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Dùng default config cho fine-tune" | PHẢI scale learning rate theo số GPU và batch size |
| "500 ảnh đủ cho recognition" | Detection cần ≥500, Recognition cần ≥5000 |
| "Chỉ cần train recognition" | Nếu domain khác biệt lớn, cần fine-tune CẢ detection lẫn recognition |
| "PP-OCRv5 luôn tốt hơn v3" | v3 dễ fine-tune hơn (simpler arch), v5 tốt hơn cho inference pretrained |
| "Không cần thêm general data" | Thêm real general data (LSVT, RCTW) giúp tránh overfitting |

## Related Skills

| Situation | Activate Skill | Why |
|-----------|---------------|-----|
| CUDA/cuDNN version conflicts | python-ml-deps | PaddlePaddle CUDA compat |
| GPU Docker container | docker-gpu-setup | Containerize PaddleOCR |
| Deploy on Triton | triton-deployment | Production serving |
| Experiment tracking | experiment-tracking | MLflow/W&B integration |
| Jupyter notebook workflow | notebook-workflows | .ipynb editing |

## References

- [Dataset Preparation](references/dataset-preparation.md) — **Load when:** preparing OCR training data, annotation format, PPOCRLabel
- [Detection Training](references/detection-training.md) — **Load when:** fine-tuning text detection model
- [Recognition Training](references/recognition-training.md) — **Load when:** fine-tuning text recognition model
- [Deployment & Export](references/deployment-export.md) — **Load when:** exporting model, inference, serving, MCP
