---
name: python-project-setup
description: "Bootstrap and configure Python projects with uv, ruff, and pytest. Use when running uv init, setting up pyproject.toml, configuring ruff linting and formatting, configuring pytest, adding pre-commit hooks, or migrating from pip or Poetry."
---

# Python Project Setup

Bootstrap well-structured Python projects using uv (package manager), ruff (linter/formatter), and pytest, all configured through a single `pyproject.toml`.

## Scope

This skill handles:
- Initializing new Python projects with `uv init` and src layout
- Creating and editing `pyproject.toml` (dependencies, build system, tool config)
- Configuring ruff for linting and formatting
- Configuring pytest with sensible defaults and plugins
- Setting up pre-commit hooks for code quality
- Migrating from pip, Poetry, setup.py, or requirements.txt to uv
- Structuring Python packages with best-practice layout

Does NOT handle:
- Installing ML/CUDA dependencies like PyTorch, Flash-Attention, bitsandbytes (→ python-ml-deps)
- Type annotations, property-based testing, mutation testing, or code quality audits (→ python-quality-testing)

## When to Use

- Starting a new Python project from scratch
- Running `uv init` and need a complete pyproject.toml template
- Setting up ruff for linting and formatting
- Configuring pytest with sensible defaults
- Adding pre-commit hooks for code quality
- Migrating from pip, Poetry, setup.py, or requirements.txt to uv
- Structuring a Python package with src layout

## Quick Start

### 1. Initialize a new project

```bash
# Create a new project with src layout
uv init my-project --lib
cd my-project

# Or initialize in an existing directory
uv init --lib

# Create virtual environment and install deps
uv sync
```

**Validate:** `uv sync` exits 0 and `.venv/` directory exists. If not → run `uv venv` manually, then `uv sync` again.

### 2. pyproject.toml Template

```toml
[project]
name = "my-project"
version = "0.1.0"
description = "Project description"
readme = "README.md"
requires-python = ">=3.11"
dependencies = []

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "ruff>=0.8",
    "pre-commit>=4.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "ruff>=0.8",
    "pre-commit>=4.0",
]

[tool.ruff]
target-version = "py311"
line-length = 88

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "SIM",  # flake8-simplify
    "TCH",  # flake8-type-checking
    "RUF",  # ruff-specific rules
]
ignore = [
    "E501",  # line too long (handled by formatter)
]

[tool.ruff.lint.isort]
known-first-party = ["my_project"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["src"]
addopts = [
    "-ra",
    "--strict-markers",
    "--strict-config",
    "-x",
]
filterwarnings = [
    "error",
]
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: marks integration tests",
]
```

**Validate:** `uv run ruff check . && uv run pytest --co -q` both exit 0 (lint passes, tests collect). If not → check `[tool.ruff]` and `[tool.pytest.ini_options]` sections for typos.

### 3. Project Layout

```
my-project/
├── pyproject.toml
├── uv.lock
├── README.md
├── src/
│   └── my_project/
│       ├── __init__.py
│       └── main.py
└── tests/
    ├── __init__.py
    └── test_main.py
```

**Validate:** `src/<package>/__init__.py` and `tests/__init__.py` exist. If not → create them: `touch src/my_project/__init__.py tests/__init__.py`.

## Ruff Config

### Running ruff

```bash
# Lint
uv run ruff check .

# Lint with auto-fix
uv run ruff check . --fix

# Format
uv run ruff format .

# Check formatting without changes
uv run ruff format . --check
```

### Per-directory overrides

Add to `pyproject.toml` to relax rules in tests:

```toml
[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = [
    "S101",   # allow assert in tests
    "ARG",    # allow unused function args (fixtures)
    "FBT",    # allow boolean positional args in tests
]
```

## Pytest Config

### Running tests

```bash
# Run all tests
uv run pytest

# Run with coverage
uv run pytest --cov=my_project --cov-report=term-missing

# Run specific test file or pattern
uv run pytest tests/test_main.py -k "test_something"

# Run marked tests
uv run pytest -m "not slow"
```

### Useful pytest plugins

Add to `[tool.uv] dev-dependencies`:

```toml
[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "pytest-xdist>=3.0",    # parallel test execution
    "pytest-randomly>=3.0",  # randomize test order
    "pytest-timeout>=2.0",   # timeout for hanging tests
]
```

## Pre-commit Setup

### Install and configure

```bash
# Install pre-commit
uv add --dev pre-commit

# Install hooks
uv run pre-commit install

# Run against all files (first time)
uv run pre-commit run --all-files
```

**Validate:** `uv run pre-commit run --all-files` exits 0. If not → check `.pre-commit-config.yaml` syntax and hook versions.

### `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.6
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: [--maxkb=1000]
      - id: check-toml
```

## Common Commands Cheat Sheet

```bash
# Dependency management
uv add <package>              # Add a dependency
uv add --dev <package>        # Add a dev dependency
uv remove <package>           # Remove a dependency
uv sync                       # Sync environment with lock file
uv lock                       # Update lock file without syncing

# Run tools through uv
uv run python script.py       # Run a script
uv run pytest                 # Run tests
uv run ruff check .           # Run linter

# Virtual environment
uv venv                       # Create .venv
uv venv --python 3.12         # Create with specific Python version
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Dùng `pip install` cho nhanh, setup uv sau" | Luôn dùng `uv add` từ đầu — pip install không cập nhật pyproject.toml và uv.lock, gây drift giữa environment và lock file |
| "Không cần ruff, project nhỏ mà" | Luôn cấu hình ruff từ đầu — cost gần zero, nhưng bắt lỗi import ordering, unused vars, và type-checking issues sớm |
| "Copy pyproject.toml từ project cũ là xong" | Luôn dùng `uv init --lib` rồi customize — template cũ có thể dùng build backend lỗi thời hoặc thiếu `[tool.uv]` section |
| "Bỏ qua pre-commit, CI sẽ catch lỗi" | Setup pre-commit ngay — catch lỗi trước khi commit tiết kiệm thời gian hơn chờ CI fail |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Cần install PyTorch, CUDA, Flash-Attention, hoặc ML dependencies | python-ml-deps | Xử lý CUDA version conflicts và ML-specific pip index URLs |
| Cần setup type annotations, property-based testing, hoặc mutation testing | python-quality-testing | Chuyên về code quality audits và testing strategies nâng cao |
| Cần cấu hình ruff rules nâng cao cho ML codebases | python-quality-testing | Có ruff-ml-config reference với rule sets tối ưu cho ML |
| Cần thêm error tracking cho Python app | power-sentry | Sentry SDK setup, error capture, performance tracing |

## References

- [Migration Guides](references/migration-guides.md) — Step-by-step migration from pip, Poetry, setup.py, requirements.txt to uv
  **Load when:** migrating an existing project from pip, Poetry, setup.py, or requirements.txt to uv
- [pyproject.toml Recipes](references/pyproject-recipes.md) — Advanced patterns: workspaces, optional deps, scripts, build backends
  **Load when:** configuring workspaces, optional dependency groups, custom scripts, or non-hatchling build backends
- [Troubleshooting](references/troubleshooting.md) — Dependency resolution failures, lock file conflicts, virtual env issues
  **Load when:** encountering dependency resolution errors, uv.lock conflicts, or virtual environment activation issues
