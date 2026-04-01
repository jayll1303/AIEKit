# Exception Audit: Detailed Walkthrough

Auditing `try-except` blocks in ML code using the 5-point checklist. Each example shows real ML code before and after applying all 5 points.

## The 5-Point Checklist (Quick Recap)

| # | Point | Question |
|---|---|---|
| 1 | Specificity | Is the exception type as narrow as possible? |
| 2 | Logging | Is the exception logged with enough context to debug? |
| 3 | Re-raising | Is the exception re-raised or converted appropriately? |
| 4 | Cleanup | Are resources properly released on failure? |
| 5 | User Feedback | Does the user get an actionable error message? |

---

## Example 1: Model Loading

### Before (Score: 1/5)

```python
def load_checkpoint(path, device="cuda"):
    try:
        checkpoint = torch.load(path)
        model = MyModel(checkpoint["config"])
        model.load_state_dict(checkpoint["state_dict"])
        model.to(device)
        return model
    except Exception:
        print("Failed to load model")
        return None
```

1. ❌ Specificity — bare `Exception` catches file, pickle, key, and CUDA errors alike
2. ❌ Logging — `print` with no traceback or variable context
3. ❌ Re-raising — returns `None`, forcing callers to null-check
4. ✅ Cleanup — no resources to leak
5. ❌ User Feedback — no actionable information

### After (Score: 5/5)

```python
logger = logging.getLogger(__name__)

def load_checkpoint(path: str | Path, device: str = "cuda") -> nn.Module:
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Checkpoint not found: {path}")

    try:
        checkpoint = torch.load(path, map_location="cpu", weights_only=True)
    except Exception as e:
        logger.error("Failed to deserialize checkpoint %s", path, exc_info=True)
        raise RuntimeError(f"Corrupt or incompatible checkpoint: {path}") from e

    for key in ("config", "state_dict"):
        if key not in checkpoint:
            raise KeyError(
                f"Checkpoint {path} missing '{key}'. "
                f"Available keys: {list(checkpoint.keys())}"
            )

    model = MyModel(checkpoint["config"])
    try:
        model.load_state_dict(checkpoint["state_dict"])
    except RuntimeError as e:
        logger.error("State dict mismatch for %s", path, exc_info=True)
        raise RuntimeError(
            "State dict incompatible with model architecture. "
            "Check that checkpoint matches the current model version."
        ) from e

    model.to(device)
    return model
```

Split into specific failure modes; each `except` logs with `exc_info=True`; exceptions re-raised with domain context via `from e`; error messages tell the user what to check.

---

## Example 2: Data Pipeline

### Before (Score: 0/5)

```python
def load_training_data(data_dir):
    try:
        files = list(Path(data_dir).glob("*.parquet"))
        dfs = [pd.read_parquet(f) for f in files]
        combined = pd.concat(dfs)
        combined = combined.dropna(subset=["label"])
        return combined
    except:
        pass
```

1. ❌ Specificity — bare `except:` catches `KeyboardInterrupt` and `SystemExit`
2. ❌ Logging — nothing logged
3. ❌ Re-raising — silently swallowed
4. ❌ Cleanup — DataFrames accumulate with no cleanup
5. ❌ User Feedback — none

### After (Score: 5/5)

```python
class DataLoadError(Exception):
    """Raised when training data cannot be loaded or validated."""

def load_training_data(data_dir: str | Path) -> pd.DataFrame:
    data_path = Path(data_dir)
    files = sorted(data_path.glob("*.parquet"))
    if not files:
        raise DataLoadError(
            f"No .parquet files in {data_path}. Check path and format."
        )

    dfs: list[pd.DataFrame] = []
    for f in files:
        try:
            dfs.append(pd.read_parquet(f))
        except (OSError, pd.errors.ParquetError) as e:
            logger.warning("Skipping unreadable file %s: %s", f, e)
            continue

    if not dfs:
        raise DataLoadError(
            f"All {len(files)} parquet files in {data_path} were unreadable."
        )

    combined = pd.concat(dfs, ignore_index=True)
    if "label" not in combined.columns:
        raise DataLoadError(
            f"Required column 'label' not found. "
            f"Available: {list(combined.columns)}"
        )

    before = len(combined)
    combined = combined.dropna(subset=["label"])
    if (dropped := before - len(combined)):
        logger.info("Dropped %d rows with missing labels", dropped)
    return combined
```

Domain-specific `DataLoadError`; per-file error handling logs bad files and continues; validates preconditions; actionable messages.

---

## Example 3: GPU Operations (CUDA OOM)

### Before (Score: 2/5)

```python
def run_inference(model, batch):
    try:
        with torch.no_grad():
            outputs = model(batch.to("cuda"))
        return outputs.cpu()
    except RuntimeError:
        torch.cuda.empty_cache()
        return None
```

