# Correctness Property Patterns for ML

Mapping of five core property-based testing patterns to ML/AI scenarios. Each pattern includes a definition, guidance on when to use it, and a full Hypothesis code example.

---

## 1. Invariant

**Definition**: A condition that must hold true for all valid inputs, regardless of the specific values.

**When to use in ML**:
- Data pipeline stages that must preserve row counts, column schemas, or value ranges
- Normalization or scaling that must keep outputs within bounds
- Feature engineering that must not introduce NaN or infinity

### Example: Feature normalization stays bounded

```python
import numpy as np
from hypothesis import given, settings
from hypothesis.extra.numpy import arrays, array_shapes
import hypothesis.strategies as st


def min_max_normalize(arr: np.ndarray) -> np.ndarray:
    """Scale array values to [0, 1]."""
    mn, mx = arr.min(), arr.max()
    if mn == mx:
        return np.zeros_like(arr)
    return (arr - mn) / (mx - mn)


bounded_arrays = arrays(
    dtype=np.float64,
    shape=array_shapes(min_dims=1, max_dims=1, min_side=2, max_side=200),
    elements=st.floats(min_value=-1e6, max_value=1e6, allow_nan=False, allow_infinity=False),
)


@given(data=bounded_arrays)
@settings(max_examples=300, deadline=None)
def test_normalization_output_bounded(data: np.ndarray) -> None:
    """Invariant: normalized values are always in [0, 1]."""
    result = min_max_normalize(data)
    assert np.all(result >= 0.0)
    assert np.all(result <= 1.0)


@given(data=bounded_arrays)
@settings(max_examples=300, deadline=None)
def test_normalization_preserves_length(data: np.ndarray) -> None:
    """Invariant: normalization never changes array length."""
    assert len(min_max_normalize(data)) == len(data)
```

---

## 2. Round-Trip

**Definition**: Encoding then decoding (or serializing then deserializing) returns the original value.

**When to use in ML**:
- Model config serialization (YAML/JSON/TOML save → load)
- Dataset export/import (Parquet, CSV with schema)
- Tokenizer encode → decode cycles
- Checkpoint save → load for model weights or optimizer state

### Example: Model config survives JSON round-trip

```python
import json
from hypothesis import given, settings
import hypothesis.strategies as st


model_configs = st.fixed_dictionaries({
    "model_name": st.text(min_size=1, max_size=40, alphabet=st.characters(
        whitelist_categories=("L", "N"), whitelist_characters="_-")),
    "hidden_dim": st.integers(min_value=16, max_value=4096),
    "num_layers": st.integers(min_value=1, max_value=48),
    "dropout": st.floats(min_value=0.0, max_value=0.9,
                         allow_nan=False, allow_infinity=False),
    "use_bias": st.booleans(),
})


def save_config(cfg: dict) -> str:
    return json.dumps(cfg, sort_keys=True)


def load_config(raw: str) -> dict:
    return json.loads(raw)


@given(cfg=model_configs)
@settings(max_examples=300, deadline=None)
def test_config_round_trip(cfg: dict) -> None:
    """Round-trip: load(save(cfg)) == cfg for all valid configs."""
    restored = load_config(save_config(cfg))
    assert restored["model_name"] == cfg["model_name"]
    assert restored["hidden_dim"] == cfg["hidden_dim"]
    assert restored["num_layers"] == cfg["num_layers"]
    assert restored["use_bias"] == cfg["use_bias"]
    # Float comparison with tolerance for JSON precision
    assert abs(restored["dropout"] - cfg["dropout"]) < 1e-10
```

---

## 3. Idempotence

**Definition**: Applying an operation twice produces the same result as applying it once: `f(f(x)) == f(x)`.

**When to use in ML**:
- Data deduplication pipelines
- Text cleaning / preprocessing (lowercasing, whitespace normalization)
- Feature clipping or clamping
- Cache warming or index rebuilding

### Example: Text preprocessing is idempotent

```python
import re
from hypothesis import given, settings
import hypothesis.strategies as st


def clean_text(text: str) -> str:
    """Normalize whitespace and lowercase."""
    text = text.lower().strip()
    text = re.sub(r"\s+", " ", text)
    return text


@given(text=st.text(max_size=500))
@settings(max_examples=300, deadline=None)
def test_clean_text_idempotent(text: str) -> None:
    """Idempotence: cleaning twice == cleaning once."""
    once = clean_text(text)
    twice = clean_text(once)
    assert twice == once
```

Other ML examples: `np.clip(np.clip(x, lo, hi), lo, hi) == np.clip(x, lo, hi)`, dataset deduplication, cache rebuilds.

---

## 4. Metamorphic

**Definition**: Transforming the input in a known way produces a predictable, verifiable change in the output.

