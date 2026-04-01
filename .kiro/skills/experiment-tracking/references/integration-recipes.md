# Integration Recipes

Patterns for integrating MLflow and W&B into HuggingFace Trainer, PyTorch training loops, and custom training scripts. Covers logging metrics, parameters, artifacts, and model checkpoints.

## HuggingFace Trainer Integration

### MLflow + Trainer (Full Example)

```python
import os
import mlflow
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    Trainer,
)

# Configure MLflow
os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5000"
os.environ["MLFLOW_EXPERIMENT_NAME"] = "llama-fine-tuning"
os.environ["HF_MLFLOW_LOG_ARTIFACTS"] = "1"  # Log model artifacts to MLflow

model_name = "meta-llama/Llama-3.1-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(model_name)

training_args = TrainingArguments(
    output_dir="./output",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    warmup_ratio=0.1,
    logging_steps=10,
    eval_strategy="steps",
    eval_steps=50,
    save_strategy="steps",
    save_steps=100,
    report_to="mlflow",
    run_name="llama-8b-sft-v1",
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    tokenizer=tokenizer,
)

trainer.train()
# MLflow automatically logs: hyperparameters, metrics, model artifacts
```

### W&B + Trainer (Full Example)

```python
import os
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    Trainer,
)

# Configure W&B
os.environ["WANDB_PROJECT"] = "llama-fine-tuning"
os.environ["WANDB_LOG_MODEL"] = "checkpoint"  # Log model checkpoints as artifacts

model_name = "meta-llama/Llama-3.1-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(model_name)

training_args = TrainingArguments(
    output_dir="./output",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    warmup_ratio=0.1,
    logging_steps=10,
    eval_strategy="steps",
    eval_steps=50,
    save_strategy="steps",
    save_steps=100,
    report_to="wandb",
    run_name="llama-8b-sft-v1",
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    tokenizer=tokenizer,
)

trainer.train()
# W&B automatically logs: hyperparameters, metrics, system metrics (GPU, CPU, memory)
```

### Custom Trainer Callback (MLflow)

```python
from transformers import TrainerCallback
import mlflow

class MLflowCustomCallback(TrainerCallback):
    """Log custom metrics and artifacts during training."""

    def on_evaluate(self, args, state, control, metrics=None, **kwargs):
        if metrics:
            # Log custom computed metrics
            mlflow.log_metrics({
                "custom_perplexity": 2 ** metrics.get("eval_loss", 0),
            }, step=state.global_step)

    def on_save(self, args, state, control, **kwargs):
        # Log checkpoint as artifact
        checkpoint_dir = f"{args.output_dir}/checkpoint-{state.global_step}"
        mlflow.log_artifacts(checkpoint_dir, artifact_path=f"checkpoint-{state.global_step}")

    def on_train_end(self, args, state, control, **kwargs):
        # Log final model
        mlflow.log_artifacts(args.output_dir, artifact_path="final-model")

# Usage
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    callbacks=[MLflowCustomCallback()],
)
```

### Custom Trainer Callback (W&B)

```python
from transformers import TrainerCallback
import wandb

class WandbCustomCallback(TrainerCallback):
    """Log custom metrics and artifacts during training."""

    def on_evaluate(self, args, state, control, metrics=None, **kwargs):
        if metrics:
            wandb.log({
                "custom_perplexity": 2 ** metrics.get("eval_loss", 0),
            }, step=state.global_step)

    def on_save(self, args, state, control, **kwargs):
        checkpoint_dir = f"{args.output_dir}/checkpoint-{state.global_step}"
        artifact = wandb.Artifact(
            f"checkpoint-{state.global_step}",
            type="model",
        )
        artifact.add_dir(checkpoint_dir)
        wandb.log_artifact(artifact)

# Usage
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    callbacks=[WandbCustomCallback()],
)
```

## PyTorch Training Loop Integration

### MLflow + PyTorch

```python
import mlflow
import torch
from torch.utils.data import DataLoader

mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("pytorch-training")

model = MyModel()
optimizer = torch.optim.AdamW(model.parameters(), lr=1e-4)
train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)

with mlflow.start_run(run_name="pytorch-v1"):
    # Log hyperparameters
    mlflow.log_params({
        "model_type": "MyModel",
        "optimizer": "AdamW",
        "learning_rate": 1e-4,
        "batch_size": 32,
        "epochs": 10,
    })

    for epoch in range(10):
        model.train()
        epoch_loss = 0.0

        for batch_idx, (inputs, targets) in enumerate(train_loader):
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = torch.nn.functional.cross_entropy(outputs, targets)
            loss.backward()
            optimizer.step()

            epoch_loss += loss.item()
            global_step = epoch * len(train_loader) + batch_idx

            # Log step-level metrics
            if batch_idx % 10 == 0:
                mlflow.log_metrics({"train_loss": loss.item()}, step=global_step)

        # Log epoch-level metrics
        avg_loss = epoch_loss / len(train_loader)
        mlflow.log_metrics({"epoch_avg_loss": avg_loss, "epoch": epoch}, step=global_step)

        # Save and log checkpoint
        checkpoint_path = f"./checkpoints/epoch_{epoch}.pt"
        torch.save(model.state_dict(), checkpoint_path)
        mlflow.log_artifact(checkpoint_path, artifact_path="checkpoints")

    # Log final model
    mlflow.log_artifact("./checkpoints/epoch_9.pt", artifact_path="final-model")
```

