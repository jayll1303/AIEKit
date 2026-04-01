---
name: python-quality-testing
description: "Strengthen Python code quality and test suites. Use when adding type annotations, writing contract docstrings, auditing exception handling, implementing Hypothesis property-based testing, running mutmut mutation testing, or performing code quality reviews."
---

# Python Quality & Testing

Systematic code quality improvements and property-based testing for Python and ML codebases. Combines type annotations, contract docstrings, exception audits, and pre-mortem analysis with Hypothesis property testing and mutmut mutation testing.

## Scope

This skill handles:
- Type annotations, contract docstrings, and exception audit for Python/ML code
- Property-based testing with Hypothesis (strategies, settings, patterns)
- Mutation testing with mutmut (setup, interpretation, CI integration)
- Pre-mortem analysis and code review checklists for ML pipelines
- Ruff linter configuration for ML projects

Does NOT handle:
- Python project bootstrapping, `uv init`, pyproject.toml setup (→ python-project-setup)
- Installing ML dependencies, PyTorch CUDA builds, version conflicts (→ python-ml-deps)
- Fine-tuning or training workflows (→ hf-transformers-trainer)

## When to Use

- Adding or tightening type annotations on an existing codebase
- Writing contract docstrings with preconditions, postconditions, and failure modes
- Auditing try-except blocks for correctness and completeness
- Performing code review on ML pipeline code
- Running a pre-mortem exercise to find fragility in working code
- Writing property-based tests for data processing or ML pipeline code
- Need Hypothesis strategies for ML data types (tensors, DataFrames, configs)
- Testing a parser, serializer, or codec with round-trip properties
- Assessing test suite strength with mutation testing (mutmut)
- Debugging flaky Hypothesis tests (deadlines, health checks, database seeding)
- Adding invariant, idempotence, or metamorphic tests to an existing suite
- Configuring ruff rules for an ML project

---

## Type Annotation Checklist

Work through annotations in priority order. Each level builds on the previous.

### Level 1: Function Signatures (highest impact)

```python
def load_model(path: str | Path, device: str = "cpu") -> nn.Module:
    ...
```

- Annotate all public function parameters
- Use `str | Path` instead of `Union[str, Path]` (Python 3.10+)
- Use `from __future__ import annotations` for older Python versions

### Level 2: Return Types

```python
def predict(model: nn.Module, inputs: torch.Tensor) -> dict[str, torch.Tensor]:
    ...
```

- Annotate all return types, including `-> None`
- Use `-> NoReturn` for functions that always raise
- Prefer concrete types over `Any`

### Level 3: Variables and Attributes

- Annotate class attributes in `__init__` or as class variables
- Annotate variables where the type isn't obvious from the right-hand side
- Skip annotation when the type is trivially clear: `name = "default"` doesn't need `: str`

### Level 4: Generics and Protocols (advanced)

- Use `TypeVar` for functions that preserve input types
- Use `Protocol` to define structural interfaces (duck typing with type safety)
- Use `ParamSpec` for decorator type preservation

> **Deep dive**: See [Type Annotation Guide](references/type-annotation-guide.md) for TypeVar, Protocol, Overload, and ParamSpec patterns specific to ML code

---

## Contract Docstring Template

Document function contracts explicitly. A contract docstring answers: what must be true before calling, what will be true after, and what can go wrong.

```python
def train_epoch(
    model: nn.Module,
    dataloader: DataLoader,
    optimizer: Optimizer,
    device: str = "cuda",
) -> float:
    """Train the model for one epoch and return average loss.

    Preconditions:
        - model is on `device` and in train mode
        - dataloader yields (input_tensor, target_tensor) batches
        - optimizer is configured for model.parameters()

    Postconditions:
        - model weights are updated in-place
        - returned loss is a finite, non-negative float

    Raises:
        RuntimeError: if device is unavailable or tensors have mismatched shapes
        ValueError: if dataloader is empty (zero batches)

    Silences:
        - UserWarning from torch.amp (expected during mixed-precision training)
    """
```

| Section | Purpose |
|---|---|
| **Preconditions** | What the caller must guarantee before calling |
| **Postconditions** | What the function guarantees upon successful return |
| **Raises** | Exceptions the caller should handle (with cause) |
| **Silences** | Warnings or exceptions intentionally suppressed inside the function |

### When to Write Contracts

- Public API functions (called by other modules)
- Functions with non-obvious preconditions (e.g., "model must be on GPU")
- Functions that mutate state (in-place operations, file I/O)
- Functions where failure modes aren't obvious from the signature

> **Deep dive**: See [Contract Docstrings](references/contract-docstrings.md) for full examples including side effects, thread safety, and performance notes

---

## Exception Audit Checklist

Evaluate every `try-except` block against these 5 points. Score each 0 (missing) or 1 (present).

