---
inclusion: auto
name: python-project-conventions
description: Conventions cho Python projects trong ML/AI context. Match khi user hỏi về pyproject.toml, uv, ruff, pytest, Python dependencies, project setup, hoặc code quality.
---

# Python Project Conventions

Khi làm việc với Python projects (đặc biệt ML/AI), tuân thủ các conventions sau.

## Package Manager: uv

- LUÔN dùng `uv` thay vì pip/pip3 trực tiếp
- `uv pip install` cho install, `uv init` cho project mới
- `uv pip compile` cho lock file

Tham khảo skill `python-project-setup` cho chi tiết.

## Project Structure

```
project/
├── pyproject.toml        # Single source of truth cho deps + config
├── uv.lock               # Lock file (commit vào git)
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

KHÔNG install PyTorch/CUDA packages mà không specify index URL:

```bash
# Đúng
uv pip install torch --index-url https://download.pytorch.org/whl/cu121

# Sai — sẽ install CPU version
uv pip install torch
```

Tham khảo skill `python-ml-deps` cho CUDA version matrix và index URLs.

## Linting & Formatting

- Dùng `ruff` (thay thế flake8 + isort + black)
- `ruff check .` trước khi commit
- `ruff format .` cho auto-format

## Testing

- Dùng `pytest` với `pytest-cov`
- `pytest --cov=src/ --cov-report=term-missing`
- Tham khảo skill `python-quality-testing` cho Hypothesis, mutation testing

## Skill Chain Reference

| Cần gì? | Skill |
|---------|-------|
| Bootstrap project (uv init, ruff, pytest) | python-project-setup |
| Install ML deps với CUDA | python-ml-deps |
| Type annotations, property testing | python-quality-testing |
| GPU Docker container | docker-gpu-setup |
