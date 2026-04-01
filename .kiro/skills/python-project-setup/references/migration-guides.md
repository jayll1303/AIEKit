# Migration Guides: Migrating to uv

Step-by-step migration from pip, Poetry, setup.py, and requirements.txt to uv.

## Command Equivalents

### pip → uv

| pip | uv |
|---|---|
| `pip install <pkg>` | `uv add <pkg>` |
| `pip install -r requirements.txt` | `uv add -r requirements.txt` |
| `pip install -e .` | `uv sync` |
| `pip install --upgrade <pkg>` | `uv add <pkg>@latest` |
| `pip uninstall <pkg>` | `uv remove <pkg>` |
| `pip freeze` | `uv pip freeze` |
| `python -m venv .venv` | `uv venv` |

### Poetry → uv

| Poetry | uv |
|---|---|
| `poetry init` | `uv init` |
| `poetry add <pkg>` | `uv add <pkg>` |
| `poetry add --group dev <pkg>` | `uv add --dev <pkg>` |
| `poetry remove <pkg>` | `uv remove <pkg>` |
| `poetry install` | `uv sync` |
| `poetry lock` | `uv lock` |
| `poetry run <cmd>` | `uv run <cmd>` |
| `poetry update` | `uv lock --upgrade && uv sync` |
| `poetry build` | `uv build` |
| `poetry publish` | `uv publish` |

---

## From requirements.txt

### Before

```
# requirements.txt
numpy>=1.24,<2.0
pandas>=2.0
```

### Steps

```bash
uv init --lib
uv add -r requirements.txt
uv add --dev -r requirements-dev.txt   # if exists
uv sync
uv run python -c "import numpy; print(numpy.__version__)"
rm requirements.txt requirements-dev.txt
```

### After

```toml
[project]
dependencies = [
    "numpy>=1.24,<2.0",
    "pandas>=2.0",
]
```

Single `pyproject.toml` + `uv.lock` replaces all requirements files.

---

## From pip + venv

### Before

```bash
python -m venv .venv
source .venv/bin/activate
pip install numpy pandas
pip freeze > requirements.txt
```

### Steps

If you have a `requirements.txt`, follow the section above. Otherwise, export first:

```bash
source .venv/bin/activate
pip freeze > requirements-old.txt
deactivate
rm -rf .venv
uv init --lib
uv add -r requirements-old.txt
rm requirements-old.txt
uv sync
```

Key differences: uv manages `.venv` automatically, `uv.lock` replaces `pip freeze`, use `uv run <cmd>` instead of activating the venv.

---

## From setup.py

### Before

```python
from setuptools import setup, find_packages

setup(
    name="my-project",
    version="0.1.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    python_requires=">=3.11",
    install_requires=["numpy>=1.24", "pandas>=2.0"],
    extras_require={"dev": ["pytest>=8.0", "ruff>=0.8"]},
)
```

### Steps

1. Create `pyproject.toml` mapping setup.py fields:

```toml
[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["numpy>=1.24", "pandas>=2.0"]

[project.optional-dependencies]
dev = ["pytest>=8.0", "ruff>=0.8"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/my_project"]

[tool.uv]
dev-dependencies = ["pytest>=8.0", "ruff>=0.8"]
```

2. Remove old files and sync:

```bash
rm setup.py setup.cfg MANIFEST.in
uv sync
uv run pytest
```

### Field Mapping

| setup.py | pyproject.toml |
|---|---|
| `name` | `[project] name` |
| `version` | `[project] version` |
| `python_requires` | `[project] requires-python` |
| `install_requires` | `[project] dependencies` |
| `extras_require` | `[project.optional-dependencies]` |
| `entry_points.console_scripts` | `[project.scripts]` |

---

## From Poetry

### Before

```toml
[tool.poetry]
name = "my-project"
version = "0.1.0"
description = "My project"

[tool.poetry.dependencies]
python = "^3.11"
numpy = "^1.24"
pandas = "^2.0"

[tool.poetry.group.dev.dependencies]
pytest = "^8.0"
ruff = "^0.8"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
```

### Steps

1. Replace `[tool.poetry]` sections with PEP 621 format:

```toml
[project]
name = "my-project"
version = "0.1.0"
description = "My project"
requires-python = ">=3.11"
dependencies = ["numpy>=1.24,<2", "pandas>=2.0,<3"]

[project.optional-dependencies]
dev = ["pytest>=8.0", "ruff>=0.8"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.uv]
dev-dependencies = ["pytest>=8.0", "ruff>=0.8"]
```

2. Convert Poetry version constraints to PEP 440:

| Poetry | PEP 440 |
|---|---|
| `^1.24` | `>=1.24,<2` |
| `^1.24.3` | `>=1.24.3,<2` |
| `~1.24` | `>=1.24,<1.25` |
| `*` | (no constraint) |

3. Remove Poetry artifacts and sync:

```bash
rm poetry.lock poetry.toml
uv lock
uv sync
uv run pytest
```

### Poetry Groups → uv

```toml
# Poetry groups
[tool.poetry.group.test.dependencies]
pytest = "^8.0"
[tool.poetry.group.docs.dependencies]
sphinx = "^7.0"

# uv equivalent
[tool.uv]
dev-dependencies = ["pytest>=8.0", "sphinx>=7.0"]

# Or as optional dependency groups
[project.optional-dependencies]
test = ["pytest>=8.0"]
docs = ["sphinx>=7.0"]
```

### Poetry Scripts → PEP 621

```toml
# Poetry                              # PEP 621
[tool.poetry.scripts]                  [project.scripts]
my-cli = "my_project.cli:main"        my-cli = "my_project.cli:main"
```

---

## Post-Migration Checklist

- [ ] `uv sync` completes without errors
- [ ] `uv run pytest` passes
- [ ] `uv.lock` committed to version control
- [ ] Old files removed (requirements.txt, setup.py, poetry.lock)
- [ ] CI/CD updated to use `uv sync` and `uv run`
- [ ] `.gitignore` includes `.venv/`

## CI/CD Migration

```yaml
# GitHub Actions
- uses: astral-sh/setup-uv@v4
- run: uv sync
- run: uv run pytest
- run: uv run ruff check .
```