**When to use in ML**:
- Testing models where the exact output is unknown but relative behavior is predictable
- Verifying that scaling inputs scales outputs proportionally (linear models)
- Checking that adding noise doesn't flip confident predictions
- Validating that permuting features in a permutation-invariant model gives the same result

### Example: Permutation invariance of set aggregation

```python
import numpy as np
from hypothesis import given, settings
from hypothesis.extra.numpy import arrays, array_shapes
import hypothesis.strategies as st


def aggregate_set(features: np.ndarray) -> np.ndarray:
    """Sum-pool over the set dimension (axis 0) — permutation invariant."""
    return features.sum(axis=0)


set_features = arrays(
    dtype=np.float64,
    shape=st.tuples(
        st.integers(min_value=2, max_value=50),
        st.integers(min_value=1, max_value=16),
    ),
    elements=st.floats(-1e3, 1e3, allow_nan=False, allow_infinity=False),
)


@given(features=set_features, data=st.data())
@settings(max_examples=200, deadline=None)
def test_sum_pool_permutation_invariant(
    features: np.ndarray, data: st.DataObject
) -> None:
    """Metamorphic: permuting rows doesn't change sum-pool output."""
    perm = data.draw(
        st.permutations(list(range(features.shape[0]))),
        label="row_permutation",
    )
    permuted = features[list(perm)]
    np.testing.assert_allclose(
        aggregate_set(features), aggregate_set(permuted), atol=1e-8,
    )
```

### Example: Scaling input scales linear prediction

```python
import numpy as np
from hypothesis import given, settings, assume
from hypothesis.extra.numpy import arrays
import hypothesis.strategies as st


def linear_predict(X: np.ndarray, weights: np.ndarray) -> np.ndarray:
    return X @ weights


@given(
    X=arrays(np.float64, (10, 4), elements=st.floats(-100, 100, allow_nan=False, allow_infinity=False)),
    w=arrays(np.float64, (4,), elements=st.floats(-10, 10, allow_nan=False, allow_infinity=False)),
    scale=st.floats(min_value=0.1, max_value=10.0),
)
@settings(max_examples=200, deadline=None)
def test_linear_scaling(X: np.ndarray, w: np.ndarray, scale: float) -> None:
    """Metamorphic: scaling input by k scales output by k for linear models."""
    original = linear_predict(X, w)
    scaled = linear_predict(X * scale, w)
    np.testing.assert_allclose(scaled, original * scale, rtol=1e-6)
```

---

## 5. Model-Based (Oracle)

**Definition**: Compare a complex or optimized implementation against a simple, trusted reference implementation.

**When to use in ML**:
- Validating an optimized batched prediction against a naive loop
- Checking a vectorized metric against a scalar reference
- Verifying a custom CUDA kernel against a pure-Python equivalent
- Comparing a cached/memoized pipeline against a fresh computation

### Example: Batched softmax vs loop softmax

```python
import numpy as np
from hypothesis import given, settings
from hypothesis.extra.numpy import arrays, array_shapes
import hypothesis.strategies as st


def softmax_reference(logits: np.ndarray) -> np.ndarray:
    """Simple loop-based softmax (trusted oracle)."""
    result = np.empty_like(logits)
    for i in range(logits.shape[0]):
        row = logits[i] - logits[i].max()  # numerical stability
        exp_row = np.exp(row)
        result[i] = exp_row / exp_row.sum()
    return result


def softmax_batched(logits: np.ndarray) -> np.ndarray:
    """Vectorized softmax (implementation under test)."""
    shifted = logits - logits.max(axis=1, keepdims=True)
    exp_vals = np.exp(shifted)
    return exp_vals / exp_vals.sum(axis=1, keepdims=True)


logit_batches = arrays(
    dtype=np.float64,
    shape=st.tuples(
        st.integers(min_value=1, max_value=32),
        st.integers(min_value=2, max_value=64),
    ),
    elements=st.floats(-50, 50, allow_nan=False, allow_infinity=False),
)


@given(logits=logit_batches)
@settings(max_examples=300, deadline=None)
def test_batched_softmax_matches_reference(logits: np.ndarray) -> None:
    """Model-based: vectorized softmax matches loop-based oracle."""
    expected = softmax_reference(logits)
    actual = softmax_batched(logits)
    np.testing.assert_allclose(actual, expected, atol=1e-10)
```

---

## Pattern Selection Guide

| Pattern | Use when you know… | ML example |
|---|---|---|
| Invariant | A condition that must always hold | Normalization output ∈ [0, 1] |
| Round-trip | encode/decode should be lossless | Config save → load |
| Idempotence | Reapplying shouldn't change result | Text cleaning, dedup |
| Metamorphic | How input changes relate to output changes | Permutation invariance |
| Model-based | A simple correct reference exists | Vectorized vs loop impl |

> **See also**: [Hypothesis Strategies](hypothesis-strategies.md) for reusable strategy recipes to pair with these patterns