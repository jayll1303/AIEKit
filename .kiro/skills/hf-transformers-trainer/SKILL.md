---
name: hf-transformers-trainer
description: "Fine-tune and align LLMs locally with HuggingFace Trainer, TRL, PEFT. Use when configuring TrainingArguments, applying LoRA or QLoRA, running SFT/DPO/GRPO alignment, estimating VRAM requirements, debugging OOM errors, or setting up gradient checkpointing."
---

# HuggingFace Transformers & Trainer

Patterns for fine-tuning and aligning LLMs on local GPU hardware using HuggingFace Trainer API, PEFT (LoRA/QLoRA), and TRL (SFT/DPO/GRPO). Covers training configuration, parameter-efficient methods, alignment workflows, dataset preparation, and VRAM optimization.

## Scope

This skill handles:
- Configuring TrainingArguments, data collators, evaluation, and callbacks for HuggingFace Trainer
- Applying LoRA or QLoRA parameter-efficient fine-tuning with PEFT library
- Running SFT, DPO, and GRPO alignment training with TRL (SFTTrainer, DPOTrainer, GRPOTrainer)
- Estimating VRAM requirements and optimizing memory (gradient checkpointing, mixed precision, DeepSpeed)

Does NOT handle:
- Downloading or uploading models/datasets from HuggingFace Hub (→ hf-hub-datasets)
- Post-training quantization to GGUF, GPTQ, or AWQ formats (→ model-quantization)
- Installing CUDA-aware Python dependencies like transformers, peft, trl (→ python-ml-deps)
- Serving fine-tuned models via vLLM or TGI inference servers (→ vllm-tgi-inference)

## When to Use

- Fine-tuning a language model locally with HuggingFace Trainer
- Applying LoRA or QLoRA for parameter-efficient fine-tuning on limited VRAM
- Running SFT (Supervised Fine-Tuning) with TRL's SFTTrainer
- Training DPO or GRPO alignment with preference datasets
- Preparing datasets for instruction tuning, chat format (ChatML, Llama), or preference data
- Optimizing VRAM usage: gradient checkpointing, mixed precision, gradient accumulation
- Debugging OOM errors or selecting the right training method for your GPU budget
- Configuring TrainingArguments, data collators, evaluation, and callbacks

## Training Scenario Decision Table

| Scenario | Method | Library | Min VRAM (7B) | Min VRAM (13B) | Min VRAM (70B) | Key Config |
|---|---|---|---|---|---|---|
| Full fine-tune | Full params | Trainer | ~28 GB | ~52 GB | ~280 GB (multi-GPU) | `bf16=True`, gradient checkpointing |
| LoRA | Adapter only | PEFT + Trainer | ~18 GB | ~32 GB | ~160 GB (multi-GPU) | `r=16`, `alpha=32`, target modules |
| QLoRA | 4-bit base + adapter | PEFT + Trainer + bnb | ~6 GB | ~10 GB | ~40 GB | NF4 + LoRA, `r=16` |
| SFT | Supervised fine-tune | TRL SFTTrainer | ~6 GB (QLoRA) | ~10 GB (QLoRA) | ~40 GB (QLoRA) | Chat template, packing |
| DPO | Preference alignment | TRL DPOTrainer | ~12 GB (QLoRA) | ~20 GB (QLoRA) | ~80 GB (QLoRA) | Chosen/rejected pairs, `beta=0.1` |
| GRPO | Group reward optimization | TRL GRPOTrainer | ~16 GB (QLoRA) | ~28 GB (QLoRA) | ~100 GB (QLoRA) | Reward model, group sampling |

**Rules of thumb**:
- **Limited VRAM (≤8 GB)**: QLoRA with SFTTrainer — the most VRAM-efficient path
- **Mid-range (16-24 GB)**: LoRA or QLoRA with DPO alignment
- **High-end (≥48 GB)**: Full fine-tune for small models, LoRA for larger ones
- **Multi-GPU**: DeepSpeed ZeRO-3 or FSDP for 70B+ models

## Trainer Quick Start

⚠️ **HARD GATE:** Do NOT start training before estimating VRAM requirements using the Decision Table above. Compare model size + method against available GPU memory. If estimated VRAM exceeds available, switch to QLoRA or reduce batch size first.

### Basic TrainingArguments Template

```python
from transformers import TrainingArguments

training_args = TrainingArguments(
    output_dir="./output",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    per_device_eval_batch_size=8,
    gradient_accumulation_steps=4,       # Effective batch = 4 * 4 = 16
    learning_rate=2e-4,
    weight_decay=0.01,
    warmup_ratio=0.03,
    lr_scheduler_type="cosine",
    bf16=True,                           # Use bf16 on Ampere+ GPUs
    gradient_checkpointing=True,         # Trade compute for VRAM
    logging_steps=10,
    eval_strategy="steps",
    eval_steps=100,
    save_strategy="steps",
    save_steps=100,
    save_total_limit=3,
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    report_to="mlflow",                  # or "wandb", "tensorboard"
    dataloader_num_workers=4,
    remove_unused_columns=False,
)
```

### Trainer Setup with Evaluation