1. ⚠️ Specificity — `RuntimeError` is broad; CUDA OOM has a specific subclass
2. ❌ Logging — none
3. ❌ Re-raising — returns `None`
4. ✅ Cleanup — calls `empty_cache()`
5. ❌ User Feedback — caller gets `None` with no explanation

### After (Score: 5/5)

```python
def run_inference(
    model: nn.Module, batch: torch.Tensor, device: str = "cuda"
) -> torch.Tensor:
    try:
        with torch.no_grad():
            outputs = model(batch.to(device))
        return outputs.cpu()
    except torch.cuda.OutOfMemoryError:
        allocated = torch.cuda.memory_allocated() / 1e9
        reserved = torch.cuda.memory_reserved() / 1e9
        logger.error(
            "CUDA OOM. Batch shape: %s, Allocated: %.2f GB, Reserved: %.2f GB",
            batch.shape, allocated, reserved,
        )
        torch.cuda.empty_cache()
        raise RuntimeError(
            f"GPU OOM with batch shape {batch.shape}. "
            f"Try reducing batch_size or using model.half()."
        )
    except RuntimeError as e:
        logger.error("CUDA error during inference: %s", e, exc_info=True)
        raise
```

Catches `torch.cuda.OutOfMemoryError` separately; logs memory stats for debugging; cleans up GPU memory before re-raising; suggests concrete fixes.

---

## Example 4: API Calls (Model Registry)

### Before (Score: 1/5)

```python
def download_model(registry_url, model_name, version):
    try:
        resp = requests.get(f"{registry_url}/models/{model_name}/{version}")
        data = resp.json()
        weights_url = data["artifacts"]["weights"]
        weights = requests.get(weights_url).content
        with open(f"models/{model_name}.pt", "wb") as f:
            f.write(weights)
    except Exception as e:
        print(f"Download failed: {e}")
        raise
```

1. ❌ Specificity — bare `Exception` lumps network, JSON, key, and file errors
2. ❌ Logging — `print` instead of structured logging
3. ✅ Re-raising — at least re-raises
4. ❌ Cleanup — partial file left on disk if write fails midway
5. ❌ User Feedback — raw exception, no guidance

### After (Score: 5/5)

```python
class RegistryError(Exception):
    """Raised when model registry operations fail."""

def download_model(
    registry_url: str, model_name: str, version: str,
    output_dir: str | Path = "models",
) -> Path:
    dest = Path(output_dir) / f"{model_name}.pt"
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Fetch metadata — separate connection vs HTTP errors
    try:
        resp = requests.get(
            f"{registry_url}/models/{model_name}/{version}", timeout=30
        )
        resp.raise_for_status()
    except requests.ConnectionError:
        raise RegistryError(f"Cannot reach registry at {registry_url}.")
    except requests.HTTPError as e:
        raise RegistryError(
            f"Registry HTTP {e.response.status_code} for {model_name}:{version}"
        ) from e

    try:
        weights_url = resp.json()["artifacts"]["weights"]
    except (KeyError, ValueError) as e:
        logger.error("Unexpected registry response: %s", resp.text[:500])
        raise RegistryError("Response missing 'artifacts.weights'.") from e

    # Atomic write: temp file + rename prevents corrupt partial files
    try:
        wr = requests.get(weights_url, timeout=300, stream=True)
        wr.raise_for_status()
        with tempfile.NamedTemporaryFile(dir=output_dir, delete=False) as tmp:
            for chunk in wr.iter_content(chunk_size=8192):
                tmp.write(chunk)
            tmp_path = Path(tmp.name)
        tmp_path.rename(dest)
    except (requests.RequestException, OSError) as e:
        if "tmp_path" in locals() and tmp_path.exists():
            tmp_path.unlink()  # clean up partial temp file
        raise RegistryError(f"Download failed for {model_name}:{version}.") from e
    return dest
```

Separate handling for connection, HTTP, JSON, and download errors; atomic write prevents corrupt files; temp file cleanup on failure.

---

## Audit Workflow

1. **Find all try-except blocks** — search for `except` in the codebase
2. **Score each block** against the 5-point checklist (0 or 1 per point)
3. **Prioritize** — rewrite blocks scoring 0-2 first; address gaps in 3-4 blocks
4. **Group by pattern** — similar blocks often need the same fix
5. **Add domain exceptions** — create module-level exception classes for repeated categories

### Common Anti-Patterns in ML Code

| Anti-Pattern | Fix |
|---|---|
| `except Exception: pass` | Catch specific types, log, re-raise |
| `except: return None` | Raise a domain exception instead |
| `except RuntimeError:` for CUDA | Use `torch.cuda.OutOfMemoryError` |
| `print(e)` in except | Use `logger.error(..., exc_info=True)` |
| No timeout on `requests.get` | Always pass `timeout=` |
| Writing files without atomic rename | Use temp file + `os.rename` |

> **See also**: [Contract Docstrings](contract-docstrings.md) for documenting `Raises` and `Silences` sections that complement good exception handling
