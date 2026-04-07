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

## Config-Driven Training — HARD GATE

<HARD-GATE>
KHÔNG hardcode hyperparameters trong source code. Mọi hyperparameters PHẢI nằm trong config (TrainingArguments, YAML config, hoặc CLI args).
</HARD-GATE>

Lý do: Hardcoded values → unreproducible experiments. Runs khác nhau có thể dùng values khác nhau mà không ai biết.

Checklist:
- [ ] Learning rate, batch size, epochs → trong TrainingArguments hoặc config file
- [ ] Model name, dataset path → trong config hoặc CLI args, không hardcode
- [ ] LoRA r, alpha, target_modules → trong LoraConfig object, không scatter trong code
- [ ] Random seed → explicit trong config, không dùng implicit default

## Session Handoff Convention

Cho long-running training projects (multi-session), maintain state file để agent pick up across sessions:

```json
// training-progress.json (đặt ở project root)
{
  "project": "my-fine-tuning",
  "last_updated": "2026-04-07",
  "phase": "training",
  "current_status": "LoRA fine-tune epoch 2/3 completed, eval_loss=0.85",
  "next_action": "Complete epoch 3, run eval on test set, compare with baseline",
  "blocked_by": null,
  "recent_sessions": [
    {
      "date": "2026-04-07",
      "what_was_done": "Started LoRA fine-tune, completed 2 epochs",
      "key_outcomes": "train_loss 2.1→0.9, eval_loss 2.3→0.85",
      "next_step": "Finish training, evaluate, export"
    }
  ]
}
```

Rules:
- Update `training-progress.json` ở cuối mỗi session
- Agent đọc file này ở đầu session mới để reconstruct context
- `recent_sessions` giữ 3-5 entries gần nhất (rolling log)
- Dùng JSON (không Markdown) — agent ít corrupt structured JSON hơn freeform text

## Anti-Patterns

| ID | Agent nghĩ | Thực tế | Detection | Fix |
|---|---|---|---|---|
| AP-01 | "Model nhỏ, không cần estimate VRAM" | Mọi model đều cần estimate. OOM waste thời gian hơn | Không có VRAM estimation step trước training | Luôn chạy estimation theo công thức ở trên trước khi train |
| AP-02 | "Default TrainingArguments là đủ" | Default hiếm khi optimal cho hardware cụ thể | TrainingArguments không customize batch_size, gradient_accumulation theo GPU | LUÔN tune theo hardware: batch_size, gradient_accumulation, bf16 |
| AP-03 | "Train xong là xong" | Chưa evaluate = chưa biết model có tốt không | Không có eval step sau training | PHẢI evaluate metrics + so sánh với baseline trước khi claim done |
| AP-04 | "Chỉ cần 1 epoch" | Có thể underfitting | Loss curve vẫn giảm ở cuối epoch 1 | Check loss curve — nếu vẫn giảm, cần thêm epochs |
| AP-05 | "Thay đổi nhiều biến cùng lúc cho nhanh" | Không thể attribute kết quả cho thay đổi nào | 2 experiments liên tiếp khác >1 biến | Mỗi experiment chỉ thay đổi 1 biến. Log rõ ràng |
| AP-06 | "Report best seed, bỏ qua seed kém" | Cherry-picking = p-hacking | Chỉ report 1 seed, không có std | Chạy 3+ seeds, report mean±std |
| AP-07 | "Hardcode lr=2e-4 trong code cho tiện" | Unreproducible, dễ quên thay đổi | Grep source cho magic numbers (bare floats, ints) | Mọi hyperparams vào config/TrainingArguments |