```python
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    Trainer,
    DataCollatorForLanguageModeling,
)
import numpy as np

model_id = "meta-llama/Llama-3.1-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_id)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype="auto",
    device_map="auto",
)

data_collator = DataCollatorForLanguageModeling(
    tokenizer=tokenizer,
    mlm=False,
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    data_collator=data_collator,
    tokenizer=tokenizer,
)

trainer.train()
trainer.save_model("./output/final")
```

**Validate:** `trainer.train()` completes without OOM and `trainer.state.log_history` shows decreasing `train_loss`. If OOM → reduce `per_device_train_batch_size` or enable `gradient_checkpointing=True`. If loss not decreasing → check learning rate and data quality.

> For detailed TrainingArguments patterns, callback recipes, and evaluation setup, see [Trainer Config Recipes](references/trainer-config-recipes.md)

## PEFT Config Templates

### LoRA Configuration

```python
from peft import LoraConfig, get_peft_model, TaskType

lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,                        # Rank — higher = more capacity, more VRAM
    lora_alpha=32,               # Scaling factor (alpha/r = scaling)
    lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    bias="none",
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Typical output: trainable params: 13.6M || all params: 8.03B || 0.17%
```

### QLoRA Configuration (4-bit base + LoRA)

```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
import torch

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.1-8B-Instruct",
    quantization_config=bnb_config,
    device_map="auto",
)

model = prepare_model_for_kbit_training(model)

lora_config = LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    bias="none", task_type="CAUSAL_LM",
)

model = get_peft_model(model, lora_config)
```

### Recommended Hyperparameters by Model Size

| Model Size | r | lora_alpha | Target Modules | Notes |
|---|---|---|---|---|
| 7B-8B | 16 | 32 | All linear layers | Good default, ~13M trainable params |
| 13B | 16-32 | 32-64 | All linear layers | Increase r for complex tasks |
| 70B | 8-16 | 16-32 | Attention layers only | Keep r lower to manage VRAM |

> For detailed PEFT configs per model size, adapter merging, and advanced patterns, see [PEFT LoRA/QLoRA reference](references/peft-lora-qlora.md)

## TRL Workflow Overview

### SFT (Supervised Fine-Tuning)

```python
from trl import SFTTrainer, SFTConfig

sft_config = SFTConfig(
    output_dir="./output-sft",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    bf16=True,
    gradient_checkpointing=True,
    max_seq_length=2048,
    packing=True,
    dataset_text_field="text",
)

trainer = SFTTrainer(
    model=model,
    args=sft_config,
    train_dataset=train_dataset,
    peft_config=lora_config,
    tokenizer=tokenizer,
)

trainer.train()
```

**Validate:** Training logs show `train_loss` decreasing over steps. If `train_loss` stays flat → verify `dataset_text_field` matches actual column name. If OOM → reduce `max_seq_length` or `per_device_train_batch_size`.

### DPO (Direct Preference Optimization)

```python
from trl import DPOTrainer, DPOConfig

dpo_config = DPOConfig(
    output_dir="./output-dpo",
    num_train_epochs=1,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    learning_rate=5e-5,
    beta=0.1,
    bf16=True,
    gradient_checkpointing=True,
    max_length=1024,
    max_prompt_length=512,
)

# Dataset must have columns: prompt, chosen, rejected
trainer = DPOTrainer(
    model=model,
    args=dpo_config,
    train_dataset=dpo_dataset,
    tokenizer=tokenizer,
    peft_config=lora_config,
)

trainer.train()
```

**Validate:** `rewards/chosen` > `rewards/rejected` in training logs after a few steps. If not → check dataset format has correct `prompt`, `chosen`, `rejected` columns. If `rewards/accuracies` stays ~0.5 → increase `beta` or check data quality.

### GRPO (Group Relative Policy Optimization)

```python
from trl import GRPOTrainer, GRPOConfig

grpo_config = GRPOConfig(
    output_dir="./output-grpo",
    num_train_epochs=1,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
    learning_rate=1e-5,
    bf16=True,
    gradient_checkpointing=True,
    num_generations=4,
    max_completion_length=512,
)

def reward_fn(completions, **kwargs):
    """Score each completion. Return list of floats."""
    return [len(c.split()) * 0.1 for c in completions]

trainer = GRPOTrainer(
    model=model,
    args=grpo_config,
    train_dataset=prompt_dataset,
    reward_funcs=reward_fn,
    peft_config=lora_config,
)

trainer.train()
```

**Validate:** `reward/mean` increases over training steps. If reward stays flat → verify reward function returns meaningful scores. If OOM → reduce `num_generations` or `max_completion_length`.

> For detailed TRL workflows, dataset format requirements, and advanced configs, see [TRL SFT/DPO/GRPO reference](references/trl-sft-dpo-grpo.md)

## VRAM Optimization Checklist

When encountering OOM errors or needing to fit training on limited VRAM:

