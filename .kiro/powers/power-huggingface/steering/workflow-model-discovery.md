---
inclusion: auto
name: hf-model-discovery
description: Guide for searching and selecting models from HuggingFace Hub. Use when user asks to find, compare, or choose pretrained models.
---

# Model Discovery Workflow

## Search Strategy

1. Xác định task type: text-generation, text-classification, token-classification, translation, summarization, image-classification, object-detection, automatic-speech-recognition, text-to-image...
2. Search với query + task filter
3. Narrow down bằng: library (transformers, gguf, diffusers), language, license

## Model Evaluation Checklist

Trước khi recommend model, PHẢI check:

| Check | Cách verify | Red flag |
|-------|------------|----------|
| License | model card → license field | NC license cho commercial use |
| Size | config.json → num_parameters | Quá lớn cho hardware |
| Quantization available | search GGUF/GPTQ variants | Không có = phải tự quantize |
| Recent activity | last modified date | >6 tháng = có thể outdated |
| Community | downloads + likes | <100 downloads = chưa validated |

## Common Search Patterns

```
# Tìm LLM tiếng Việt
search-models: query="vietnamese", tags=["text-generation"]

# Tìm embedding model
search-models: query="embedding", tags=["sentence-similarity"]

# Tìm GGUF quantized
search-models: query="GGUF", author="TheBloke"

# Tìm model theo author
search-models: author="meta-llama"
```

## Model Size → Hardware Mapping

| Parameters | FP16 VRAM | Quantized (Q4) | Min GPU |
|-----------|-----------|-----------------|---------|
| 1-3B | 2-6 GB | 1-2 GB | RTX 3060 |
| 7-8B | 14-16 GB | 4-5 GB | RTX 4090 / A10 |
| 13B | 26 GB | 7-8 GB | A100 40GB |
| 30-34B | 60-68 GB | 18-20 GB | A100 80GB |
| 70B | 140 GB | 35-40 GB | 2x A100 80GB |

## Decision: Fine-tune vs Use As-Is

```
Model phù hợp task?
├─ Yes, performance đủ → Serve trực tiếp (→ vllm-tgi-inference)
├─ Yes, nhưng cần adapt → Fine-tune (→ hf-transformers-trainer)
├─ Quá lớn → Quantize trước (→ model-quantization)
└─ Không có model phù hợp → Train from scratch (rare)
```
