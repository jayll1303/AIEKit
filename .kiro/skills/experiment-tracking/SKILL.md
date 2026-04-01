---
name: experiment-tracking
description: "Set up selfhosted experiment tracking with MLflow or W&B. Use when deploying MLflow servers, configuring W&B selfhosted, logging metrics and artifacts, comparing experiment runs, managing model registry, or troubleshooting offline sync."
---

# Experiment Tracking

Patterns for selfhosted ML experiment tracking using MLflow and Weights & Biases (W&B), covering server deployment, training integration, experiment comparison, and model registry workflows.

## Scope

This skill handles:
- Deploying selfhosted MLflow tracking servers (SQLite, PostgreSQL, S3-compatible artifact stores)
- Setting up W&B selfhosted, local server mode, and offline sync
- Logging metrics, parameters, and artifacts from training scripts
- Comparing experiment runs and querying results via MLflow/W&B APIs
- Managing model versions with MLflow model registry (staging, promotion)

Does NOT handle:
- Fine-tuning models with Trainer, LoRA, or PEFT (→ hf-transformers-trainer)
- Installing ML Python packages or resolving CUDA version conflicts (→ python-ml-deps)
- Deploying models for inference with vLLM or TGI (→ vllm-tgi-inference)

## When to Use

- Deploying a selfhosted MLflow tracking server (SQLite, PostgreSQL, S3-compatible artifact store)
- Setting up W&B selfhosted or local server mode for private experiment tracking
- Logging metrics, parameters, and artifacts from HuggingFace Trainer callbacks
- Logging experiments from PyTorch training loops or custom training scripts
- Comparing experiment results and querying runs with MLflow or W&B APIs
- Managing model versions with MLflow model registry (staging, promotion, serving)
- Troubleshooting offline logging, tracking data loss, or server connectivity issues

## Setup Decision Table

| Need | Recommended Setup | Why |
|---|---|---|
| Solo developer, local experiments | MLflow local (`mlflow server` with SQLite) | Zero infrastructure, single command, file-based storage |
| Small team (2-10), shared tracking | MLflow server (PostgreSQL + S3-compatible artifacts) | Shared backend, concurrent access, Docker Compose deployment |
| Enterprise, advanced dashboards | W&B selfhosted (local server mode) | Rich UI, team collaboration, advanced visualization, sweeps |
| Offline / air-gapped environment | MLflow local + file artifact store | No network dependency, full offline support |
| Hybrid (local + cloud sync) | W&B offline mode with periodic sync | Train offline, sync results when connected |

## MLflow Quick Start

### Local Server (Solo Developer)

```bash
# Install MLflow
pip install mlflow

# Start local tracking server (SQLite backend, local artifacts)
mlflow server \
  --backend-store-uri sqlite:///mlflow.db \
  --default-artifact-root ./mlflow-artifacts \
  --host 0.0.0.0 \
  --port 5000
```

Access UI at `http://localhost:5000`.

**Validate:** Run `curl http://localhost:5000/health` — must return OK. If not → check port is not in use (`lsof -i :5000`) and re-run the server command.

### Docker Compose Deployment (Team)

```yaml
# docker-compose.yml
services:
  mlflow:
    image: ghcr.io/mlflow/mlflow:v2.16.0
    command: >
      mlflow server
      --backend-store-uri postgresql://mlflow:mlflow@postgres:5432/mlflow
      --default-artifact-root s3://mlflow-artifacts/
      --host 0.0.0.0
      --port 5000
    ports:
      - "5000:5000"
    environment:
      - AWS_ACCESS_KEY_ID=minioadmin
      - AWS_SECRET_ACCESS_KEY=minioadmin
      - MLFLOW_S3_ENDPOINT_URL=http://minio:9000
    depends_on:
      postgres:
        condition: service_healthy
      minio:
        condition: service_started

  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: mlflow
      POSTGRES_PASSWORD: mlflow
      POSTGRES_DB: mlflow
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mlflow"]
      interval: 5s
      retries: 5

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - miniodata:/data

volumes:
  pgdata:
  miniodata:
```

```bash
# Start the stack
docker compose up -d

# Create the S3 bucket for artifacts
docker compose exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
docker compose exec minio mc mb local/mlflow-artifacts
```

**Validate:** Run `docker compose ps` — all 3 services must show "running". Then `curl http://localhost:5000/health` must return OK. If not → check `docker compose logs mlflow` for connection errors.

> For detailed server setup including nginx reverse proxy, see [mlflow-server-setup](references/mlflow-server-setup.md)

### Log an Experiment (Python)

