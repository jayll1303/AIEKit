# MLflow Model Registry

Patterns for managing model lifecycle with MLflow Model Registry: registering models, versioning, stage transitions (Staging → Production), promotion workflows, and model serving.

## Model Registry Overview

The MLflow Model Registry provides:

- **Centralized model store**: Single place to manage all model versions
- **Version tracking**: Automatic versioning when new models are registered
- **Stage management**: Transition models through stages (None → Staging → Production → Archived)
- **Annotations**: Add descriptions and tags to models and versions
- **Lineage**: Link model versions back to the training run that produced them

## Register a Model

### From a Training Run

```python
import mlflow

mlflow.set_tracking_uri("http://localhost:5000")

with mlflow.start_run() as run:
    # Train model...
    mlflow.log_params({"model": "llama-8b", "method": "LoRA"})
    mlflow.log_metrics({"eval_loss": 0.85})

    # Log and register model in one step
    mlflow.pyfunc.log_model(
        artifact_path="model",
        python_model=my_model_wrapper,
        registered_model_name="llama-8b-sft",  # Auto-registers
    )
```

### Register an Existing Run's Artifacts

```python
from mlflow import MlflowClient

client = MlflowClient("http://localhost:5000")

# Register model from an existing run
result = client.create_model_version(
    name="llama-8b-sft",
    source=f"runs:/{run_id}/model",
    run_id=run_id,
    description="LoRA fine-tuned Llama 3.1 8B on custom dataset",
)

print(f"Registered version: {result.version}")
```

### Create a Registered Model First

```python
from mlflow import MlflowClient

client = MlflowClient("http://localhost:5000")

# Create the registered model entry
client.create_registered_model(
    name="llama-8b-sft",
    description="Llama 3.1 8B fine-tuned for customer support",
    tags={"team": "ml-platform", "task": "text-generation"},
)

# Then register versions against it
client.create_model_version(
    name="llama-8b-sft",
    source=f"runs:/{run_id}/model",
    run_id=run_id,
)
```

## Version Management

### List Versions

```python
from mlflow import MlflowClient

client = MlflowClient("http://localhost:5000")

# List all versions of a model
versions = client.search_model_versions("name='llama-8b-sft'")
for v in versions:
    print(f"Version {v.version}: stage={v.current_stage}, run_id={v.run_id}")
```

### Get Specific Version

```python
# Get latest version in a stage
latest = client.get_latest_versions("llama-8b-sft", stages=["Production"])
if latest:
    prod_version = latest[0]
    print(f"Production version: {prod_version.version}")
    print(f"Source: {prod_version.source}")

# Get specific version
version_info = client.get_model_version("llama-8b-sft", version="3")
```

### Add Description and Tags

```python
# Update version description
client.update_model_version(
    name="llama-8b-sft",
    version="3",
    description="Trained on v2 dataset, 15% improvement on eval set",
)

# Add tags to version
client.set_model_version_tag("llama-8b-sft", "3", "dataset", "v2")
client.set_model_version_tag("llama-8b-sft", "3", "eval_loss", "0.72")
```

## Stage Transitions

### Promotion Workflow

```
None → Staging → Production → Archived
```

```python
from mlflow import MlflowClient

client = MlflowClient("http://localhost:5000")

# Promote to Staging
client.transition_model_version_stage(
    name="llama-8b-sft",
    version="3",
    stage="Staging",
    archive_existing_versions=False,  # Keep current staging version
)

# After validation, promote to Production
client.transition_model_version_stage(
    name="llama-8b-sft",
    version="3",
    stage="Production",
    archive_existing_versions=True,  # Archive previous production version
)

# Archive old version
client.transition_model_version_stage(
    name="llama-8b-sft",
    version="1",
    stage="Archived",
)
```

### Automated Promotion Script

```python
from mlflow import MlflowClient

client = MlflowClient("http://localhost:5000")

def promote_if_better(model_name: str, new_version: str, metric: str = "eval_loss"):
    """Promote new version to Production if it beats current Production."""

    # Get current production version
    prod_versions = client.get_latest_versions(model_name, stages=["Production"])

    # Get new version's run metrics
    new_info = client.get_model_version(model_name, new_version)
    new_run = client.get_run(new_info.run_id)
    new_metric = new_run.data.metrics.get(metric)

    if not prod_versions:
        # No production version yet — promote directly
        client.transition_model_version_stage(
            name=model_name, version=new_version,
            stage="Production", archive_existing_versions=False,
        )
        print(f"Promoted v{new_version} to Production (first version)")
        return True

    # Compare with current production
    prod_run = client.get_run(prod_versions[0].run_id)
    prod_metric = prod_run.data.metrics.get(metric)

    if new_metric is not None and prod_metric is not None and new_metric < prod_metric:
        client.transition_model_version_stage(
            name=model_name, version=new_version,
            stage="Production", archive_existing_versions=True,
        )
        print(f"Promoted v{new_version} ({metric}: {new_metric:.4f} < {prod_metric:.4f})")
        return True
    else:
        print(f"Kept current production ({metric}: {prod_metric:.4f} <= {new_metric:.4f})")
        return False

# Usage
promote_if_better("llama-8b-sft", new_version="5", metric="eval_loss")
```

## Model Serving

### Load Model from Registry

```python
import mlflow

# Load by stage
model = mlflow.pyfunc.load_model("models:/llama-8b-sft/Production")

# Load by version number
model = mlflow.pyfunc.load_model("models:/llama-8b-sft/3")

# Load latest version
model = mlflow.pyfunc.load_model("models:/llama-8b-sft/latest")
```

### Serve Model with MLflow

```bash
# Serve a registered model version
mlflow models serve \
  --model-uri "models:/llama-8b-sft/Production" \
  --host 0.0.0.0 \
  --port 8000 \
  --no-conda

# Test the endpoint
curl -X POST http://localhost:8000/invocations \
  -H "Content-Type: application/json" \
  -d '{"inputs": ["Hello, how can I help you?"]}'
```

### Download Model Artifacts

```python
from mlflow import MlflowClient

client = MlflowClient("http://localhost:5000")

# Download model artifacts to local directory
version = client.get_model_version("llama-8b-sft", "3")
local_path = client.download_artifacts(version.run_id, "model", dst_path="./downloaded-model")
print(f"Model downloaded to: {local_path}")
```

## Registry Best Practices

| Practice | Description |
|---|---|
| Naming convention | Use `<model-family>-<size>-<task>` (e.g., `llama-8b-sft`, `mistral-7b-rag`) |
| Always tag versions | Include dataset version, eval metrics, training method |
| Use descriptions | Document what changed in each version |
| Archive, don't delete | Keep old versions for reproducibility |
| Automate promotion | Use metric-based promotion scripts |
| Link to runs | Always register from a tracked run for full lineage |
| One model per task | Don't mix different tasks in the same registered model |
