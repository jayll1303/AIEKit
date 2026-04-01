# W&B Selfhosted Setup

Detailed guide for running Weights & Biases in selfhosted mode, local server configuration, offline training workflows, and sync patterns.

## Deployment Options

| Option | Description | When to Use |
|---|---|---|
| W&B Cloud (SaaS) | Hosted at `wandb.ai`, free tier available | Quick start, small teams, no infra overhead |
| W&B Server (selfhosted) | Docker-based deployment on your infrastructure | Data privacy, air-gapped environments, enterprise |
| W&B Offline Mode | No server, logs stored locally | No network, sync later |

## W&B Server (Selfhosted)

### Docker Deployment

```bash
# Pull the W&B local server image
docker pull wandb/local:latest

# Run W&B server
docker run -d \
  --name wandb-local \
  -p 8080:8080 \
  -v wandb-data:/vol \
  -e LOCAL_RESTORE=true \
  wandb/local:latest
```

Access the UI at `http://localhost:8080`. First-time setup will prompt for license key and admin account creation.

### Docker Compose

```yaml
# docker-compose.yml
services:
  wandb:
    image: wandb/local:latest
    ports:
      - "8080:8080"
    volumes:
      - wandb-data:/vol
    environment:
      - LOCAL_RESTORE=true
      - GORILLA_ALLOW_SIGNUP=true
    restart: unless-stopped

volumes:
  wandb-data:
```

```bash
docker compose up -d
```

### Client Configuration

```bash
# Point wandb CLI to selfhosted server
export WANDB_BASE_URL=http://localhost:8080

# Login (creates API key on selfhosted server)
wandb login

# Verify connection
wandb verify
```

```python
import wandb
import os

os.environ["WANDB_BASE_URL"] = "http://localhost:8080"

# Initialize a run
run = wandb.init(project="my-project", name="test-run")
wandb.log({"test_metric": 1.0})
run.finish()
```

### Production Setup with External Database

For production deployments, use an external MySQL/PostgreSQL database:

```yaml
services:
  wandb:
    image: wandb/local:latest
    ports:
      - "8080:8080"
    volumes:
      - wandb-data:/vol
    environment:
      - MYSQL_HOST=mysql
      - MYSQL_PORT=3306
      - MYSQL_DATABASE=wandb
      - MYSQL_USER=wandb
      - MYSQL_PASSWORD=wandb
      - BUCKET=s3://wandb-artifacts
      - AWS_ACCESS_KEY_ID=minioadmin
      - AWS_SECRET_ACCESS_KEY=minioadmin
      - AWS_S3_ENDPOINT_URL=http://minio:9000
    depends_on:
      - mysql
      - minio
    restart: unless-stopped

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: wandb
      MYSQL_USER: wandb
      MYSQL_PASSWORD: wandb
    volumes:
      - mysqldata:/var/lib/mysql
    restart: unless-stopped

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
    restart: unless-stopped

volumes:
  wandb-data:
  mysqldata:
  miniodata:
```

## Offline Mode

Train without any server connection. Logs are stored locally and can be synced later.

### Enable Offline Mode

```bash
# Environment variable (recommended)
export WANDB_MODE=offline

# Or set in code
import wandb
wandb.init(project="my-project", mode="offline")
```

### Offline Training Workflow

```python
import wandb
import os

os.environ["WANDB_MODE"] = "offline"

run = wandb.init(
    project="my-fine-tuning",
    name="llama-lora-offline",
    config={
        "model": "meta-llama/Llama-3.1-8B-Instruct",
        "method": "LoRA",
        "learning_rate": 2e-4,
    },
)

# Training loop
for epoch in range(3):
    for step in range(100):
        wandb.log({
            "train_loss": 2.5 - (epoch * 100 + step) * 0.005,
            "learning_rate": 2e-4 * (1 - step / 100),
        })

# Log model artifact
artifact = wandb.Artifact("model-checkpoint", type="model")
artifact.add_dir("./output/checkpoint-final")
run.log_artifact(artifact)

run.finish()
# Logs saved to ./wandb/offline-run-YYYYMMDD_HHMMSS-XXXXXXXX/
```

### Sync Offline Runs

```bash
# Sync all offline runs
wandb sync ./wandb/offline-run-*

# Sync a specific run
wandb sync ./wandb/offline-run-20240101_120000-abc12345

# Sync to a specific project
wandb sync --project my-project ./wandb/offline-run-*

# Sync to selfhosted server
export WANDB_BASE_URL=http://wandb.your-company.com
wandb sync ./wandb/offline-run-*

# Dry run (see what would be synced)
wandb sync --dry-run ./wandb/offline-run-*
```

### Offline Mode with HuggingFace Trainer

```python
import os
os.environ["WANDB_MODE"] = "offline"
os.environ["WANDB_PROJECT"] = "my-fine-tuning"

from transformers import TrainingArguments

training_args = TrainingArguments(
    output_dir="./output",
    report_to="wandb",
    run_name="offline-lora-run",
    # ... other args
)
# Trainer will log to local wandb directory
```

## Environment Variables Reference

| Variable | Description | Example |
|---|---|---|
| `WANDB_API_KEY` | API key for authentication | `wandb_xxxxxxxxxxxxx` |
| `WANDB_BASE_URL` | Selfhosted server URL | `http://localhost:8080` |
| `WANDB_MODE` | Logging mode | `online`, `offline`, `disabled` |
| `WANDB_PROJECT` | Default project name | `my-fine-tuning` |
| `WANDB_ENTITY` | Team or user name | `my-team` |
| `WANDB_DIR` | Local log directory | `/tmp/wandb` |
| `WANDB_SILENT` | Suppress output | `true` |
| `WANDB_DISABLE_CODE` | Don't save code | `true` |
| `WANDB_DISABLE_GIT` | Don't save git info | `true` |

## Backup and Migration

### Export Runs via API

```python
import wandb
import json

api = wandb.Api()
runs = api.runs("my-team/my-project")

exported = []
for run in runs:
    exported.append({
        "name": run.name,
        "config": dict(run.config),
        "summary": dict(run.summary),
        "history": [row for row in run.history()],
    })

with open("runs_export.json", "w") as f:
    json.dump(exported, f, indent=2, default=str)
```

### Backup Local Data

```bash
# Backup wandb local server data
docker compose exec wandb tar czf /tmp/wandb-backup.tar.gz /vol
docker cp wandb-local:/tmp/wandb-backup.tar.gz ./wandb-backup.tar.gz

# Backup offline runs
tar czf wandb-offline-backup.tar.gz ./wandb/
```
