---
name: hf-hub-datasets
description: "Download, upload, and stream HuggingFace models and datasets. Use when downloading pretrained models with snapshot_download, loading datasets with load_dataset, pushing to Hub with push_to_hub, streaming large datasets, or managing private repos and gated models."
---

# HuggingFace Hub & Datasets

Commands and patterns for interacting with HuggingFace Hub (model/dataset upload, download, repo management) and processing datasets efficiently with the `datasets` library, including streaming for large-scale data.

## Scope

This skill handles:
- Downloading models and files from HuggingFace Hub (snapshot_download, hf_hub_download, CLI)
- Uploading models, datasets, and model cards to Hub (upload_folder, upload_file, push_to_hub)
- Loading, filtering, mapping, and streaming datasets with the `datasets` library
- Managing Hub repositories (create, delete, private/gated access, organization repos)

Does NOT handle:
- Fine-tuning or training models with Trainer, LoRA, or TRL (→ hf-transformers-trainer)
- Quantizing models to GGUF, GPTQ, or AWQ formats (→ model-quantization)
- Building RAG pipelines or generating text embeddings (→ text-embeddings-rag)

## When to Use

- Downloading a pretrained model or specific model revision from HuggingFace Hub
- Uploading a fine-tuned model or dataset to HuggingFace Hub
- Loading a dataset from Hub or local files with the `datasets` library
- Pushing a processed dataset back to HuggingFace Hub
- Creating a new model or dataset repository on Hub
- Streaming or memory-mapping datasets too large to fit in RAM
- Managing private repositories, gated models, or organization access
- Generating model cards for uploaded models

## Operations Quick Reference Table

| Operation | CLI | Python |
|---|---|---|
| Login / authenticate | `huggingface-cli login` | `huggingface_hub.login(token="hf_...")` |
| Download model | `huggingface-cli download <repo_id>` | `huggingface_hub.snapshot_download("<repo_id>")` |
| Download single file | `huggingface-cli download <repo_id> <filename>` | `huggingface_hub.hf_hub_download("<repo_id>", "<filename>")` |
| Upload model | `huggingface-cli upload <repo_id> <local_dir>` | `huggingface_hub.upload_folder(repo_id="<repo_id>", folder_path="<local_dir>")` |
| Upload single file | `huggingface-cli upload <repo_id> <file> <path_in_repo>` | `huggingface_hub.upload_file(repo_id="<repo_id>", path_or_fileobj="<file>", path_in_repo="<path>")` |
| Create repo | `huggingface-cli repo create <name> --type model` | `huggingface_hub.create_repo("<name>", repo_type="model")` |
| Load dataset | — | `datasets.load_dataset("<dataset_id>")` |
| Push dataset | — | `dataset.push_to_hub("<repo_id>")` |
| Delete repo | — | `huggingface_hub.delete_repo("<repo_id>")` |

## Hub CLI & Python Commands

### Authentication

```bash
# Interactive login (stores token in ~/.cache/huggingface/token)
huggingface-cli login

# Non-interactive login (CI/CD, scripts)
huggingface-cli login --token hf_xxxxxxxxxxxxx

# Verify current login
huggingface-cli whoami
```

```python
from huggingface_hub import login, whoami

# Login with token
login(token="hf_xxxxxxxxxxxxx")

# Or use environment variable (no code change needed)
# export HF_TOKEN=hf_xxxxxxxxxxxxx

# Verify
info = whoami()
print(info["name"])
```

**Validate:** `huggingface-cli whoami` returns your username. If not → run `huggingface-cli login` again or check `HF_TOKEN` env var.

### Download with Revision Selection

```python
from huggingface_hub import snapshot_download, hf_hub_download

# Download entire repo (latest)
snapshot_download("meta-llama/Llama-3.1-8B-Instruct")

# Download specific revision (branch, tag, or commit hash)
snapshot_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    revision="main",
    local_dir="./models/llama-3.1-8b",
)

# Download specific files only (partial download)
snapshot_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    allow_patterns=["*.safetensors", "config.json", "tokenizer*"],
)

# Download single file
hf_hub_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    filename="config.json",
    revision="main",
)
```

```bash
# CLI: download with revision
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct --revision main

# CLI: download specific files
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct \
  --include "*.safetensors" "config.json" "tokenizer*"

# CLI: set local directory
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct \
  --local-dir ./models/llama-3.1-8b
```

### Partial Downloads

```python
from huggingface_hub import snapshot_download

# Include only specific patterns
snapshot_download(
    "bigscience/bloom",
    allow_patterns=["*.json", "*.txt"],  # config + tokenizer only
)

# Exclude large files
snapshot_download(
    "meta-llama/Llama-3.1-8B-Instruct",
    ignore_patterns=["*.bin"],  # skip PyTorch .bin if .safetensors available
)
```

## Upload Patterns

### Create Repository and Upload

```python
from huggingface_hub import HfApi

api = HfApi()

# Create a new model repo
api.create_repo("my-org/my-fine-tuned-model", repo_type="model", private=True)

# Upload entire folder
api.upload_folder(
    repo_id="my-org/my-fine-tuned-model",
    folder_path="./output/checkpoint-final",
    commit_message="Upload fine-tuned model",
)
```

### Model Card Generation

```python
from huggingface_hub import ModelCard, ModelCardData

card_data = ModelCardData(
    language="en",
    license="apache-2.0",
    library_name="transformers",
    tags=["text-generation", "llama"],
    datasets=["my-org/my-dataset"],
    base_model="meta-llama/Llama-3.1-8B-Instruct",
)

card = ModelCard.from_template(
    card_data,
    model_id="my-org/my-fine-tuned-model",
    model_description="Fine-tuned Llama 3.1 8B on custom dataset.",
    training_details="LoRA fine-tuning with r=16, alpha=32.",
    eval_results="Accuracy: 85% on held-out test set.",
)

# Push model card to Hub
card.push_to_hub("my-org/my-fine-tuned-model")
```