| # | Check | Key Rule |
|---|---|---|
| 1 | **Specificity** | Exception type as narrow as possible (not bare `except Exception`) |
| 2 | **Logging** | Logged with `exc_info=True` and relevant variable values |
| 3 | **Re-raising** | Re-raised or converted with `raise ... from e` (never silently swallowed) |
| 4 | **Cleanup** | Resources released via context managers or `try/finally` |
| 5 | **User Feedback** | Actionable error message suggesting what the user can fix |

### Scoring

| Score | Assessment |
|---|---|
| 5/5 | Solid error handling |
| 3-4/5 | Acceptable, address gaps |
| 0-2/5 | Needs rewrite |

> **Deep dive**: See [Exception Audit](references/exception-audit.md) for a full walkthrough with before/after code examples

---

## Pre-mortem Process

A pre-mortem is a structured exercise where you imagine your working code has caused a production incident, then work backward to find the cause.

### Steps

1. **Pick a target** — Choose a function or pipeline stage handling critical logic
2. **Write the fictional incident report** — 3-5 sentences describing a plausible production failure
3. **Trace the failure path** — Which assumptions would break? Are they documented or enforced?
4. **Harden** — For each fragility, add: runtime assertion, contract docstring, property-based test, or monitoring

### Pre-mortem Prompts for ML Code

- "The model returned NaN for 5% of inputs because..."
- "The training run silently diverged after epoch 50 because..."
- "The feature pipeline produced duplicate rows because..."
- "The A/B test showed no difference because the control and treatment got the same model due to..."
- "The inference latency spiked 10x because..."

---

## Property-Based Testing Quick Start

### Install

```bash
uv add --dev hypothesis
```

**Validate:** `uv run python -c "import hypothesis; print(hypothesis.__version__)"` prints a version. If not → check `uv add` output for resolver errors.

### Basic pattern

```python
from hypothesis import given, settings
import hypothesis.strategies as st

@given(x=st.integers(), y=st.integers())
def test_addition_is_commutative(x: int, y: int) -> None:
    assert x + y == y + x

@given(data=st.lists(st.floats(allow_nan=False, allow_infinity=False), min_size=1))
@settings(max_examples=200, deadline=None)
def test_sorted_output_has_same_length(data: list[float]) -> None:
    result = sorted(data)
    assert len(result) == len(data)
```

### Key `@settings` options

```python
from hypothesis import settings, HealthCheck

@settings(
    max_examples=500,              # more examples for thorough testing
    deadline=None,                 # disable per-example time limit
    suppress_health_check=[        # suppress slow-data warnings for ML tests
        HealthCheck.too_slow,
        HealthCheck.data_too_large,
    ],
)
```

---

## Common Property Patterns

### Invariant

A property that must always hold, regardless of input.

```python
@given(items=st.lists(st.integers()))
def test_sort_preserves_elements(items: list[int]) -> None:
    """Sorting never adds or removes elements."""
    result = sorted(items)
    assert sorted(result) == sorted(items)
    assert len(result) == len(items)
```

### Round-trip

Encode then decode returns the original value.

```python
@given(data=st.dictionaries(st.text(), st.integers()))
def test_json_round_trip(data: dict[str, int]) -> None:
    assert json.loads(json.dumps(data)) == data
```

### Idempotence

Applying an operation twice gives the same result as once.

```python
@given(text=st.text())
def test_strip_is_idempotent(text: str) -> None:
    assert text.strip().strip() == text.strip()
```

### Metamorphic

Transforming input in a known way produces a predictable change in output.

ML example: adding a constant offset to all features doesn't change a distance-based model's ranking.

### Model-based

Compare a complex implementation against a simple reference (oracle).

ML example: compare an optimized batched prediction against a simple loop-based prediction.

> **Deep dive**: See [Property Patterns](references/property-patterns.md) for detailed mapping of each pattern to ML testing scenarios with full code examples

---

## Round-Trip Template

Use this template for testing any parse/serialize pair:

```python
from hypothesis import given, settings
import hypothesis.strategies as st

# 1. Define a strategy that generates valid domain objects
valid_configs = st.fixed_dictionaries({
    "name": st.text(min_size=1, max_size=50),
    "batch_size": st.integers(min_value=1, max_value=4096),
    "learning_rate": st.floats(min_value=1e-8, max_value=1.0),
    "enabled": st.booleans(),
})

@given(original=valid_configs)
@settings(max_examples=200)
def test_config_round_trip(original: dict) -> None:
    """parse(serialize(x)) == x for all valid configs."""
    serialized = serialize_config(original)   # replace with your serializer
    restored = parse_config(serialized)        # replace with your parser
    assert restored == original
```

### Adapting the template

- Replace `valid_configs` with a strategy matching your domain objects
- Replace `serialize_config` / `parse_config` with your actual functions
- For lossy formats (e.g., float precision), use approximate equality with `math.isclose`

---

## Mutation Testing Quick Start

Mutation testing measures test suite quality by injecting small code changes (mutants) and checking if your tests catch them.

### Install

```bash
uv add --dev mutmut
```

