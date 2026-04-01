# Hypothesis Strategy Recipes

Reusable strategy definitions for common ML/AI data types: tensors, DataFrames, config objects, file paths, bounded floats, valid JSON, and nested structures.
## NumPy Arrays

```python
import numpy as np
import hypothesis.strategies as st
from hypothesis.extra.numpy import arrays, array_shapes

# Fixed-shape float array (e.g., a single feature vector)
feature_vectors = arrays(
    dtype=np.float32,
    shape=(128,),
    elements=st.floats(min_value=-1.0, max_value=1.0, width=32),
)

# Dynamic-shape batch of vectors
batched_features = arrays(
    dtype=np.float64,
    shape=array_shapes(min_dims=2, max_dims=2, min_side=1, max_side=64),
    elements=st.floats(min_value=-1e6, max_value=1e6, allow_nan=False, allow_infinity=False),
)

# Integer label arrays (e.g., classification targets)
label_arrays = arrays(
    dtype=np.int64,
    shape=array_shapes(min_dims=1, max_dims=1, min_side=1, max_side=256),
    elements=st.integers(min_value=0, max_value=9),
)
```

```python
from hypothesis import given, settings

@given(features=batched_features)
@settings(deadline=None)
def test_normalize_preserves_shape(features: np.ndarray) -> None:
    normed = (features - features.mean()) / (features.std() + 1e-8)
    assert normed.shape == features.shape
```

---

## PyTorch Tensors

Compose from numpy — Hypothesis has no built-in torch support.

```python
import torch
import numpy as np
import hypothesis.strategies as st
from hypothesis.extra.numpy import arrays, array_shapes

@st.composite
def torch_tensors(
    draw: st.DrawFn, min_dims: int = 1, max_dims: int = 4,
    min_side: int = 1, max_side: int = 32, dtype: torch.dtype = torch.float32,
) -> torch.Tensor:
    """Generate a torch tensor with controlled shape and values."""
    np_dtype = {torch.float32: np.float32, torch.float64: np.float64,
                torch.int32: np.int32, torch.int64: np.int64}[dtype]
    elements = (st.floats(-1e4, 1e4, allow_nan=False, allow_infinity=False, width=32)
                if np.issubdtype(np_dtype, np.floating)
                else st.integers(-1000, 1000))
    arr = draw(arrays(
        dtype=np_dtype,
        shape=array_shapes(min_dims=min_dims, max_dims=max_dims,
                           min_side=min_side, max_side=max_side),
        elements=elements,
    ))
    return torch.from_numpy(arr.copy())
```

```python
@given(t=torch_tensors(min_dims=2, max_dims=2))
@settings(deadline=None)
def test_transpose_involution(t: torch.Tensor) -> None:
    assert torch.equal(t.T.T, t)
```

---

## Pandas DataFrames

Use `@st.composite` to keep column lengths consistent.

```python
import pandas as pd
import hypothesis.strategies as st

@st.composite
def ml_dataframes(
    draw: st.DrawFn,
    min_rows: int = 1, max_rows: int = 100,
    n_numeric: int = 3, n_categorical: int = 1,
) -> pd.DataFrame:
    """Generate a DataFrame with numeric and categorical columns."""
    n_rows = draw(st.integers(min_value=min_rows, max_value=max_rows))
    data: dict[str, list] = {}
    for i in range(n_numeric):
        data[f"feat_{i}"] = draw(st.lists(
            st.floats(-1e6, 1e6, allow_nan=False, allow_infinity=False),
            min_size=n_rows, max_size=n_rows,
        ))
    for i in range(n_categorical):
        cats = draw(st.lists(st.text(min_size=1, max_size=10), min_size=1, max_size=5))
        data[f"cat_{i}"] = draw(st.lists(
            st.sampled_from(cats), min_size=n_rows, max_size=n_rows,
        ))
    return pd.DataFrame(data)
```

```python
@given(df=ml_dataframes(n_numeric=4, n_categorical=2))
@settings(deadline=None)
def test_dataframe_shape_after_fillna(df: pd.DataFrame) -> None:
    assert df.fillna(0).shape == df.shape
```

---

## Configuration Objects

Use `st.fixed_dictionaries` for flat configs, `st.builds` for dataclasses.

```python
import hypothesis.strategies as st
from dataclasses import dataclass

training_configs = st.fixed_dictionaries({
    "learning_rate": st.floats(min_value=1e-6, max_value=1.0),
    "batch_size": st.sampled_from([8, 16, 32, 64, 128, 256]),
    "epochs": st.integers(min_value=1, max_value=100),
    "optimizer": st.sampled_from(["adam", "sgd", "adamw"]),
    "weight_decay": st.floats(min_value=0.0, max_value=0.5),
})

@dataclass
class TrainConfig:
    lr: float
    batch_size: int
    epochs: int
    optimizer: str

train_config_strategy = st.builds(
    TrainConfig,
    lr=st.floats(min_value=1e-6, max_value=1.0),
    batch_size=st.sampled_from([16, 32, 64, 128]),
    epochs=st.integers(min_value=1, max_value=50),
    optimizer=st.sampled_from(["adam", "sgd", "adamw"]),
)
```

