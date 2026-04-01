# Flaky Hypothesis Test Fixes

Diagnostic guide for flaky Hypothesis tests: database seeding, deadline tuning, health check suppression, deterministic mode, and CI-specific settings.

> **Quick start**: See the [main SKILL.md](../SKILL.md#key-settings-options) for basic `@settings` usage.

## Common Symptoms and Fixes

| Symptom | Likely Cause | Fix |
|---|---|---|
| Test passes locally, fails in CI | Slower CI hardware hits deadline | `@settings(deadline=None)` |
| `DeadlineExceeded` intermittently | Per-example time limit too tight | Set `deadline=None` or `timedelta(seconds=5)` |
| `HealthCheck.too_slow` kills the test | Strategy generation is expensive | `suppress_health_check=[HealthCheck.too_slow]` |
| `HealthCheck.data_too_large` | Generated examples exceed size threshold | Suppress or constrain strategy bounds |
| Bug found once, can't reproduce | Hypothesis database not persisted | Cache `.hypothesis/` in CI |
| Different failures on every run | Non-deterministic code under test | Seed RNGs explicitly; use `derandom` setting |
| Passes at `max_examples=100`, fails at `500` | Larger search space finds edge cases | Real bug — investigate the failing example |
| `Flaky` error from Hypothesis | Result changes on replay of same example | Fix non-determinism; check for global state mutation |

## Deadline Settings

The `deadline` setting limits how long each individual example can take. ML tests often exceed the default (200ms) due to model inference or GPU operations.

### Disable or Increase Deadline

```python
from hypothesis import given, settings
import hypothesis.strategies as st
from datetime import timedelta

# Option 1: disable entirely (recommended for ML tests)
@settings(deadline=None)
@given(batch=st.lists(st.floats(allow_nan=False), min_size=1, max_size=1000))
def test_batch_processing(batch: list[float]) -> None:
    result = process_batch(batch)
    assert len(result) == len(batch)

# Option 2: generous deadline
@settings(deadline=timedelta(seconds=5))
@given(...)
def test_slow_operation(data):
    ...
```

## Health Check Suppression

Hypothesis runs health checks to catch common problems. ML tests often trigger these legitimately.

| Health Check | Triggers When | When to Suppress |
|---|---|---|
| `too_slow` | Data generation >200ms per example | Large tensor/DataFrame strategies |
| `data_too_large` | Data exceeds internal size threshold | Complex nested structures, large arrays |
| `filter_too_much` | `.filter()` rejects >50% of examples | **Don't suppress** — constrain strategy instead |
| `large_base_example` | Base example is very large | Strategies with large `min_size` |
| `return_value` | Test returns a non-None value | Test accidentally returns instead of asserting |

```python
from hypothesis import given, settings, HealthCheck

@settings(
    suppress_health_check=[
        HealthCheck.too_slow,
        HealthCheck.data_too_large,
    ]
)
@given(...)
def test_ml_pipeline(data):
    ...
```

## Hypothesis Database for Reproducibility

Hypothesis stores failing examples in `.hypothesis/examples/` so it can replay them on subsequent runs.

### How It Works

1. Hypothesis finds a failing example → saved to `.hypothesis/examples/`
2. On next run, saved examples replay first
3. If the saved example still fails, you get a deterministic reproduction

### Persist the Database in CI

By default, CI runs start with an empty database. Options to preserve failing examples:

**Cache the directory (recommended)**:

```yaml
# GitHub Actions
- name: Cache Hypothesis database
  uses: actions/cache@v4
  with:
    path: .hypothesis/
    key: hypothesis-${{ runner.os }}-${{ hashFiles('tests/**/*.py') }}
    restore-keys: hypothesis-${{ runner.os }}-
```

**Use an explicit database path**:

```python
from hypothesis import settings
from hypothesis.database import DirectoryBasedExampleDatabase

settings.register_profile(
    "ci",
    database=DirectoryBasedExampleDatabase("/tmp/hypothesis-db"),
)
```

### Seed Known Edge Cases with `@example`

```python
from hypothesis import given, example
import hypothesis.strategies as st

@given(x=st.floats(allow_nan=False))
@example(x=0.0)          # always test zero
@example(x=float("inf")) # always test infinity
@example(x=-1e-308)      # always test near-zero negative
def test_safe_division(x: float) -> None:
    result = safe_divide(1.0, x)
    assert isinstance(result, float)
```

`@example` values run before generated examples, guaranteeing coverage of known edge cases.

## Deterministic Mode

### `@seed` Decorator

Pin the random seed for debugging a specific failure:

```python
from hypothesis import given, seed

@seed(12345)
@given(x=st.integers())
def test_deterministic(x: int) -> None:
    assert my_function(x) >= 0
```

> **Warning**: `@seed` disables shrinking and database replay. Use only for debugging — don't commit it.

### `derandom` Setting

Uses a fixed seed derived from the test name — same examples every run:

```python
@settings(derandom=True)
@given(x=st.integers())
def test_always_same_inputs(x: int) -> None:
    ...
```

Trade-off: reproducible runs, but you lose the benefit of exploring new inputs.

### Replay a Seed from Failure Output

Hypothesis prints the seed when a test fails:

```bash
# Hypothesis output:
# You can reproduce this example by temporarily adding @seed(275843790)
```

## CI-Specific Settings

### Recommended Profile Setup

```python
# conftest.py
import os
from hypothesis import settings, HealthCheck, Phase

# Local development — fast feedback
settings.register_profile(
    "dev",
    max_examples=50,
    deadline=200,
)

# CI — thorough, no deadline
settings.register_profile(
    "ci",
    max_examples=500,
    deadline=None,
    suppress_health_check=[
        HealthCheck.too_slow,
        HealthCheck.data_too_large,
    ],
    phases=[
        Phase.explicit,   # run @example() cases
        Phase.reuse,      # replay database entries
        Phase.generate,   # generate new examples
        Phase.shrink,     # shrink failing examples
    ],
)

# Time-constrained CI
settings.register_profile(
    "ci-fast",
    max_examples=100,
    deadline=None,
    suppress_health_check=[HealthCheck.too_slow],
)

settings.load_profile(os.getenv("HYPOTHESIS_PROFILE", "dev"))
```

### GitHub Actions Integration

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      HYPOTHESIS_PROFILE: ci
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
      - run: uv sync --dev

      - name: Cache Hypothesis database
        uses: actions/cache@v4
        with:
          path: .hypothesis/
          key: hypothesis-${{ runner.os }}-${{ hashFiles('tests/**/*.py') }}
          restore-keys: hypothesis-${{ runner.os }}-

      - run: uv run pytest --tb=short -q
```

### Handling CI Timeouts

Set a per-test timeout with pytest-timeout:

```toml
# pyproject.toml
[tool.pytest.ini_options]
timeout = 300  # 5 minutes per test
```

## Debugging Flaky Tests Step by Step

### 1. Reproduce the Failure

```bash
uv run pytest tests/test_pipeline.py::test_transform -v --hypothesis-show-statistics
# If Hypothesis printed a seed, add @seed(XXXXX) temporarily
```

### 2. Check for Non-Determinism

Common sources in ML code:
- **Unseeded RNGs**: `numpy.random`, `torch.manual_seed`, `random.seed`
- **GPU non-determinism**: floating-point ordering varies across runs
- **Timestamps**: `datetime.now()` in assertions
- **Global state**: shared mutable state between tests (model weights, caches)

Fix: seed all RNGs at the start of the test:

```python
import random, numpy as np
from hypothesis import given
import hypothesis.strategies as st

@given(data=st.lists(st.floats(allow_nan=False, allow_infinity=False)))
def test_pipeline(data: list[float]) -> None:
    random.seed(42)
    np.random.seed(42)
    # ... test body
```

### 3. Isolate with Permissive Settings

```python
@settings(
    deadline=None,
    suppress_health_check=list(HealthCheck),  # suppress ALL
    max_examples=50,
)
@given(...)
def test_debug(data):
    ...
```

If flakiness stops, re-enable checks one at a time to find the culprit.

### 4. Clear and Rebuild the Database

```bash
rm -rf .hypothesis/   # nuclear option — start fresh
```

> **See also**: [Hypothesis Strategies](hypothesis-strategies.md) for writing strategies that avoid flakiness, [Property Patterns](property-patterns.md) for robust property formulations