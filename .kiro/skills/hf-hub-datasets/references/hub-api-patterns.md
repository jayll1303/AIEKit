# Hub API Patterns

Detailed patterns for interacting with HuggingFace Hub using `huggingface_hub` Python library and CLI.

## Revision Selection

Every Hub repo supports Git-style revisions: branches, tags, and commit hashes.

### Python API

```python
from huggingface_hub import hf_hub_download, snapshot_download

# Download from a specific branch
hf_hub_download("meta-llama/Llama-3.1-8B-Instruct", "config.json", revision="main")

# Download from a tag
hf_hub_download("meta-llama/Llama-3.1-8B-Instruct", "config.json", revision="v1.0")

# Download from a specific commit
hf_hub_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    "config.json",
    revision="a1b2c3d4e5f6",
)

# snapshot_download also supports revision
snapshot_download("meta-llama/Llama-3.1-8B-Instruct", revision="v1.0")
```

### CLI

```bash
# Branch
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct --revision main

# Tag
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct --revision v1.0

# Commit hash
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct --revision a1b2c3d4e5f6
```

### Listing Revisions

```python
from huggingface_hub import HfApi

api = HfApi()

# List all branches and tags
refs = api.list_repo_refs("meta-llama/Llama-3.1-8B-Instruct")
for branch in refs.branches:
    print(f"Branch: {branch.name} -> {branch.target_commit}")
for tag in refs.tags:
    print(f"Tag: {tag.name} -> {tag.target_commit}")

# List commits
commits = api.list_repo_commits("meta-llama/Llama-3.1-8B-Instruct")
for commit in commits[:5]:
    print(f"{commit.commit_id[:8]} - {commit.title}")
```

## Partial Downloads

Download only the files you need to save bandwidth and disk space.

### Pattern-Based Filtering

```python
from huggingface_hub import snapshot_download

# Download only safetensors weights + config
snapshot_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    allow_patterns=["*.safetensors", "config.json", "tokenizer*"],
    local_dir="./models/llama-3.1-8b",
)

# Exclude PyTorch .bin files (when .safetensors available)
snapshot_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    ignore_patterns=["*.bin", "*.pt", "original/**"],
)

# Download only tokenizer files
snapshot_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    allow_patterns=["tokenizer*", "special_tokens_map.json"],
)
```

### CLI Pattern Filtering

```bash
# Include specific patterns
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct \
  --include "*.safetensors" "config.json" "tokenizer*"

# Exclude patterns
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct \
  --exclude "*.bin" "*.pt"
```

### Single File Download

```python
from huggingface_hub import hf_hub_download

# Download one file
path = hf_hub_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    filename="config.json",
    cache_dir="/mnt/data/hf_cache",
)
print(f"Downloaded to: {path}")
```

## snapshot_download Deep Dive

`snapshot_download` is the primary function for downloading entire repos or subsets.

```python
from huggingface_hub import snapshot_download

path = snapshot_download(
    repo_id="meta-llama/Llama-3.1-8B-Instruct",
    repo_type="model",              # "model", "dataset", or "space"
    revision="main",                # branch, tag, or commit hash
    local_dir="./models/llama",     # explicit output directory
    local_dir_use_symlinks=False,   # copy files instead of symlinking from cache
    cache_dir="/mnt/data/hf_cache", # custom cache location
    allow_patterns=["*.safetensors", "*.json"],
    ignore_patterns=["*.bin"],
    max_workers=8,                  # parallel download threads
    token="hf_xxx",                 # or use HF_TOKEN env var
    resume_download=True,           # resume interrupted downloads
)
print(f"Model downloaded to: {path}")
```

### Key Parameters

| Parameter | Default | Description |
|---|---|---|
| `repo_id` | required | Repository ID (e.g., `"org/model"`) |
| `repo_type` | `"model"` | `"model"`, `"dataset"`, or `"space"` |
| `revision` | `"main"` | Branch, tag, or commit hash |
| `local_dir` | `None` | Output directory (uses cache if None) |
| `allow_patterns` | `None` | Glob patterns to include |
| `ignore_patterns` | `None` | Glob patterns to exclude |
| `max_workers` | `8` | Parallel download threads |
| `resume_download` | `True` | Resume interrupted downloads |
| `cache_dir` | `~/.cache/huggingface/hub` | Cache directory |
| `token` | `None` | Auth token (or `HF_TOKEN` env var) |