```python
import mlflow

mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("my-fine-tuning")

with mlflow.start_run(run_name="llama-3.1-8b-lora"):
    # Log parameters
    mlflow.log_params({
        "model": "meta-llama/Llama-3.1-8B-Instruct",
        "method": "LoRA",
        "lora_r": 16,
        "lora_alpha": 32,
        "learning_rate": 2e-4,
        "epochs": 3,
    })

    # Log metrics (call repeatedly for step-wise logging)
    for step in range(100):
        mlflow.log_metrics({
            "train_loss": 2.5 - step * 0.02,
            "eval_loss": 2.6 - step * 0.018,
        }, step=step)

    # Log artifacts (files, model checkpoints)
    mlflow.log_artifact("./output/adapter_config.json")
    mlflow.log_artifacts("./output/checkpoint-final", artifact_path="model")
```

## W&B Quick Start

### Selfhosted / Local Server Mode

```bash
# Install wandb
pip install wandb

# Option 1: Use W&B cloud (default, free tier available)
wandb login

# Option 2: Selfhosted — set custom server URL
export WANDB_BASE_URL=https://wandb.your-company.com
wandb login

# Option 3: Offline mode (no server needed)
export WANDB_MODE=offline
```

**Validate:** Run `wandb status` — must show logged-in user and correct base URL. If not → re-run `wandb login` or verify `WANDB_BASE_URL` is reachable.

### Log an Experiment

```python
import wandb

# Initialize run
run = wandb.init(
    project="my-fine-tuning",
    name="llama-3.1-8b-lora",
    config={
        "model": "meta-llama/Llama-3.1-8B-Instruct",
        "method": "LoRA",
        "lora_r": 16,
        "lora_alpha": 32,
        "learning_rate": 2e-4,
        "epochs": 3,
    },
)

# Log metrics
for step in range(100):
    wandb.log({
        "train_loss": 2.5 - step * 0.02,
        "eval_loss": 2.6 - step * 0.018,
    })

# Log artifacts
artifact = wandb.Artifact("model-checkpoint", type="model")
artifact.add_dir("./output/checkpoint-final")
run.log_artifact(artifact)

run.finish()
```

### Offline Sync

```bash
# After training offline, sync to server
export WANDB_MODE=online
wandb sync ./wandb/offline-run-*
```

> For detailed W&B selfhosted setup, see [wandb-selfhosted](references/wandb-selfhosted.md)

## Trainer Integration

### MLflow with HuggingFace Trainer

```python
import os
from transformers import TrainingArguments, Trainer

os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5000"
os.environ["MLFLOW_EXPERIMENT_NAME"] = "my-fine-tuning"

training_args = TrainingArguments(
    output_dir="./output",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    learning_rate=2e-4,
    logging_steps=10,
    report_to="mlflow",          # Enable MLflow logging
    run_name="llama-lora-run1",  # MLflow run name
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
)

trainer.train()
```

### W&B with HuggingFace Trainer

```python
import os
from transformers import TrainingArguments, Trainer

os.environ["WANDB_PROJECT"] = "my-fine-tuning"
# os.environ["WANDB_MODE"] = "offline"  # Uncomment for offline

training_args = TrainingArguments(
    output_dir="./output",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    learning_rate=2e-4,
    logging_steps=10,
    report_to="wandb",           # Enable W&B logging
    run_name="llama-lora-run1",  # W&B run name
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
)

trainer.train()
```

> For PyTorch training loop integration and custom callback patterns, see [integration-recipes](references/integration-recipes.md)

## Comparison Patterns

### MLflow: Query and Compare Runs

```python
import mlflow

mlflow.set_tracking_uri("http://localhost:5000")
client = mlflow.tracking.MlflowClient()

# Search runs in an experiment
experiment = client.get_experiment_by_name("my-fine-tuning")
runs = client.search_runs(
    experiment_ids=[experiment.experiment_id],
    filter_string="metrics.eval_loss < 1.5",
    order_by=["metrics.eval_loss ASC"],
    max_results=10,
)

# Compare top runs
for run in runs:
    print(f"Run: {run.info.run_name}")
    print(f"  eval_loss: {run.data.metrics.get('eval_loss', 'N/A')}")
    print(f"  method: {run.data.params.get('method', 'N/A')}")
    print(f"  lr: {run.data.params.get('learning_rate', 'N/A')}")
```

### W&B: Query and Compare Runs

```python
import wandb

api = wandb.Api()

# Get runs from a project
runs = api.runs(
    "my-team/my-fine-tuning",
    filters={"$and": [{"summary_metrics.eval_loss": {"$lt": 1.5}}]},
    order="+summary_metrics.eval_loss",
)

# Compare runs
for run in runs:
    print(f"Run: {run.name}")
    print(f"  eval_loss: {run.summary.get('eval_loss', 'N/A')}")
    print(f"  config: {run.config}")
```

