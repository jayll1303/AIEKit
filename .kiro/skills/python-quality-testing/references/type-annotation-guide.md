# Type Annotation Guide for ML Code

Advanced type annotation patterns for ML/AI Python codebases: TypeVar, Protocol, Overload, and ParamSpec.

## TypeVar: Preserving Input Types

Use `TypeVar` when a function should return the same type it receives. Common in ML code that operates on both numpy arrays and torch tensors.

### Basic TypeVar

```python
from typing import TypeVar
import numpy as np
import torch

ArrayLike = TypeVar("ArrayLike", np.ndarray, torch.Tensor)

def normalize(data: ArrayLike) -> ArrayLike:
    """Normalize to [0, 1]. Returns same type as input."""
    min_val = data.min()
    max_val = data.max()
    return (data - min_val) / (max_val - min_val + 1e-8)

# Type checker knows these return their input types
arr: np.ndarray = normalize(np.array([1.0, 2.0, 3.0]))
tensor: torch.Tensor = normalize(torch.tensor([1.0, 2.0, 3.0]))
```

### Bound TypeVar

Use `bound` when any subclass should be accepted:

```python
import torch.nn as nn

ModuleT = TypeVar("ModuleT", bound=nn.Module)

def freeze(model: ModuleT) -> ModuleT:
    """Freeze all parameters. Returns the same model (same type)."""
    for param in model.parameters():
        param.requires_grad = False
    return model

# Type checker preserves the concrete subclass
resnet: nn.Linear = freeze(nn.Linear(10, 5))
```

### TypeVar with Callable

```python
from collections.abc import Callable

T = TypeVar("T")
R = TypeVar("R")

def apply_to_batch(
    fn: Callable[[T], R],
    batch: list[T],
) -> list[R]:
    return [fn(item) for item in batch]
```

---

## Protocol: Duck-Typed ML Interfaces

`Protocol` defines structural interfaces — any class with matching methods satisfies the protocol, no inheritance required. Ideal for ML code where libraries use different class hierarchies but share method signatures.

### Basic Protocol

```python
from typing import Protocol, runtime_checkable
import numpy as np
import torch


@runtime_checkable
class Predictable(Protocol):
    """Any object with a predict method — sklearn, custom models, etc."""
    def predict(self, X: np.ndarray) -> np.ndarray: ...

def evaluate_model(model: Predictable, X_test: np.ndarray, y_test: np.ndarray) -> float:
    """Works with sklearn, XGBoost, LightGBM, or any custom model."""
    predictions = model.predict(X_test)
    return float(np.mean(predictions == y_test))
```

### Generic Protocol

```python
from typing import Protocol, TypeVar

T_contra = TypeVar("T_contra", contravariant=True)
R_co = TypeVar("R_co", covariant=True)

class Transform(Protocol[T_contra, R_co]):
    """Generic transform interface for pipeline stages."""
    def __call__(self, data: T_contra) -> R_co: ...

class Preprocessor(Protocol):
    """Preprocessing stage that works on DataFrames."""
    def fit(self, data: "pd.DataFrame") -> "Preprocessor": ...
    def transform(self, data: "pd.DataFrame") -> "pd.DataFrame": ...
    def fit_transform(self, data: "pd.DataFrame") -> "pd.DataFrame": ...
```

### Protocol for Tensor-Like Objects

```python
from typing import Protocol, Any

class TensorLike(Protocol):
    """Anything that behaves like a tensor (numpy, torch, jax)."""
    @property
    def shape(self) -> tuple[int, ...]: ...
    @property
    def dtype(self) -> Any: ...
    def __getitem__(self, key: Any) -> "TensorLike": ...
    def __add__(self, other: Any) -> "TensorLike": ...
    def __mul__(self, other: Any) -> "TensorLike": ...

def check_shapes(a: TensorLike, b: TensorLike) -> bool:
    """Works with numpy, torch, jax arrays — anything with .shape."""
    return a.shape == b.shape
```

### When to Use Protocol vs ABC

| Use Protocol when... | Use ABC when... |
|---|---|
| Interfacing with third-party code you can't modify | You control all implementations |
| Duck typing is the natural pattern | You need shared default implementations |
| You want structural subtyping | You want nominal subtyping |
| Defining interfaces for ML libraries (sklearn, torch, etc.) | Building your own class hierarchy |

---

## Overload: Multiple Signatures

Use `@overload` when a function's return type depends on its input types or argument values. Common in ML code that handles different data formats.

### Return Type Depends on Input Type

