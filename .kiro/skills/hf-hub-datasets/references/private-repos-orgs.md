# Private Repos & Organizations

Patterns for working with private repositories, organization management, access tokens, and gated models on HuggingFace Hub.

## Access Tokens

HuggingFace uses User Access Tokens for authentication. Tokens are created at https://huggingface.co/settings/tokens.

### Token Types

| Type | Permissions | Use Case |
|---|---|---|
| Read | Download public/private repos you have access to | CI/CD pulls, inference |
| Write | Read + upload files, create repos | Training pipelines, model uploads |
| Fine-grained | Custom per-repo/org permissions | Production, least-privilege access |

### Setting Up Authentication

```bash
# Interactive login (recommended for local dev)
huggingface-cli login

# Non-interactive (CI/CD, scripts)
huggingface-cli login --token hf_xxxxxxxxxxxxx

# Environment variable (no login needed)
export HF_TOKEN=hf_xxxxxxxxxxxxx
```

```python
from huggingface_hub import login

# Explicit login
login(token="hf_xxxxxxxxxxxxx")

# Or set env var before importing any HF library
# export HF_TOKEN=hf_xxxxxxxxxxxxx
# All HF libraries (transformers, datasets, huggingface_hub) auto-detect HF_TOKEN
```

### Token in CI/CD

```yaml
# GitHub Actions example
env:
  HF_TOKEN: ${{ secrets.HF_TOKEN }}

steps:
  - name: Download model
    run: huggingface-cli download my-org/my-private-model
```

```dockerfile
# Docker build with token (use build secrets, not ARG)
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=hf_token \
    HF_TOKEN=$(cat /run/secrets/hf_token) \
    huggingface-cli download my-org/my-private-model
```

## Private Repositories

### Creating Private Repos

```python
from huggingface_hub import HfApi

api = HfApi()

# Create private model repo
api.create_repo("my-org/my-model", repo_type="model", private=True)

# Create private dataset repo
api.create_repo("my-org/my-dataset", repo_type="dataset", private=True)
```

```bash
# CLI
huggingface-cli repo create my-model --type model --organization my-org
# Then set visibility via Hub web UI or API
```

### Accessing Private Repos

```python
from huggingface_hub import snapshot_download
from datasets import load_dataset

# Private model — token auto-detected from login or HF_TOKEN
snapshot_download("my-org/my-private-model")

# Explicit token
snapshot_download("my-org/my-private-model", token="hf_xxx")

# Private dataset
dataset = load_dataset("my-org/my-private-dataset")

# With explicit token
dataset = load_dataset("my-org/my-private-dataset", token="hf_xxx")
```

### Changing Repo Visibility

```python
from huggingface_hub import HfApi

api = HfApi()

# Make public
api.update_repo_visibility("my-org/my-model", private=False)

# Make private
api.update_repo_visibility("my-org/my-model", private=True)
```

## Organization Management

### Listing Organization Repos

```python
from huggingface_hub import HfApi

api = HfApi()

# List all models in an organization
models = api.list_models(author="my-org")
for model in models:
    print(f"{model.id} - {model.private}")

# List all datasets in an organization
datasets = api.list_datasets(author="my-org")
for ds in datasets:
    print(f"{ds.id} - {ds.private}")
```

### Organization Roles

| Role | Permissions |
|---|---|
| Read | View and download org repos |
| Contributor | Read + create repos under org |
| Write | Contributor + push to existing repos |
| Admin | Full control: manage members, billing, settings |

### Adding Members (Web UI)

Organization member management is done through the Hub web UI:
1. Go to `https://huggingface.co/organizations/<org-name>/settings/members`
2. Invite by username or email
3. Assign role (read, contributor, write, admin)

## Gated Models

Gated models require users to accept terms before downloading. Common for Llama, Mistral, Gemma, etc.

### Requesting Access

1. Visit the model page (e.g., `https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct`)
2. Click "Access repository" or "Agree and access"
3. Fill out the form (some models require manual approval)
4. Wait for approval (instant for most, manual for some)

### Downloading Gated Models

```python
from huggingface_hub import snapshot_download

# Must be logged in with a token that has accepted the gate
snapshot_download("meta-llama/Llama-3.1-8B-Instruct")

# If not accepted, you'll get:
# huggingface_hub.errors.GatedRepoError: Access to model is restricted.
# You must accept the agreement to access it.
```

```bash
# CLI — same requirement
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct
```

### Creating Gated Repos

```python
from huggingface_hub import HfApi

api = HfApi()

# Enable gating on your repo
api.update_repo_settings(
    "my-org/my-model",
    gated="auto",  # "auto" (instant approval), "manual", or False (no gate)
)
```

### Gated Dataset Access

```python
from datasets import load_dataset

# Same pattern — must have accepted terms
dataset = load_dataset("meta-llama/Llama-3.1-8B-Instruct-evals")
```

## Repo Management Patterns

### Delete Repository

```python
from huggingface_hub import HfApi

api = HfApi()

# Delete model repo (irreversible!)
api.delete_repo("my-org/my-model", repo_type="model")

# Delete dataset repo
api.delete_repo("my-org/my-dataset", repo_type="dataset")
```

### Move / Rename Repository

```python
from huggingface_hub import HfApi

api = HfApi()

# Move repo to different name/org
api.move_repo("old-org/old-name", "new-org/new-name")
```

### List Repo Files

```python
from huggingface_hub import HfApi

api = HfApi()

# List all files in a repo
files = api.list_repo_tree("meta-llama/Llama-3.1-8B-Instruct")
for f in files:
    if hasattr(f, "size"):
        print(f"{f.rfilename}: {f.size / 1e6:.1f} MB")
```

### Repo Tags and Metadata

```python
from huggingface_hub import HfApi

api = HfApi()

# Get model info
info = api.model_info("meta-llama/Llama-3.1-8B-Instruct")
print(f"Downloads: {info.downloads}")
print(f"Tags: {info.tags}")
print(f"Pipeline tag: {info.pipeline_tag}")
print(f"Library: {info.library_name}")

# Get dataset info
info = api.dataset_info("imdb")
print(f"Downloads: {info.downloads}")
```