**Validate:** `uv run mutmut --version` prints a version. If not → check `uv add` output for resolver errors.

### Run

```bash
uv run mutmut run                    # run mutation testing
uv run mutmut results                # view results summary
uv run mutmut show <mutant-id>       # show a specific surviving mutant
uv run mutmut html                   # generate HTML report
```

### Configure in `pyproject.toml`

```toml
[tool.mutmut]
paths_to_mutate = "src/"
tests_dir = "tests/"
runner = "python -m pytest -x --tb=short"
```

### Interpreting results

| Metric | Meaning |
|---|---|
| Killed | Test suite caught the mutant (good) |
| Survived | Mutant was NOT caught — test gap (bad) |
| Timeout | Mutant caused infinite loop (usually fine) |
| Suspicious | Mutant caused unexpected behavior |

**Target**: aim for >80% mutation kill rate. Surviving mutants reveal specific code paths your tests don't cover.

### Workflow

1. Run `mutmut run` on a module
2. Review surviving mutants with `mutmut show <id>`
3. Write targeted tests to kill survivors
4. Re-run to confirm improvement

**Validate:** `uv run mutmut results` shows kill rate ≥80%. If not → review surviving mutants with `mutmut show <id>` and add targeted tests.

> **Deep dive**: See [Mutation Testing](references/mutation-testing.md) for advanced mutmut configuration, CI integration, and strategies for prioritizing which surviving mutants to address

---

## Quick Reference: Code Review Checklist

When reviewing ML code, check these in order:

1. **Types**: Are function signatures annotated? (→ Type Annotation Checklist above)
2. **Contracts**: Do critical functions have contract docstrings? (→ Contract Docstring Template above)
3. **Exceptions**: Do try-except blocks pass the 5-point audit? (→ Exception Audit above)
4. **Assumptions**: Are implicit assumptions documented or asserted?
5. **Mutability**: Are in-place operations clearly documented?
6. **Reproducibility**: Are random seeds set? Are non-deterministic operations flagged?
7. **Properties**: Are key invariants covered by property-based tests? (→ Property Patterns above)
8. **Mutation score**: Has mutation testing been run to verify test strength? (→ Mutation Testing above)

---

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Code đã có type hints ở vài chỗ, không cần thêm nữa" | Partial annotations che giấu lỗi — mypy chỉ check hàm đã annotated. Annotate toàn bộ public API trước. |
| "Hypothesis chạy chậm, dùng vài unit test cụ thể là đủ" | Unit tests chỉ cover cases bạn nghĩ ra. Hypothesis tìm edge cases bạn không tưởng tượng được (NaN, empty list, Unicode). |
| "Mutation score 60% là chấp nhận được" | 60% nghĩa là 40% code changes không bị test nào phát hiện. Target ≥80%, review surviving mutants trước khi ship. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Cần bootstrap project mới với uv, ruff, pytest | python-project-setup | Setup project structure trước khi thêm quality gates |
| Cần cài PyTorch, CUDA dependencies trước khi test | python-ml-deps | Dependency resolution phải xong trước khi chạy test suite |
| Cần test model training loop end-to-end | hf-transformers-trainer | Training workflow testing nằm ngoài scope code quality |

---

## References

- [Type Annotation Guide](references/type-annotation-guide.md) — TypeVar, Protocol, Overload, ParamSpec patterns for ML code
  **Load when:** adding generics, protocols, or advanced type patterns beyond basic annotations
- [Contract Docstrings](references/contract-docstrings.md) — Full contract docstring examples with preconditions, postconditions, raises, silences
  **Load when:** writing or reviewing contract docstrings for complex functions with side effects or thread safety concerns
- [Exception Audit](references/exception-audit.md) — Detailed audit walkthrough with before/after code examples
  **Load when:** auditing try-except blocks or refactoring error handling in a module
- [Ruff ML Config](references/ruff-ml-config.md) — Recommended ruff rule sets for ML codebases, per-directory overrides
  **Load when:** configuring ruff for an ML project or adding per-directory rule overrides
- [Hypothesis Strategies](references/hypothesis-strategies.md) — Strategy recipes for tensors, DataFrames, config objects, bounded floats, valid JSON, nested structures
  **Load when:** writing Hypothesis strategies for ML-specific data types or complex nested inputs
- [Property Patterns](references/property-patterns.md) — Correctness property patterns mapped to ML testing scenarios with code examples
  **Load when:** choosing which property pattern (invariant, round-trip, metamorphic, model-based) fits a testing scenario
- [Mutation Testing](references/mutation-testing.md) — mutmut setup, configuration, interpreting results, CI integration
  **Load when:** setting up mutmut for the first time or integrating mutation testing into CI
- [Flaky Test Fixes](references/flaky-test-fixes.md) — Hypothesis database seeding, deadline settings, health check suppression, deterministic mode
  **Load when:** debugging flaky Hypothesis tests or configuring deterministic test runs in CI