```
Out of memory during training?
├─ Enable gradient checkpointing
│   └─ gradient_checkpointing=True in TrainingArguments
│      Saves ~30-40% VRAM, ~20% slower training
├─ Use mixed precision
│   ├─ bf16=True (Ampere+ GPUs: A100, RTX 3090/4090)
│   ├─ fp16=True (older GPUs: V100, RTX 2080)
│   └─ Saves ~50% VRAM vs FP32
├─ Reduce batch size + increase gradient accumulation
│   ├─ per_device_train_batch_size=1 or 2
│   ├─ gradient_accumulation_steps=8 or 16
│   └─ Effective batch size = batch_size × accumulation × num_gpus
├─ Switch to QLoRA
│   ├─ Load base model in 4-bit with BitsAndBytesConfig
│   ├─ Train only LoRA adapters (~0.1-0.5% of params)
│   └─ 7B model fits in ~6 GB VRAM
├─ Reduce sequence length
│   ├─ max_seq_length=1024 instead of 2048
│   └─ VRAM scales roughly linearly with sequence length
├─ Use packing (SFTTrainer)
│   ├─ packing=True packs short examples into full sequences
│   └─ Reduces wasted padding, improves throughput
├─ Multi-GPU: DeepSpeed ZeRO
│   ├─ ZeRO-2: Shard optimizer states + gradients
│   ├─ ZeRO-3: Shard everything (params + optimizer + gradients)
│   └─ See vram-optimization reference for configs
└─ Monitor VRAM usage
    ├─ nvidia-smi -l 1 (watch every second)
    ├─ torch.cuda.max_memory_allocated() after forward pass
    └─ torch.cuda.memory_summary() for detailed breakdown
```

### Quick VRAM Estimation

| Model Size | FP16 | QLoRA (4-bit + adapters) | Full Fine-tune (FP16 + optimizer) |
|---|---|---|---|
| 7B | ~14 GB | ~6 GB | ~28 GB |
| 13B | ~26 GB | ~10 GB | ~52 GB |
| 34B | ~68 GB | ~24 GB | ~136 GB |
| 70B | ~140 GB | ~40 GB | ~280 GB |

*Full fine-tune includes model weights + optimizer states (2x) + gradients.*

> For detailed VRAM estimation formulas, DeepSpeed ZeRO configs, and FSDP setup, see [VRAM Optimization reference](references/vram-optimization.md)

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "GPU 24 GB chắc đủ cho full fine-tune 7B" | Full fine-tune 7B cần ~28 GB (weights + optimizer + gradients). Luôn check VRAM Estimation table trước khi chọn method |
| "LoRA rank cao hơn = kết quả tốt hơn" | r quá cao (>64) tăng VRAM mà không cải thiện quality; r=16 là default tốt cho hầu hết tasks. Benchmark trước khi tăng |
| "Không cần gradient checkpointing, VRAM còn dư" | Gradient checkpointing giảm ~30-40% VRAM với chỉ ~20% slower. Luôn bật cho model ≥7B để có headroom cho batch size lớn hơn |
| "Dataset nhỏ thì train nhiều epoch cho tốt" | Overfitting xảy ra nhanh với dataset nhỏ; monitor eval_loss và dùng early stopping. 1-3 epochs thường đủ cho fine-tuning |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to download model or dataset from HuggingFace Hub before training | hf-hub-datasets | Handles snapshot_download, load_dataset, private repo access |
| Need to log training metrics to MLflow or W&B | experiment-tracking | Handles MLflow/W&B setup, metric logging, model registry |
| Need to quantize fine-tuned model to GGUF/GPTQ/AWQ after training | model-quantization | Handles post-training quantization methods and VRAM budget |
| Need to install transformers, peft, trl, bitsandbytes with CUDA | python-ml-deps | Handles uv pip install with CUDA version resolution |
| Want 2x faster training with 70% less VRAM on single GPU | unsloth-training | Covers Unsloth FastLanguageModel, optimized Triton kernels, built-in GGUF export |

## References

- [Trainer Config Recipes](references/trainer-config-recipes.md) — TrainingArguments patterns, data collation, evaluation setup, callback patterns
  **Load when:** customizing TrainingArguments beyond defaults, adding custom callbacks, or setting up evaluation metrics
- [PEFT LoRA/QLoRA](references/peft-lora-qlora.md) — LoRA/QLoRA config templates per model size (7B, 13B, 70B), recommended hyperparameters, adapter merging
  **Load when:** tuning LoRA hyperparameters for specific model sizes, merging adapters back into base model, or debugging PEFT errors
- [TRL SFT/DPO/GRPO](references/trl-sft-dpo-grpo.md) — TRL workflow templates for SFT, DPO, GRPO; dataset format requirements for each method
  **Load when:** setting up DPO/GRPO training, preparing preference datasets, or configuring advanced TRL options
- [Dataset Preparation](references/dataset-preparation.md) — Dataset preparation patterns for instruction tuning, chat format (ChatML, Llama), preference data
  **Load when:** formatting datasets for chat templates (ChatML, Llama), creating preference pairs, or converting between dataset formats
- [VRAM Optimization](references/vram-optimization.md) — VRAM estimation formulas, DeepSpeed ZeRO stages, FSDP config, memory profiling
  **Load when:** encountering OOM errors, configuring DeepSpeed ZeRO or FSDP, or profiling GPU memory usage during training