### Git LFS Handling

Large files (model weights, datasets >10MB) are automatically tracked by Git LFS on Hub. Key points:

- **Automatic**: `upload_folder` / `upload_file` handle LFS transparently
- **`.gitattributes`**: Hub repos auto-configure LFS patterns for common extensions (`.bin`, `.safetensors`, `.h5`, `.ot`, `.parquet`)
- **Manual LFS tracking** (if using git directly):
  ```bash
  git lfs install
  git lfs track "*.safetensors"
  git add .gitattributes
  git add -A && git commit -m "Add model" && git push
  ```

## Dataset Loading Patterns

### Basic Loading

```python
from datasets import load_dataset

# Load from Hub
dataset = load_dataset("imdb")

# Load specific split
train = load_dataset("imdb", split="train")

# Load specific config/subset
dataset = load_dataset("glue", "mrpc")

# Load from local files
dataset = load_dataset("json", data_files="data/train.jsonl")
dataset = load_dataset("csv", data_files={"train": "train.csv", "test": "test.csv"})
dataset = load_dataset("parquet", data_files="data/*.parquet")
```

**Validate:** `dataset` object prints column names and row count. If `FileNotFoundError` → verify `data_files` path. If `ConnectionError` → check Hub connectivity and token.

### Filter and Map

```python
# Filter rows
filtered = dataset.filter(lambda x: len(x["text"]) > 100)

# Map transformation (with batched processing for speed)
def tokenize(examples):
    return tokenizer(examples["text"], truncation=True, padding="max_length")

tokenized = dataset.map(tokenize, batched=True, num_proc=4)

# Remove columns
tokenized = tokenized.remove_columns(["text", "label_text"])

# Rename columns
tokenized = tokenized.rename_column("label", "labels")
```

### Push Dataset to Hub

```python
# Push entire dataset
dataset.push_to_hub("my-org/my-processed-dataset", private=True)

# Push specific split
train_dataset.push_to_hub("my-org/my-dataset", split="train")
```

## Streaming Large Datasets

When datasets are too large for RAM, use streaming or memory-mapped loading.

### Streaming Mode

```python
from datasets import load_dataset

# Stream from Hub (no download, processes on-the-fly)
stream = load_dataset("allenai/c4", "en", split="train", streaming=True)

# Iterate over examples one at a time
for example in stream:
    text = example["text"]
    # process...
    break  # just showing iteration

# Apply transformations to stream
stream = stream.filter(lambda x: len(x["text"]) > 200)
stream = stream.map(lambda x: {"text_len": len(x["text"])})

# Take first N examples
subset = stream.take(1000)

# Skip first N examples
remaining = stream.skip(1000)

# Shuffle with buffer
shuffled = stream.shuffle(seed=42, buffer_size=10_000)
```

### Memory-Mapped Loading

```python
from datasets import load_dataset

# Default: memory-mapped Arrow files (doesn't load all into RAM)
dataset = load_dataset("large-dataset-id")

# Explicitly keep on disk
dataset = load_dataset("large-dataset-id", keep_in_memory=False)

# Set cache directory for large datasets
dataset = load_dataset(
    "large-dataset-id",
    cache_dir="/mnt/data/hf_cache",
)

# Convert to iterable for memory-efficient processing
iterable = dataset.to_iterable_dataset()
```

### When to Use Streaming vs Memory-Mapped

| Scenario | Approach |
|---|---|
| Dataset fits in disk but not RAM | Memory-mapped (default `load_dataset`) |
| Dataset too large even for disk | Streaming (`streaming=True`) |
| Need random access to rows | Memory-mapped |
| Single-pass processing (training) | Streaming |
| Need `.filter()` / `.map()` with index | Memory-mapped |
| Exploring first N rows | Streaming with `.take(N)` |

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Dataset nhỏ, load hết vào RAM cho nhanh" | Luôn kiểm tra size trước bằng `dataset.info.size_in_bytes`; dataset >2 GB nên dùng streaming hoặc memory-mapped |
| "Không cần login, repo public mà" | Nhiều model/dataset yêu cầu accept license agreement trước khi download (gated repos); luôn verify bằng `huggingface-cli whoami` |
| "push_to_hub sẽ tự tạo repo" | `push_to_hub` tạo repo nếu chưa có, nhưng KHÔNG set private mặc định; phải truyền `private=True` nếu cần private repo |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to fine-tune a model after downloading from Hub | hf-transformers-trainer | Handles TrainingArguments, LoRA, SFTTrainer workflows |
| Need to generate embeddings or build RAG pipeline from downloaded dataset | text-embeddings-rag | Handles sentence-transformers, FAISS, ChromaDB pipelines |
| Need to quantize a downloaded model to GGUF/GPTQ/AWQ | model-quantization | Handles quantization methods and VRAM budget planning |

## References

- [Hub API Patterns](references/hub-api-patterns.md) — Detailed Hub API: revision selection, partial downloads, snapshot_download, model card generation, Git LFS handling
  **Load when:** using advanced Hub API features like revision pinning, allow_patterns/ignore_patterns, or generating model cards
- [Dataset Processing](references/dataset-processing.md) — `datasets` library patterns: load_dataset, filter, map, streaming, train_test_split, interleave, concatenate
  **Load when:** performing dataset transformations (filter, map, split, interleave) or debugging slow dataset processing
- [Private Repos & Organizations](references/private-repos-orgs.md) — Private repository access, organization management, access tokens, gated models
  **Load when:** accessing gated models, managing organization repos, or troubleshooting authentication/permission errors
