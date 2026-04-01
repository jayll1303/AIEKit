# Dataset Processing Patterns

Detailed patterns for loading, transforming, and managing datasets with the HuggingFace `datasets` library.

## load_dataset

### From Hub

```python
from datasets import load_dataset

# Load all splits
dataset = load_dataset("imdb")
# DatasetDict({ train: Dataset(...), test: Dataset(...) })

# Load specific split
train = load_dataset("imdb", split="train")

# Load specific config/subset
dataset = load_dataset("glue", "mrpc")

# Load with specific revision
dataset = load_dataset("imdb", revision="refs/pr/1")
```

### From Local Files

```python
from datasets import load_dataset

# JSON / JSONL
dataset = load_dataset("json", data_files="data/train.jsonl")
dataset = load_dataset("json", data_files={"train": "train.jsonl", "test": "test.jsonl"})

# CSV
dataset = load_dataset("csv", data_files="data/*.csv")

# Parquet
dataset = load_dataset("parquet", data_files="data/train.parquet")

# Text files (one example per line)
dataset = load_dataset("text", data_files="data/corpus.txt")

# Multiple files with glob
dataset = load_dataset("json", data_files="data/shard_*.jsonl")
```

### From Python Dict / Pandas

```python
from datasets import Dataset
import pandas as pd

# From dict
data = {"text": ["hello", "world"], "label": [0, 1]}
dataset = Dataset.from_dict(data)

# From pandas DataFrame
df = pd.DataFrame({"text": ["hello", "world"], "label": [0, 1]})
dataset = Dataset.from_pandas(df)

# From generator (memory-efficient for large data)
def gen():
    for i in range(1000000):
        yield {"id": i, "text": f"example {i}"}

dataset = Dataset.from_generator(gen)
```

## Filter

```python
# Simple filter
filtered = dataset.filter(lambda x: x["label"] == 1)

# Filter with multiple conditions
filtered = dataset.filter(lambda x: len(x["text"]) > 100 and x["label"] == 1)

# Batched filter (faster for large datasets)
filtered = dataset.filter(
    lambda batch: [len(t) > 100 for t in batch["text"]],
    batched=True,
)

# Filter with index
filtered = dataset.filter(lambda x, idx: idx % 2 == 0, with_indices=True)

# Multiprocessing filter
filtered = dataset.filter(lambda x: len(x["text"]) > 100, num_proc=4)
```

## Map

```python
# Simple map
mapped = dataset.map(lambda x: {"text_upper": x["text"].upper()})

# Batched map (much faster, especially with tokenizers)
def tokenize_batch(examples):
    return tokenizer(examples["text"], truncation=True, padding="max_length")

tokenized = dataset.map(tokenize_batch, batched=True, batch_size=1000)

# Map with multiprocessing
tokenized = dataset.map(tokenize_batch, batched=True, num_proc=4)

# Map that adds/removes columns
def process(example):
    return {
        "input_ids": tokenizer(example["text"])["input_ids"],
        "word_count": len(example["text"].split()),
    }

processed = dataset.map(process, remove_columns=["text"])

# Map with index
mapped = dataset.map(
    lambda x, idx: {"id": idx, **x},
    with_indices=True,
)
```

### Map with Cache

```python
# Map results are cached by default. Force recompute:
processed = dataset.map(my_fn, load_from_cache_file=False)

# Set custom cache file
processed = dataset.map(my_fn, cache_file_name="./cache/processed.arrow")
```

## Streaming

Streaming processes data on-the-fly without downloading the entire dataset.

```python
from datasets import load_dataset

# Enable streaming
stream = load_dataset("allenai/c4", "en", split="train", streaming=True)
# Returns IterableDataset (not Dataset)

# Iterate
for example in stream:
    process(example)

# Transformations on streams
stream = stream.filter(lambda x: len(x["text"]) > 200)
stream = stream.map(lambda x: {"text_len": len(x["text"])})

# Take / skip
first_1000 = stream.take(1000)
after_1000 = stream.skip(1000)

# Shuffle with buffer (approximate shuffle)
shuffled = stream.shuffle(seed=42, buffer_size=10_000)

# Batch iteration
from torch.utils.data import DataLoader

dataloader = DataLoader(stream, batch_size=32)
for batch in dataloader:
    # batch is a dict of lists
    pass
```