## Model Card Generation

### Basic Model Card

```python
from huggingface_hub import ModelCard, ModelCardData

card_data = ModelCardData(
    language="en",
    license="apache-2.0",
    library_name="transformers",
    tags=["text-generation", "fine-tuned", "llama"],
    datasets=["my-org/my-training-data"],
    base_model="meta-llama/Llama-3.1-8B-Instruct",
    metrics=[{"type": "accuracy", "value": 0.85, "name": "Accuracy"}],
)

card = ModelCard.from_template(
    card_data,
    model_id="my-org/my-fine-tuned-model",
    model_description="Fine-tuned Llama 3.1 8B for domain-specific tasks.",
    training_details="LoRA fine-tuning, r=16, alpha=32, 3 epochs on A100.",
    eval_results="85% accuracy on held-out test set.",
)

# Save locally
card.save("./output/README.md")

# Or push directly to Hub
card.push_to_hub("my-org/my-fine-tuned-model")
```

### Custom Model Card from Markdown

```python
from huggingface_hub import ModelCard

content = """
---
language: en
license: apache-2.0
tags:
  - text-generation
base_model: meta-llama/Llama-3.1-8B-Instruct
---

# My Fine-Tuned Model

## Description
Fine-tuned Llama 3.1 8B on custom instruction dataset.

## Training
- Method: QLoRA (4-bit NF4)
- Epochs: 3
- Learning rate: 2e-4
- Hardware: 1x NVIDIA A100 80GB

## Usage
```python
from transformers import AutoModelForCausalLM, AutoTokenizer
model = AutoModelForCausalLM.from_pretrained("my-org/my-model")
tokenizer = AutoTokenizer.from_pretrained("my-org/my-model")
```
"""

card = ModelCard(content)
card.push_to_hub("my-org/my-fine-tuned-model")
```

## Git LFS Handling

HuggingFace Hub uses Git LFS for large files. The Python API handles this transparently, but understanding LFS is useful for git-based workflows.

### Automatic LFS (Python API)

```python
from huggingface_hub import HfApi

api = HfApi()

# upload_folder handles LFS automatically
api.upload_folder(
    repo_id="my-org/my-model",
    folder_path="./output/model",
    commit_message="Upload model weights",
)
# .safetensors, .bin, .h5 files are automatically LFS-tracked
```

### Manual Git LFS (git-based workflow)

```bash
# Clone repo
git clone https://huggingface.co/my-org/my-model
cd my-model

# Ensure LFS is installed
git lfs install

# Track large file patterns
git lfs track "*.safetensors"
git lfs track "*.bin"
git lfs track "*.h5"

# Verify .gitattributes
cat .gitattributes
# *.safetensors filter=lfs diff=lfs merge=lfs -text
# *.bin filter=lfs diff=lfs merge=lfs -text

# Add, commit, push
git add .gitattributes
git add -A
git commit -m "Add model weights"
git push
```

### LFS File Size Limits

- Hub free tier: 50GB per repo (LFS storage)
- Hub Pro: 1TB per repo
- Files >5GB: use `upload_large_folder` for chunked upload

```python
from huggingface_hub import HfApi

api = HfApi()

# For very large uploads (>50GB total), use upload_large_folder
api.upload_large_folder(
    repo_id="my-org/my-large-model",
    folder_path="./output/70b-model",
    repo_type="model",
)
```

### Checking LFS Status

```python
from huggingface_hub import HfApi

api = HfApi()

# List files with LFS info
files = api.list_repo_tree("meta-llama/Llama-3.1-8B-Instruct")
for file_info in files:
    if hasattr(file_info, "lfs"):
        print(f"{file_info.rfilename}: {file_info.lfs.size / 1e9:.1f} GB (LFS)")
    elif hasattr(file_info, "size"):
        print(f"{file_info.rfilename}: {file_info.size / 1e3:.1f} KB")
```