```python
from typing import overload
import numpy as np
import torch

@overload
def to_numpy(data: torch.Tensor) -> np.ndarray: ...
@overload
def to_numpy(data: np.ndarray) -> np.ndarray: ...
@overload
def to_numpy(data: list[float]) -> np.ndarray: ...

def to_numpy(data: torch.Tensor | np.ndarray | list[float]) -> np.ndarray:
    if isinstance(data, torch.Tensor):
        return data.detach().cpu().numpy()
    if isinstance(data, np.ndarray):
        return data
    return np.array(data)
```

### Return Type Depends on Argument Value

```python
from typing import Literal, overload
import pandas as pd

@overload
def load_data(path: str, format: Literal["csv"]) -> pd.DataFrame: ...
@overload
def load_data(path: str, format: Literal["numpy"]) -> np.ndarray: ...
@overload
def load_data(path: str, format: Literal["torch"]) -> torch.Tensor: ...

def load_data(
    path: str, format: Literal["csv", "numpy", "torch"] = "csv"
) -> pd.DataFrame | np.ndarray | torch.Tensor:
    if format == "csv":
        return pd.read_csv(path)
    if format == "numpy":
        return np.load(path)
    return torch.load(path, weights_only=True)
```

---

## ParamSpec: Decorator Type Preservation

`ParamSpec` captures the full parameter signature of a function, so decorators preserve type information. Essential for ML code that uses decorators for timing, logging, retries, and GPU management.

### Basic Decorator with ParamSpec

```python
from typing import ParamSpec, TypeVar
from collections.abc import Callable
import functools
import time

P = ParamSpec("P")
R = TypeVar("R")

def timer(func: Callable[P, R]) -> Callable[P, R]:
    """Time a function call. Preserves the original signature."""
    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(f"{func.__name__} took {elapsed:.3f}s")
        return result
    return wrapper

@timer
def train_epoch(model: nn.Module, loader: "DataLoader", lr: float = 1e-3) -> float:
    ...

# Type checker sees: train_epoch(model: nn.Module, loader: DataLoader, lr: float = 1e-3) -> float
```

### Retry Decorator

```python
def retry(max_attempts: int = 3) -> Callable[[Callable[P, R]], Callable[P, R]]:
    """Retry on failure. Useful for flaky GPU operations or API calls."""
    def decorator(func: Callable[P, R]) -> Callable[P, R]:
        @functools.wraps(func)
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            last_error: Exception | None = None
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_error = e
                    print(f"Attempt {attempt + 1}/{max_attempts} failed: {e}")
            raise RuntimeError(f"All {max_attempts} attempts failed") from last_error
        return wrapper
    return decorator

@retry(max_attempts=3)
def download_model(url: str, dest: str) -> Path:
    ...

# Type checker sees: download_model(url: str, dest: str) -> Path
```

---

## Combining Patterns

### TypeVar + Protocol for Pipelines

```python
StepT = TypeVar("StepT")

class PipelineStep(Protocol[StepT]):
    def process(self, data: StepT) -> StepT: ...

def run_pipeline(steps: list[PipelineStep[StepT]], data: StepT) -> StepT:
    for step in steps:
        data = step.process(data)
    return data
```

### TypeAlias for Complex ML Types

```python
from typing import TypeAlias

BatchOutput: TypeAlias = dict[str, torch.Tensor]
MetricsDict: TypeAlias = dict[str, float]
LRSchedule: TypeAlias = Callable[[int], float]
ModelFactory: TypeAlias = Callable[..., nn.Module]
```

---

## Quick Reference

| Pattern | Use When |
|---|---|
| `TypeVar("T", A, B)` | Function returns same type as input (constrained to A or B) |
| `TypeVar("T", bound=Base)` | Function returns same type as input (any subclass of Base) |
| `Protocol` | Define interface for duck-typed objects (sklearn models, datasets) |
| `@runtime_checkable Protocol` | Need `isinstance()` checks at runtime |
| `@overload` | Return type depends on input type or argument value |
| `ParamSpec("P")` | Decorator that preserves wrapped function's signature |
| `TypeAlias` | Readable name for complex type expressions |

## Common Pitfalls

1. **TypeVar reuse across unrelated functions** — Create separate TypeVars for unrelated generic functions. Reusing the same TypeVar implies a type relationship that doesn't exist.

2. **Forgetting `covariant`/`contravariant` on Protocol TypeVars** — Use `covariant=True` for output-only type parameters (return types), `contravariant=True` for input-only (parameter types).

3. **Overload without implementation** — The `@overload` signatures are for the type checker only. You still need the actual implementation without `@overload`.

4. **Using `Any` as an escape hatch** — Prefer `object` when you mean "any type" but don't need attribute access. Reserve `Any` for untyped library boundaries.

5. **Missing `from __future__ import annotations`** — Required for `X | Y` union syntax on Python <3.10.
