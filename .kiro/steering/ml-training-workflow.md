---
inclusion: auto
name: ml-training-workflow
description: Conventions for ML training and fine-tuning workflows. Match when user asks about training, fine-tune, LoRA, QLoRA, SFT, DPO, GRPO, VRAM estimation, dataset preparation, or experiment tracking.
---

# ML Training Workflow Conventions

When performing ML training or fine-tuning workflows, follow these conventions.

## Workflow Order

Always follow this order — do NOT skip steps:

1. **Environment**: Verify GPU + CUDA (→ python-ml-deps)
2. **Dependencies**: Install packages with correct CUDA index (→ python-ml-deps)
3. **Data**: Download/prepare dataset (→ hf-hub-datasets)
4. **VRAM Estimate**: Calculate VRAM before training — do NOT skip
5. **Config**: Set TrainingArguments appropriate for hardware
6. **Train**: Run training with experiment tracking (→ experiment-tracking)
7. **Evaluate**: Validate metrics before claiming done
8. **Export**: Quantize or push to Hub (→ model-quantization, hf-hub-datasets)

## VRAM Estimation — HARD GATE

Do NOT start training without estimating VRAM. Quick formulas:

```
Full fine-tune:  params × 18 bytes (fp32 optimizer states)
LoRA:            params × 2 bytes + adapter_params × 18 bytes
QLoRA:           params × 0.5 bytes + adapter_params × 18 bytes
```

If estimated VRAM > 90% available → reduce batch size, use gradient accumulation, or switch to QLoRA.

## Skill Chain Reference

See #[[file:docs/skill-interconnection-map.md]] for skill chaining details.

| Step | Primary Skill | Supporting Skill |
|------|--------------|-----------------|
| Setup env | python-ml-deps | docker-gpu-setup |
| Download model/data | hf-hub-datasets | — |
| Train/fine-tune | hf-transformers-trainer | experiment-tracking |
| Quantize | model-quantization | — |
| Serve | vllm-tgi-inference | triton-deployment |

## Config-Driven Training — HARD GATE

<HARD-GATE>
Do NOT hardcode hyperparameters in source code. All hyperparameters MUST be in config (TrainingArguments, YAML config, or CLI args).
</HARD-GATE>

Reason: Hardcoded values → unreproducible experiments. Different runs may use different values with no one knowing.

Checklist:
- [ ] Learning rate, batch size, epochs → in TrainingArguments or config file
- [ ] Model name, dataset path → in config or CLI args, not hardcoded
- [ ] LoRA r, alpha, target_modules → in LoraConfig object, not scattered in code
- [ ] Random seed → explicit in config, not using implicit default

## Session Handoff Convention

For long-running training projects (multi-session), maintain a state file so the agent can pick up across sessions:

```json
// training-progress.json (place at project root)
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
- Update `training-progress.json` at the end of each session
- Agent reads this file at the start of a new session to reconstruct context
- `recent_sessions` keeps the 3-5 most recent entries (rolling log)
- Use JSON (not Markdown) — agents are less likely to corrupt structured JSON than freeform text

## Anti-Patterns

| ID | Agent thinks | Reality | Detection | Fix |
|---|---|---|---|---|
| AP-01 | "Small model, no need to estimate VRAM" | Every model needs estimation. OOM wastes more time | No VRAM estimation step before training | Always run estimation using the formulas above before training |
| AP-02 | "Default TrainingArguments are fine" | Defaults are rarely optimal for specific hardware | TrainingArguments not customized for batch_size, gradient_accumulation per GPU | ALWAYS tune for hardware: batch_size, gradient_accumulation, bf16 |
| AP-03 | "Training is done once it finishes" | Without evaluation you don't know if the model is good | No eval step after training | MUST evaluate metrics + compare with baseline before claiming done |
| AP-04 | "One epoch is enough" | May be underfitting | Loss curve still decreasing at end of epoch 1 | Check loss curve — if still decreasing, add more epochs |
| AP-05 | "Change multiple variables at once to save time" | Cannot attribute results to any single change | 2 consecutive experiments differ by >1 variable | Each experiment changes only 1 variable. Log clearly |
| AP-06 | "Report best seed, ignore bad seeds" | Cherry-picking = p-hacking | Only 1 seed reported, no std | Run 3+ seeds, report mean±std |
| AP-07 | "Hardcode lr=2e-4 in code for convenience" | Unreproducible, easy to forget to change | Grep source for magic numbers (bare floats, ints) | All hyperparams go in config/TrainingArguments |