### Converting Between Modes

```python
# Dataset → IterableDataset
iterable = dataset.to_iterable_dataset()

# IterableDataset → Dataset (materializes into memory/disk)
# Only feasible for small streams
materialized = Dataset.from_generator(lambda: iter(stream))
```

## train_test_split

```python
# Random split
split = dataset.train_test_split(test_size=0.2, seed=42)
# DatasetDict({ train: Dataset(...), test: Dataset(...) })

train = split["train"]
test = split["test"]

# Stratified split (preserves label distribution)
split = dataset.train_test_split(test_size=0.2, seed=42, stratify_by_column="label")

# Custom split sizes
split = dataset.train_test_split(train_size=0.8, test_size=0.1, seed=42)
# Remaining 10% is discarded
```

## Interleave Datasets

Combine multiple datasets by alternating examples (useful for multi-task training).

```python
from datasets import interleave_datasets, load_dataset

ds1 = load_dataset("dataset_a", split="train")
ds2 = load_dataset("dataset_b", split="train")
ds3 = load_dataset("dataset_c", split="train")

# Equal interleaving
combined = interleave_datasets([ds1, ds2, ds3])

# Weighted interleaving (sample more from ds1)
combined = interleave_datasets(
    [ds1, ds2, ds3],
    probabilities=[0.5, 0.3, 0.2],
    seed=42,
)

# With streaming
stream1 = load_dataset("dataset_a", split="train", streaming=True)
stream2 = load_dataset("dataset_b", split="train", streaming=True)
combined_stream = interleave_datasets([stream1, stream2])

# Stopping strategy
combined = interleave_datasets(
    [ds1, ds2],
    stopping_strategy="all_exhausted",  # or "first_exhausted" (default)
)
```

## Concatenate Datasets

Stack datasets vertically (same columns required).

```python
from datasets import concatenate_datasets, load_dataset

ds1 = load_dataset("dataset_a", split="train")
ds2 = load_dataset("dataset_b", split="train")

# Simple concatenation
combined = concatenate_datasets([ds1, ds2])

# Concatenate with different column sets (fills missing with None)
# Both datasets must have compatible features/schemas
```

## Column Operations

```python
# Remove columns
dataset = dataset.remove_columns(["unnecessary_col1", "unnecessary_col2"])

# Rename columns
dataset = dataset.rename_column("old_name", "new_name")
dataset = dataset.rename_columns({"old1": "new1", "old2": "new2"})

# Select columns
dataset = dataset.select_columns(["text", "label"])

# Cast column type
from datasets import Value
dataset = dataset.cast_column("label", Value("int32"))
```

## Sorting and Selecting

```python
# Sort by column
sorted_ds = dataset.sort("text_length", reverse=True)

# Select specific rows by index
subset = dataset.select(range(100))  # first 100 rows
subset = dataset.select([0, 5, 10, 15])  # specific indices

# Shuffle
shuffled = dataset.shuffle(seed=42)

# Flatten nested features
flattened = dataset.flatten()
```

## Saving and Loading Locally

```python
# Save to disk (Arrow format, fast)
dataset.save_to_disk("./data/processed_dataset")

# Load from disk
from datasets import load_from_disk
dataset = load_from_disk("./data/processed_dataset")

# Save to specific formats
dataset.to_json("data/output.jsonl")
dataset.to_csv("data/output.csv")
dataset.to_parquet("data/output.parquet")
```

## Push to Hub

```python
# Push entire DatasetDict
dataset.push_to_hub("my-org/my-dataset", private=True)

# Push specific split
train_dataset.push_to_hub("my-org/my-dataset", split="train")

# Push with commit message
dataset.push_to_hub(
    "my-org/my-dataset",
    commit_message="Add processed v2 dataset",
)

# Push as Parquet (default) or other format
dataset.push_to_hub("my-org/my-dataset")  # Parquet by default
```