## Troubleshooting Checklist

```
Tracking data loss or connectivity issues?
├─ Server unreachable?
│   ├─ Check: curl http://localhost:5000/health (MLflow)
│   ├─ Check: docker compose logs mlflow
│   └─ Fix: Verify port mapping, firewall rules, DNS resolution
│
├─ Runs not appearing in UI?
│   ├─ MLflow: Verify MLFLOW_TRACKING_URI is set correctly
│   ├─ W&B: Verify WANDB_PROJECT and WANDB_BASE_URL
│   └─ Check: Experiment name matches between code and UI
│
├─ Offline logging (no server access)?
│   ├─ MLflow: Use file-based URI: mlflow.set_tracking_uri("file:///tmp/mlruns")
│   ├─ W&B: Set WANDB_MODE=offline, sync later with `wandb sync`
│   └─ Tip: Always set up local fallback for unreliable networks
│
├─ Retry patterns for intermittent failures?
│   ├─ MLflow: Set MLFLOW_HTTP_REQUEST_MAX_RETRIES=5
│   ├─ MLflow: Set MLFLOW_HTTP_REQUEST_TIMEOUT=30
│   ├─ W&B: Built-in retry with exponential backoff
│   └─ Tip: Use async logging to avoid blocking training
│
├─ Data backup strategies?
│   ├─ MLflow: Back up PostgreSQL DB + artifact store (S3/MinIO)
│   ├─ MLflow local: Back up mlflow.db + mlflow-artifacts/
│   ├─ W&B: Export runs with wandb API, back up local wandb/ directory
│   └─ Tip: Schedule regular pg_dump for PostgreSQL backend
│
└─ Artifact upload failures?
    ├─ MLflow + S3: Check AWS_ACCESS_KEY_ID, MLFLOW_S3_ENDPOINT_URL
    ├─ Large artifacts: Increase upload timeout, check disk space
    └─ Fix: Verify MinIO/S3 bucket exists and is writable
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Training script runs fine, I'll add tracking later" | Tracking must be set up BEFORE training starts. Retroactively recovering metrics from logs is error-prone and loses step-level granularity. Always configure `report_to` in TrainingArguments or `mlflow.start_run()` before `trainer.train()`. |
| "I'll log metrics to both MLflow and W&B simultaneously for redundancy" | Dual logging doubles API calls and can cause timeout-related training slowdowns. Pick one tracker per project. If migration is needed, export from one and import to the other after training. |
| "The MLflow server is on localhost, so I don't need to set MLFLOW_TRACKING_URI" | MLflow defaults to local file storage (`./mlruns`), not `localhost:5000`. Always explicitly set `MLFLOW_TRACKING_URI` or `mlflow.set_tracking_uri()` — even for local servers. Forgetting this is the #1 cause of "runs not appearing in UI". |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Fine-tuning with HuggingFace Trainer and need `report_to` integration | hf-transformers-trainer | Covers TrainingArguments, LoRA/QLoRA config, Trainer callbacks that feed into experiment tracking |
| Need to download pretrained models or push datasets to HuggingFace Hub | hf-hub-datasets | Handles `snapshot_download`, `load_dataset`, `push_to_hub` for models and datasets used in tracked experiments |
| Setting up Python project with uv, pyproject.toml before adding tracking deps | python-project-setup | Covers `uv init`, pyproject.toml setup, dependency management for the project that will use MLflow/W&B |

## References

- [MLflow Server Setup](references/mlflow-server-setup.md) — MLflow server deployment: backend store (SQLite, PostgreSQL), artifact store (local, S3-compatible), Docker Compose, nginx reverse proxy
  **Load when:** deploying MLflow server beyond the basic local setup, or configuring PostgreSQL backend, S3 artifact store, or nginx reverse proxy
- [W&B Selfhosted](references/wandb-selfhosted.md) — W&B selfhosted setup, local server mode, offline sync patterns
  **Load when:** setting up W&B selfhosted server, configuring local server mode, or troubleshooting offline-to-online sync
- [Integration Recipes](references/integration-recipes.md) — Integration patterns: Trainer callbacks, PyTorch training loops, custom scripts; logging metrics, parameters, artifacts
  **Load when:** integrating tracking into PyTorch training loops, writing custom Trainer callbacks, or logging non-standard artifact types
- [Model Registry](references/model-registry.md) — MLflow model registry: versioning, staging, promotion workflows, model serving
  **Load when:** managing model versions, promoting models between staging/production, or setting up model serving from the registry
