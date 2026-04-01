# Contract Docstrings

Full contract docstring examples for ML/AI Python code: preconditions, postconditions, raises, silences, side effects, thread safety, and performance notes.

## Contract Sections Reference

| Section | Purpose |
|---|---|
| **Preconditions** | What the caller must guarantee |
| **Postconditions** | What the function guarantees on success |
| **Raises** | Exceptions the caller should handle |
| **Silences** | Warnings/exceptions intentionally suppressed |
| **Side Effects** | State changes beyond the return value |
| **Thread Safety** | Concurrency guarantees or restrictions |
| **Performance** | Complexity, memory, or latency notes |

---

## Data Loading

```python
def load_dataset(
    path: str | Path,
    split: Literal["train", "val", "test"],
    max_samples: int | None = None,
    dtype: torch.dtype = torch.float32,
) -> Dataset:
    """Load a dataset split from disk into memory.

    Preconditions:
        - `path` points to a directory containing {split}.parquet files
        - `dtype` is a floating-point torch dtype

    Postconditions:
        - returned Dataset has length > 0
        - all tensors in the dataset use `dtype`
        - if `max_samples` is set, len(dataset) <= max_samples

    Raises:
        FileNotFoundError: if `path` or the split file does not exist
        ValueError: if `split` is not one of "train", "val", "test"
        pyarrow.ArrowInvalid: if the parquet file is corrupted

    Side Effects:
        - reads files from disk

    Performance:
        - O(n) memory where n = number of samples
        - I/O bound on first call; OS page cache helps subsequent calls
    """
```

---

## Model Training

```python
def train_epoch(
    model: nn.Module,
    dataloader: DataLoader,
    optimizer: Optimizer,
    scheduler: LRScheduler | None = None,
    device: str = "cuda",
    grad_clip: float | None = 1.0,
) -> dict[str, float]:
    """Train the model for one full epoch.

    Preconditions:
        - model is on `device` and in train mode (model.training is True)
        - dataloader yields (input_tensor, target_tensor) batches
        - optimizer is configured for model.parameters()
        - if scheduler is provided, it is stepped per-batch (not per-epoch)

    Postconditions:
        - model weights are updated in-place
        - returned dict contains "loss" (finite, non-negative float)
          and "lr" (current learning rate)
        - model remains on `device` and in train mode

    Raises:
        RuntimeError: if device is unavailable or tensors have shape mismatches
        ValueError: if dataloader yields zero batches

    Silences:
        - torch.amp.GradScaler warnings during mixed-precision ramp-up
        - UserWarning from torch.nn.utils.clip_grad_norm_ when max_norm is inf

    Side Effects:
        - mutates model parameters in-place
        - steps optimizer and scheduler state

    Thread Safety:
        - NOT thread-safe: model, optimizer, and scheduler are mutated

    Performance:
        - GPU-bound; throughput scales with batch size up to GPU memory limit
        - gradient clipping adds ~5% overhead per step
    """
```

---

## Inference

```python
@torch.inference_mode()
def predict_batch(
    model: nn.Module,
    inputs: torch.Tensor,
    temperature: float = 1.0,
    top_k: int | None = None,
) -> dict[str, torch.Tensor]:
    """Run inference on a batch and return logits and probabilities.

    Preconditions:
        - model is in eval mode (model.training is False)
        - inputs shape is (batch_size, seq_len) with valid token IDs
        - temperature > 0
        - if top_k is set, top_k > 0

    Postconditions:
        - returned dict contains "logits" (batch_size, vocab_size)
          and "probs" (batch_size, vocab_size) summing to ~1.0 per row
        - all returned tensors are on the same device as inputs
        - model state is unchanged

    Raises:
        ValueError: if temperature <= 0 or top_k <= 0
        torch.cuda.OutOfMemoryError: if batch is too large for GPU memory

    Performance:
        - runs under torch.inference_mode (no grad tracking, lower memory)
        - latency scales linearly with batch_size, quadratically with seq_len
    """
```

---

## Data Preprocessing

