---
inclusion: auto
name: python-project-conventions
description: Conventions for Python projects in ML/AI context. Match when user asks about pyproject.toml, uv, ruff, pytest, Python dependencies, project setup, or code quality.
---

# Python Project Conventions

When working with Python projects (especially ML/AI), follow these conventions.

## Package Manager: uv

- ALWAYS use `uv` instead of pip/pip3 directly
- `uv pip install` for installing, `uv init` for new projects
- `uv pip compile` for lock files

See skill `python-project-setup` for details.

## Project Structure

```
project/
├── pyproject.toml        # Single source of truth for deps + config
├── uv.lock               # Lock file (commit to git)
├── src/
│   └── package_name/
│       ├── __init__.py
│       └── ...
├── tests/
│   └── ...
└── .python-version       # Pin Python version
```

## pyproject.toml Essentials

```toml
[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "torch>=2.0",
]

[project.optional-dependencies]
dev = ["ruff", "pytest", "pytest-cov"]
gpu = ["flash-attn"]  # CUDA-specific extras

[tool.ruff]
line-length = 120
target-version = "py310"

[tool.ruff.lint]
select = ["E", "F", "I", "W"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

## CUDA Dependencies — HARD GATE

Do NOT install PyTorch/CUDA packages without specifying the index URL:

```bash
# Correct
uv pip install torch --index-url https://download.pytorch.org/whl/cu121

# Wrong — will install the CPU version
uv pip install torch
```

See skill `python-ml-deps` for CUDA version matrix and index URLs.

## Linting & Formatting

- Use `ruff` (replaces flake8 + isort + black)
- `ruff check .` before committing
- `ruff format .` for auto-format

## Testing

- Use `pytest` with `pytest-cov`
- `pytest --cov=src/ --cov-report=term-missing`
- See skill `python-quality-testing` for Hypothesis and mutation testing

## Skill Chain Reference

| Need | Skill |
|------|-------|
| Bootstrap project (uv init, ruff, pytest) | python-project-setup |
| Install ML deps with CUDA | python-ml-deps |
| Type annotations, property testing | python-quality-testing |
| GPU Docker container | docker-gpu-setup |
