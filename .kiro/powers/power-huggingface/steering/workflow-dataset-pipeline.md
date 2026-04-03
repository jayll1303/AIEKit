---
inclusion: auto
name: hf-dataset-pipeline
description: Guide for discovering and evaluating datasets from HuggingFace Hub. Use when user needs training data, evaluation benchmarks, or dataset recommendations.
---

# Dataset Discovery Workflow

## Search Strategy

1. Xác định data type: text, image, audio, tabular, multimodal
2. Search với query + task filter + language filter
3. Check: size, format, license, quality

## Dataset Evaluation Checklist

| Check | Cách verify | Quan trọng vì |
|-------|------------|---------------|
| Size | dataset card → row count | Quá nhỏ = underfit, quá lớn = cần streaming |
| Format | features schema | Phải compatible với training pipeline |
| License | dataset card | Commercial use restrictions |
| Language | metadata | Multilingual vs monolingual |
| Quality | preview rows | Noisy data = poor model |
| Splits | train/test/validation | Không có test split = phải tự split |

## Common Search Patterns

```
# Tìm instruction tuning data
search-datasets: query="instruction", tags=["text-generation"]

# Tìm Vietnamese NLP data
search-datasets: query="vietnamese", language="vi"

# Tìm image classification data
search-datasets: query="imagenet", tags=["image-classification"]

# Tìm speech data
search-datasets: query="speech", tags=["automatic-speech-recognition"]
```

## Size → Loading Strategy

| Rows | Strategy | Tool |
|------|----------|------|
| <100K | load_dataset() full | hf-hub-datasets |
| 100K-10M | load_dataset() with split | hf-hub-datasets |
| >10M | Streaming: load_dataset(streaming=True) | hf-hub-datasets |
| >100GB | Download specific files only | hf-hub-datasets (snapshot_download) |

## Dataset → Training Pipeline

```
Dataset found → get-dataset-info (check schema)
    → load_dataset (→ hf-hub-datasets skill)
    → Preprocess (tokenize, format)
    → Train:
        - SFT/DPO/GRPO → unsloth-training hoặc hf-transformers-trainer
        - Classification → hf-transformers-trainer
        - Speech → k2-training-pipeline
        - Vision → ultralytics-yolo
```
