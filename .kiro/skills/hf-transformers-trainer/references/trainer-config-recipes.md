# Trainer Config Recipes

Detailed TrainingArguments patterns, data collation strategies, evaluation setup, and callback recipes for HuggingFace Trainer.

## TrainingArguments Deep Dive

### Learning Rate Scheduling

```python
from transformers import TrainingArguments

# Cosine schedule with warmup (most common for fine-tuning)
args = TrainingArguments(
    output_dir="./output",
    learning_rate=2e-4,
    lr_scheduler_type="cosine",
    warmup_ratio=0.03,           # 3% of total steps for warmup
    num_train_epochs=3,
)

# Linear schedule with warmup steps
args = TrainingArguments(
    output_dir="./output",
    learning_rate=2e-4,
    lr_scheduler_type="linear",
    warmup_steps=100,            # Fixed warmup steps
    num_train_epochs=3,
)

# Constant with warmup (useful for short fine-tuning)
args = TrainingArguments(
    output_dir="./output",
    learning_rate=2e-4,
    lr_scheduler_type="constant_with_warmup",
    warmup_steps=50,
    num_train_epochs=1,
)
```

### Recommended Learning Rates by Method

| Method | Learning Rate | Scheduler | Warmup | Notes |
|---|---|---|---|---|
| Full fine-tune | 1e-5 to 5e-5 | Cosine | 3-5% | Lower LR to avoid catastrophic forgetting |
| LoRA | 1e-4 to 3e-4 | Cosine | 3% | Higher LR since only adapters update |
| QLoRA | 1e-4 to 2e-4 | Cosine | 3% | Similar to LoRA |
| DPO | 1e-6 to 5e-5 | Linear | 10% | Very low LR for alignment stability |
| GRPO | 1e-6 to 1e-5 | Cosine | 5% | Conservative LR for policy optimization |

### Checkpointing and Saving

```python
args = TrainingArguments(
    output_dir="./output",
    save_strategy="steps",
    save_steps=500,
    save_total_limit=3,              # Keep only last 3 checkpoints
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    greater_is_better=False,
    # Resume from checkpoint
    resume_from_checkpoint=True,     # Auto-detect last checkpoint
)
```

### Logging Configuration

```python
import os

# MLflow logging
os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5000"
os.environ["MLFLOW_EXPERIMENT_NAME"] = "my-fine-tuning"

args = TrainingArguments(
    output_dir="./output",
    report_to="mlflow",              # or "wandb", "tensorboard", ["mlflow", "tensorboard"]
    run_name="llama-lora-exp1",
    logging_steps=10,
    logging_first_step=True,
    logging_nan_inf_filter=True,     # Filter NaN/Inf from logs
)
```

## Data Collation Patterns

### DataCollatorForLanguageModeling (Causal LM)

```python
from transformers import DataCollatorForLanguageModeling

# Standard causal LM collator — masks padding, shifts labels
collator = DataCollatorForLanguageModeling(
    tokenizer=tokenizer,
    mlm=False,           # False for causal LM (GPT-style)
    pad_to_multiple_of=8, # Pad to multiple of 8 for tensor core efficiency
)
```

### DataCollatorForSeq2Seq (Instruction Tuning)

```python
from transformers import DataCollatorForSeq2Seq

# For instruction tuning where you want to mask the prompt in labels
collator = DataCollatorForSeq2Seq(
    tokenizer=tokenizer,
    model=model,
    padding=True,
    pad_to_multiple_of=8,
    label_pad_token_id=-100,  # Ignore padding in loss
)
```

### Custom Collator for Chat Format

```python
from dataclasses import dataclass
from typing import Dict, List, Sequence
import torch

@dataclass
class ChatDataCollator:
    """Collator that masks prompt tokens in labels (only compute loss on response)."""
    tokenizer: object
    max_length: int = 2048

    def __call__(self, features: List[Dict]) -> Dict[str, torch.Tensor]:
        input_ids = [f["input_ids"][:self.max_length] for f in features]
        labels = [f["labels"][:self.max_length] for f in features]

        # Pad sequences
        max_len = max(len(ids) for ids in input_ids)
        padded_input_ids = []
        padded_labels = []

        for ids, lbl in zip(input_ids, labels):
            pad_len = max_len - len(ids)
            padded_input_ids.append(ids + [self.tokenizer.pad_token_id] * pad_len)
            padded_labels.append(lbl + [-100] * pad_len)

        return {
            "input_ids": torch.tensor(padded_input_ids),
            "labels": torch.tensor(padded_labels),
            "attention_mask": torch.tensor([
                [1] * len(ids) + [0] * (max_len - len(ids))
                for ids in input_ids
            ]),
        }
```

