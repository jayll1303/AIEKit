# Ruff Configuration for ML Codebases

Recommended ruff rule sets, per-directory overrides, and `noqa` patterns for Python ML projects. All configuration goes in `pyproject.toml` under `[tool.ruff]`.

## Recommended Base Rule Set

Start with a broad selection and disable rules that conflict with ML conventions:

```toml
[tool.ruff]
target-version = "py311"
line-length = 120  # ML code has long tensor expressions

[tool.ruff.lint]
select = [
    "E",      # pycodestyle errors
    "W",      # pycodestyle warnings
    "F",      # pyflakes
    "I",      # isort
    "N",      # pep8-naming
    "UP",     # pyupgrade
    "B",      # flake8-bugbear
    "SIM",    # flake8-simplify
    "TCH",    # flake8-type-checking (move imports behind TYPE_CHECKING)
    "RUF",    # ruff-specific rules
    "C4",     # flake8-comprehensions
    "PIE",    # flake8-pie
    "PT",     # flake8-pytest-style
    "RET",    # flake8-return
    "ARG",    # flake8-unused-arguments
    "PD",     # pandas-vet
    "NPY",    # numpy-specific rules
    "PERF",   # perflint
    "LOG",    # flake8-logging
    "ANN",    # flake8-annotations (optional — enable when tightening types)
]
ignore = [
    "E501",    # line too long — handled by formatter
    "ANN101",  # missing type annotation for self
    "ANN102",  # missing type annotation for cls
    "ANN401",  # Dynamically typed expressions (typing.Any) — common in ML
    "B905",    # zip without strict= — too noisy for batch iteration
    "PD901",   # avoid using df as variable name — universal in ML
    "N803",    # argument name should be lowercase — ML uses X, y, W, b
    "N806",    # variable in function should be lowercase — same reason
    "ARG002",  # unused method argument — common in hook/callback signatures
    "RET504",  # unnecessary assignment before return — aids debugging
]


[tool.ruff.lint.per-file-ignores]
# See "Per-Directory Overrides" section below
```

### Why These Rules?

| Rule Set | Why Include | ML Relevance |
|---|---|---|
| `F` (pyflakes) | Catches undefined names, unused imports | Prevents silent bugs in long training scripts |
| `I` (isort) | Consistent import ordering | ML files often have 15+ imports |
| `B` (bugbear) | Catches common Python gotchas | Mutable default args, assert misuse |
| `TCH` (type-checking) | Moves heavy imports behind `TYPE_CHECKING` | Reduces import time for torch, transformers |
| `PD` (pandas-vet) | Catches pandas anti-patterns | `.values` vs `.to_numpy()`, inplace mutations |
| `NPY` (numpy) | Catches deprecated numpy patterns | `np.bool` → `np.bool_`, legacy random API |
| `PERF` (perflint) | Catches performance anti-patterns | Unnecessary list copies in data pipelines |
| `ANN` (annotations) | Enforces type annotations | Enable gradually — start with public APIs |

---

## Per-Directory Overrides

ML projects have distinct code zones with different quality needs. Use `per-file-ignores` to relax rules where they cause friction.

```toml
[tool.ruff.lint.per-file-ignores]
# Notebooks — exploratory code, relaxed rules
"notebooks/**/*.py" = [
    "E402",    # module-level import not at top — cells reorder imports
    "F401",    # imported but unused — common in exploration
    "F811",    # redefinition of unused name — cell re-execution
    "T201",    # print() found — notebooks use print for output
    "ANN",     # no annotation enforcement in notebooks
    "ARG",     # unused arguments in notebook helper functions
    "B018",    # useless expression — notebooks display values this way
]

# Scripts — one-off training/eval scripts
"scripts/**/*.py" = [
    "T201",    # print() is fine in CLI scripts
    "ANN",     # annotations optional in scripts
    "ARG001",  # unused function argument — argparse callbacks
]

# Tests — pytest conventions differ from production code
"tests/**/*.py" = [
    "ANN",     # no annotation enforcement in tests
    "ARG001",  # unused argument — fixtures injected by name
    "ARG002",  # unused method argument — parametrize callbacks
    "S101",    # assert used — that's what tests do
    "PT004",   # fixture does not return anything — setup fixtures
    "B011",    # assert False — used as deliberate test markers
]

# Conftest files
"**/conftest.py" = [
    "F401",    # imported but unused — fixtures are used by name
    "ARG001",  # unused argument — fixture injection
]
```

### Jupyter Notebook Support

Ruff can lint `.ipynb` files directly. Enable it:

