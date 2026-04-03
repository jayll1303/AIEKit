---
inclusion: auto
name: ml-training-workflow
description: Conventions cho ML training và fine-tuning workflows. Match khi user hỏi về training, fine-tune, LoRA, QLoRA, SFT, DPO, GRPO, VRAM estimation, dataset preparation, hoặc experiment tracking.
---

# ML Training Workflow Conventions

Khi thực hiện ML training hoặc fine-tuning workflow, tuân thủ các conventions sau.

## Workflow Order

Luôn follow thứ tự này — KHÔNG skip steps:

1. **Environment**: Verify GPU + CUDA (→ python-ml-deps)
2. **Dependencies**: Install packages với đúng CUDA index (→ python-ml-deps)
3. **Data**: Download/prepare dataset (→ hf-hub-datasets)
4. **VRAM Estimate**: Tính VRAM trước khi train — KHÔNG skip
5. **Config**: Set TrainingArguments phù hợp hardware
6. **Train**: Run training với experiment tracking (→ experiment-tracking)
7. **Evaluate**: Validate metrics trước khi claim done
8. **Export**: Quantize hoặc push to Hub (→ model-quantization, hf-hub-datasets)

## VRAM Estimation — HARD GATE

KHÔNG bắt đầu training mà chưa estimate VRAM. Công thức nhanh:

```
Full fine-tune:  params × 18 bytes (fp32 optimizer states)
LoRA:            params × 2 bytes + adapter_params × 18 bytes
QLoRA:           params × 0.5 bytes + adapter_params × 18 bytes
```

Nếu estimated VRAM > 90% available → giảm batch size, dùng gradient accumulation, hoặc chuyển sang QLoRA.

## Skill Chain Reference

Tham khảo #[[file:docs/skill-interconnection-map.md]] để biết skill nào chain sang skill nào.

| Bước | Skill chính | Skill hỗ trợ |
|------|------------|-------------|
| Setup env | python-ml-deps | docker-gpu-setup |
| Download model/data | hf-hub-datasets | — |
| Train/fine-tune | hf-transformers-trainer | experiment-tracking |
| Quantize | model-quantization | — |
| Serve | vllm-tgi-inference | triton-deployment |

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Model nhỏ, không cần estimate VRAM" | Mọi model đều cần estimate. OOM waste thời gian hơn |
| "Default TrainingArguments là đủ" | LUÔN tune theo hardware: batch_size, gradient_accumulation, bf16 |
| "Train xong là xong" | PHẢI evaluate metrics + so sánh với baseline |
| "Chỉ cần 1 epoch" | Check loss curve — nếu vẫn giảm, cần thêm epochs |