```python
@given(cfg=training_configs)
def test_config_has_required_keys(cfg: dict) -> None:
    assert {"learning_rate", "batch_size", "epochs", "optimizer"}.issubset(cfg.keys())
```

---

## File Paths

Generate safe, realistic file paths for testing I/O code.

```python
import hypothesis.strategies as st

safe_names = st.from_regex(r"[a-z][a-z0-9_]{0,19}", fullmatch=True)

ml_file_paths = st.tuples(
    st.lists(safe_names, min_size=1, max_size=4), safe_names,
    st.sampled_from([".pt", ".pth", ".onnx", ".csv", ".json", ".parquet", ".npy", ".pkl"]),
).map(lambda t: "/".join(t[0]) + "/" + t[1] + t[2])
```

```python
@given(path=ml_file_paths)
def test_path_has_valid_extension(path: str) -> None:
    assert path.rsplit(".", 1)[-1] in {"pt", "pth", "onnx", "csv", "json", "parquet", "npy", "pkl"}
```

---

## Bounded Floats

Strategies for numeric values with ML-specific constraints.

```python
import hypothesis.strategies as st
import math

probabilities = st.floats(min_value=0.0, max_value=1.0)
temperatures = st.floats(min_value=1e-3, max_value=100.0)  # softmax temperature
epsilons = st.floats(min_value=1e-12, max_value=1e-4)      # numerical stability
dropout_rates = st.floats(min_value=0.0, max_value=0.9)

@st.composite
def log_uniform_floats(draw: st.DrawFn, low: float = 1e-6, high: float = 1.0) -> float:
    """Log-uniform distribution — realistic for learning rates."""
    log_val = draw(st.floats(min_value=math.log(low), max_value=math.log(high)))
    return math.exp(log_val)

learning_rates = log_uniform_floats(low=1e-6, high=1e-1)
```

```python
@given(lr=learning_rates)
def test_lr_is_positive(lr: float) -> None:
    assert lr > 0
```

---

## Valid JSON

Generate well-formed JSON-compatible structures using `st.recursive`.

```python
import hypothesis.strategies as st

json_primitives = st.one_of(
    st.none(), st.booleans(),
    st.integers(-10_000, 10_000),
    st.floats(-1e6, 1e6, allow_nan=False, allow_infinity=False),
    st.text(max_size=50),
)
json_values = st.recursive(
    json_primitives,
    lambda children: st.one_of(
        st.lists(children, max_size=5),
        st.dictionaries(st.text(min_size=1, max_size=20), children, max_size=5),
    ),
    max_leaves=20,
)
json_objects = st.dictionaries(
    st.text(min_size=1, max_size=20), json_values, min_size=1, max_size=10,
)
```

```python
import json
from hypothesis import given

@given(data=json_values)
def test_json_round_trip(data) -> None:
    assert json.loads(json.dumps(data)) == data
```

---

## Nested Structures

Strategies for recursive and deeply nested data common in ML configs.

```python
import hypothesis.strategies as st

@st.composite
def nested_model_configs(draw: st.DrawFn) -> dict:
    """Generate a nested model architecture configuration."""
    layer_specs = {
        "linear": {"in_features": st.integers(1, 1024), "out_features": st.integers(1, 1024)},
        "conv2d": {"in_channels": st.sampled_from([1, 3, 16, 32, 64]),
                   "out_channels": st.sampled_from([16, 32, 64, 128]),
                   "kernel_size": st.sampled_from([1, 3, 5, 7])},
        "lstm": {"hidden_size": st.integers(16, 512), "num_layers": st.integers(1, 4)},
        "attention": {"num_heads": st.sampled_from([1, 2, 4, 8]),
                      "embed_dim": st.sampled_from([64, 128, 256, 512])},
    }
    n_layers = draw(st.integers(min_value=1, max_value=6))
    layers = []
    for _ in range(n_layers):
        ltype = draw(st.sampled_from(list(layer_specs)))
        layer = {"type": ltype}
        for k, strat in layer_specs[ltype].items():
            layer[k] = draw(strat)
        layers.append(layer)
    return {
        "model_name": draw(st.text(min_size=1, max_size=30)),
        "layers": layers,
        "dropout": draw(st.floats(min_value=0.0, max_value=0.5)),
    }

# Recursive tree (e.g., expression trees, nested pipelines)
tree_nodes = st.recursive(
    st.integers(-100, 100),
    lambda children: st.tuples(st.sampled_from(["+", "-", "*"]), children, children),
    max_leaves=10,
)
```

```python
@given(config=nested_model_configs())
def test_nested_config_has_layers(config: dict) -> None:
    assert "layers" in config
    assert len(config["layers"]) >= 1
    for layer in config["layers"]:
        assert "type" in layer
```