## Evaluation Setup

### Built-in Eval with Trainer

```python
from transformers import TrainingArguments, Trainer

args = TrainingArguments(
    output_dir="./output",
    eval_strategy="steps",
    eval_steps=100,
    per_device_eval_batch_size=8,
    eval_accumulation_steps=4,       # Accumulate eval predictions to save memory
    metric_for_best_model="eval_loss",
    load_best_model_at_end=True,
)

trainer = Trainer(
    model=model,
    args=args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    data_collator=collator,
    tokenizer=tokenizer,
)
```

### Custom Metrics Function

```python
import numpy as np
from transformers import EvalPrediction

def compute_metrics(eval_pred: EvalPrediction) -> dict:
    """Compute perplexity and accuracy from eval predictions."""
    logits, labels = eval_pred

    # Shift for causal LM
    shift_logits = logits[..., :-1, :]
    shift_labels = labels[..., 1:]

    # Flatten
    flat_logits = shift_logits.reshape(-1, shift_logits.shape[-1])
    flat_labels = shift_labels.reshape(-1)

    # Filter out padding (-100)
    mask = flat_labels != -100
    valid_logits = flat_logits[mask]
    valid_labels = flat_labels[mask]

    # Accuracy
    predictions = np.argmax(valid_logits, axis=-1)
    accuracy = (predictions == valid_labels).mean()

    return {"accuracy": float(accuracy)}
```

## Callback Patterns

### Early Stopping

```python
from transformers import EarlyStoppingCallback

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    callbacks=[
        EarlyStoppingCallback(
            early_stopping_patience=3,     # Stop after 3 evals without improvement
            early_stopping_threshold=0.01, # Minimum improvement threshold
        ),
    ],
)
```

### Custom Logging Callback

```python
from transformers import TrainerCallback

class VRAMLoggingCallback(TrainerCallback):
    """Log GPU VRAM usage at each logging step."""

    def on_log(self, args, state, control, logs=None, **kwargs):
        import torch
        if torch.cuda.is_available():
            allocated = torch.cuda.max_memory_allocated() / 1e9
            reserved = torch.cuda.max_memory_reserved() / 1e9
            if logs is not None:
                logs["vram_allocated_gb"] = round(allocated, 2)
                logs["vram_reserved_gb"] = round(reserved, 2)

trainer = Trainer(
    model=model,
    args=training_args,
    callbacks=[VRAMLoggingCallback()],
    # ...
)
```

### Save PEFT Adapter Callback

```python
from transformers import TrainerCallback

class SavePeftCallback(TrainerCallback):
    """Save only the PEFT adapter (not full model) at each save step."""

    def on_save(self, args, state, control, **kwargs):
        checkpoint_dir = f"{args.output_dir}/checkpoint-{state.global_step}"
        kwargs["model"].save_pretrained(checkpoint_dir)

    def on_train_end(self, args, state, control, **kwargs):
        kwargs["model"].save_pretrained(f"{args.output_dir}/final-adapter")
```

### Gradient Norm Monitoring

```python
from transformers import TrainerCallback
import torch

class GradNormCallback(TrainerCallback):
    """Monitor gradient norms to detect training instability."""

    def on_step_end(self, args, state, control, model=None, **kwargs):
        if state.global_step % args.logging_steps == 0 and model is not None:
            total_norm = 0.0
            for p in model.parameters():
                if p.grad is not None:
                    total_norm += p.grad.data.norm(2).item() ** 2
            total_norm = total_norm ** 0.5
            if state.log_history:
                state.log_history[-1]["grad_norm"] = round(total_norm, 4)
```

## Multi-GPU Training Arguments

### DataParallel (Simple Multi-GPU)

```bash
# Automatic with Trainer — just launch normally
python train.py
# Trainer auto-detects multiple GPUs and uses DataParallel
```

### DeepSpeed Integration

```python
args = TrainingArguments(
    output_dir="./output",
    deepspeed="ds_config.json",  # Path to DeepSpeed config
    bf16=True,
    per_device_train_batch_size=2,
    gradient_accumulation_steps=8,
)
```

```bash
# Launch with DeepSpeed
deepspeed --num_gpus=4 train.py \
  --deepspeed ds_config.json
```

### FSDP Integration

```python
args = TrainingArguments(
    output_dir="./output",
    fsdp="full_shard auto_wrap",
    fsdp_config={
        "fsdp_transformer_layer_cls_to_wrap": "LlamaDecoderLayer",
    },
    bf16=True,
)
```

```bash
# Launch with torchrun
torchrun --nproc_per_node=4 train.py
```

> For DeepSpeed ZeRO configs and FSDP details, see [vram-optimization.md](vram-optimization.md)