```python
def preprocess_features(
    df: pd.DataFrame,
    numeric_cols: list[str],
    categorical_cols: list[str],
    fit: bool = True,
    scaler: StandardScaler | None = None,
) -> tuple[np.ndarray, StandardScaler]:
    """Normalize numeric features and one-hot encode categoricals.

    Preconditions:
        - `df` contains all columns listed in `numeric_cols` and `categorical_cols`
        - numeric columns contain no infinite values
        - if fit=False, `scaler` must be a previously fitted StandardScaler

    Postconditions:
        - returned array has shape (len(df), n_numeric + n_onehot)
        - numeric columns are zero-mean, unit-variance (when fit=True)
        - returned scaler is fitted and can be reused with fit=False
        - NaN values in numeric columns are replaced with column median

    Raises:
        KeyError: if any column in numeric_cols or categorical_cols is missing from df
        ValueError: if fit=False and scaler is None
        ValueError: if numeric columns contain infinite values

    Side Effects:
        - does NOT mutate the input DataFrame
        - if fit=True, fits the scaler in-place (mutates scaler state)

    Performance:
        - O(n * m) where n = rows, m = total feature columns
    """
```

---

## Model Checkpoint I/O

```python
def save_checkpoint(
    model: nn.Module,
    optimizer: Optimizer,
    epoch: int,
    metrics: dict[str, float],
    path: str | Path,
) -> Path:
    """Save a training checkpoint to disk using atomic write.

    Preconditions:
        - parent directory of `path` exists and is writable

    Postconditions:
        - checkpoint file exists at `path` with keys:
          "model_state_dict", "optimizer_state_dict", "epoch", "metrics"
        - file is written atomically (temp file + rename)

    Raises:
        PermissionError: if the directory is not writable
        RuntimeError: if model contains non-serializable custom layers

    Side Effects:
        - writes a file to disk at `path`
        - briefly creates a temporary file in the same directory

    Thread Safety:
        - safe for concurrent writes to DIFFERENT paths
        - NOT safe for concurrent writes to the SAME path
    """
```

---

## Embedding Generation

```python
def encode_texts(
    texts: list[str],
    model: "SentenceTransformer",
    batch_size: int = 32,
    normalize: bool = True,
) -> np.ndarray:
    """Encode texts into dense vector embeddings.

    Preconditions:
        - `texts` is non-empty; each element is a non-empty string
        - `model` is a loaded SentenceTransformer instance

    Postconditions:
        - returned array has shape (len(texts), embedding_dim)
        - if normalize=True, each row has L2 norm ≈ 1.0
        - row order matches input text order

    Raises:
        ValueError: if texts is empty or contains empty strings
        torch.cuda.OutOfMemoryError: if batch_size is too large for GPU

    Thread Safety:
        - safe for concurrent reads if model is not being fine-tuned
        - NOT safe if another thread is updating model weights

    Performance:
        - GPU-bound; throughput improves with larger batch_size up to VRAM limit
    """
```

---

## Writing Good Contracts: Guidelines

### Preconditions

- State what the caller must guarantee, not what the function checks
- If the function validates and raises, that belongs in **Raises**
- Be specific about tensor shapes, dtypes, and device placement

```python
# Good: specific and verifiable
"""
Preconditions:
    - images shape is (batch, channels, height, width) with channels=3
    - pixel values are in [0, 1] range (not [0, 255])
"""

# Bad: vague — "images is a valid tensor"
```

### Postconditions

- Describe the return value's properties, not the implementation
- Include shape, dtype, value range, and ordering guarantees

```python
# Good: testable guarantees
"""
Postconditions:
    - returned tensor has same shape as input
    - all values are in [0, 1] range
"""

# Bad: "returns the normalized data" — restates the function name
```

### Side Effects and Thread Safety

- List every mutation: in-place changes, file writes, global state, GPU memory
- Explicitly state when inputs are NOT mutated (callers care about this)
- Default assumption is NOT thread-safe; document when it IS safe

---

## Quick Reference: When to Document Each Section

| Scenario | Pre | Post | Raises | Silences | Side Effects | Thread Safety | Perf |
|---|---|---|---|---|---|---|---|
| Pure function | ✓ | ✓ | if applicable | — | — | — | if non-obvious |
| In-place mutation | ✓ | ✓ | ✓ | — | ✓ | ✓ | if non-obvious |
| File I/O | ✓ | ✓ | ✓ | — | ✓ | ✓ | ✓ |
| GPU computation | ✓ | ✓ | ✓ | if amp warnings | ✓ | ✓ | ✓ |
| Data pipeline stage | ✓ | ✓ | ✓ | — | ✓ | — | ✓ |