```toml
[tool.ruff]
extend-include = ["*.ipynb"]

[tool.ruff.lint.per-file-ignores]
"*.ipynb" = [
    "E402",    # imports not at top
    "F401",    # unused imports
    "F811",    # redefinition
    "T201",    # print statements
    "B018",    # useless expressions (cell display)
    "ANN",     # no annotations
]
```

---

## Common `noqa` Patterns for ML Code

Some ML conventions require targeted suppression. Use inline `noqa` comments rather than disabling rules globally.

### Star Imports for PyTorch and Friends

```python
from torch import *  # noqa: F403
from torch.nn import *  # noqa: F403
```

Suppress `F403` inline — avoid disabling it globally since it catches real bugs elsewhere. Names imported via star import also trigger `F405` on each usage.

Better approach — use explicit imports and avoid `noqa` entirely:

```python
from torch.nn import Sequential, Linear, ReLU

model = Sequential(Linear(784, 256), ReLU())
```

### Single-Letter Variable Names in Math Code

```python
# Matrix operations — conventional math notation
X = data[:, :-1]  # noqa: N806 — uppercase by convention for matrices
y = data[:, -1]
W = torch.randn(n, m)  # noqa: N806
b = torch.zeros(m)
```

If this pattern is pervasive, add `N806` and `N803` to the global `ignore` list (shown in the base config above).

### Unused Variables in Unpacking

```python
# Common in training loops
for epoch in range(num_epochs):
    for batch_idx, (inputs, targets) in enumerate(dataloader):
        loss, _ = train_step(model, inputs, targets)  # noqa: F841 — metrics unused
```

Prefer using `_` for intentionally unused values — ruff won't flag variables starting with `_`:

```python
for _batch_idx, (inputs, targets) in enumerate(dataloader):
    loss, _metrics = train_step(model, inputs, targets)
```

### Broad Exception Handling in Training Loops

```python
try:
    loss = train_step(model, batch)
except Exception as e:  # noqa: BLE001 — intentional broad catch for resilience
    logger.warning("Batch failed: %s", e)
    continue
```

Document why the broad catch is intentional. Better yet, narrow it after identifying actual failure modes.

---

## Gradual Adoption Strategy

Don't enable everything at once. Roll out in phases:

**Phase 1** — Safe, non-breaking rules:
```toml
select = ["E", "W", "F", "I", "UP"]
```

**Phase 2** — Add bug-catching rules:
```toml
select = ["E", "W", "F", "I", "UP", "B", "SIM", "C4", "RUF"]
```

**Phase 3** — Add ML-specific and style rules:
```toml
select = ["E", "W", "F", "I", "UP", "B", "SIM", "C4", "RUF", "PD", "NPY", "PERF", "TCH"]
```

**Phase 4** — Add annotation enforcement (biggest effort):
```toml
select = [..., "ANN"]
```

Use `--statistics` to see rule violation counts before enabling a new set:

```bash
ruff check --select PD --statistics src/
```

---

## Pre-commit Integration

Add ruff to pre-commit for automatic enforcement:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.6
    hooks:
      - id: ruff
        args: [--fix, --exit-non-zero-on-fix]
      - id: ruff-format
```

---

## Complete Example: ML Project `pyproject.toml`

Putting it all together for a typical ML project:

```toml
[tool.ruff]
target-version = "py311"
line-length = 120
extend-include = ["*.ipynb"]

[tool.ruff.lint]
select = ["E", "W", "F", "I", "N", "UP", "B", "SIM", "TCH", "RUF", "C4", "PIE", "PT", "RET", "PD", "NPY", "PERF", "LOG"]
ignore = ["E501", "N803", "N806", "PD901", "ARG002", "RET504", "B905"]

[tool.ruff.lint.per-file-ignores]
"notebooks/**/*.py" = ["E402", "F401", "F811", "T201", "ANN", "ARG", "B018"]
"*.ipynb" = ["E402", "F401", "F811", "T201", "ANN", "B018"]
"scripts/**/*.py" = ["T201", "ANN", "ARG001"]
"tests/**/*.py" = ["ANN", "ARG001", "ARG002", "S101", "PT004", "B011"]
"**/conftest.py" = ["F401", "ARG001"]

[tool.ruff.lint.isort]
known-first-party = ["myproject"]
known-third-party = ["torch", "transformers", "numpy", "pandas"]
force-sort-within-sections = true

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
docstring-code-format = true
docstring-code-line-length = 80
```

> **See also**: [python-project-setup](../../python-project-setup/SKILL.md) for full pyproject.toml templates including pytest and uv configuration