### W&B + PyTorch

```python
import wandb
import torch
from torch.utils.data import DataLoader

run = wandb.init(
    project="pytorch-training",
    name="pytorch-v1",
    config={
        "model_type": "MyModel",
        "optimizer": "AdamW",
        "learning_rate": 1e-4,
        "batch_size": 32,
        "epochs": 10,
    },
)

model = MyModel()
optimizer = torch.optim.AdamW(model.parameters(), lr=wandb.config.learning_rate)
train_loader = DataLoader(train_dataset, batch_size=wandb.config.batch_size, shuffle=True)

# Optional: watch model gradients and parameters
wandb.watch(model, log="all", log_freq=100)

for epoch in range(wandb.config.epochs):
    model.train()
    epoch_loss = 0.0

    for batch_idx, (inputs, targets) in enumerate(train_loader):
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = torch.nn.functional.cross_entropy(outputs, targets)
        loss.backward()
        optimizer.step()

        epoch_loss += loss.item()

        # Log step-level metrics
        if batch_idx % 10 == 0:
            wandb.log({"train_loss": loss.item()})

    # Log epoch-level metrics
    avg_loss = epoch_loss / len(train_loader)
    wandb.log({"epoch_avg_loss": avg_loss, "epoch": epoch})

    # Save and log checkpoint as artifact
    checkpoint_path = f"./checkpoints/epoch_{epoch}.pt"
    torch.save(model.state_dict(), checkpoint_path)
    artifact = wandb.Artifact(f"model-epoch-{epoch}", type="model")
    artifact.add_file(checkpoint_path)
    run.log_artifact(artifact)

run.finish()
```

## Custom Script Integration

### MLflow — Minimal Logging

```python
import mlflow

mlflow.set_tracking_uri("http://localhost:5000")

with mlflow.start_run():
    # Log anything: params, metrics, artifacts
    mlflow.log_param("script", "preprocess_v2.py")
    mlflow.log_param("dataset_size", 50000)

    # Log metrics
    mlflow.log_metric("accuracy", 0.92)
    mlflow.log_metric("f1_score", 0.89)

    # Log files
    mlflow.log_artifact("./results/confusion_matrix.png")
    mlflow.log_artifact("./results/classification_report.txt")

    # Log a directory
    mlflow.log_artifacts("./results/", artifact_path="evaluation")

    # Log tags for organization
    mlflow.set_tag("stage", "evaluation")
    mlflow.set_tag("dataset", "v2")
```

### W&B — Minimal Logging

```python
import wandb

run = wandb.init(project="my-project")

# Log config
wandb.config.update({"script": "preprocess_v2.py", "dataset_size": 50000})

# Log metrics
wandb.log({"accuracy": 0.92, "f1_score": 0.89})

# Log images, plots, tables
wandb.log({"confusion_matrix": wandb.Image("./results/confusion_matrix.png")})

# Log artifacts
artifact = wandb.Artifact("evaluation-results", type="results")
artifact.add_dir("./results/")
run.log_artifact(artifact)

# Log tables
table = wandb.Table(columns=["model", "accuracy", "f1"])
table.add_data("v1", 0.88, 0.85)
table.add_data("v2", 0.92, 0.89)
wandb.log({"comparison": table})

run.finish()
```

## Logging Best Practices

| Practice | MLflow | W&B |
|---|---|---|
| Log hyperparameters | `mlflow.log_params({...})` | `wandb.config.update({...})` |
| Log step metrics | `mlflow.log_metrics({...}, step=N)` | `wandb.log({...})` (auto-increments step) |
| Log epoch metrics | `mlflow.log_metrics({...}, step=N)` | `wandb.log({...})` |
| Log artifacts/files | `mlflow.log_artifact(path)` | `wandb.Artifact` + `run.log_artifact` |
| Log images | `mlflow.log_artifact("plot.png")` | `wandb.log({"img": wandb.Image(...)})` |
| Tag/organize runs | `mlflow.set_tag("key", "val")` | `wandb.run.tags = ["tag1"]` |
| Nested runs | `mlflow.start_run(nested=True)` | `wandb.init(group="experiment")` |
| Resume a run | `mlflow.start_run(run_id="...")` | `wandb.init(resume="must", id="...")` |
