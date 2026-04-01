# pyproject.toml Recipes

Advanced pyproject.toml patterns for Python projects using uv. Covers workspaces, optional dependency groups, console scripts, and build backend selection.

## uv Workspaces (Monorepo)

### Root `pyproject.toml`

```toml
[project]
name = "my-monorepo"
version = "0.0.0"
requires-python = ">=3.11"

[tool.uv.workspace]
members = [
    "packages/*",
    "services/*",
]

# Shared dev dependencies across all workspace members
[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "ruff>=0.8",
]
```

### Member `packages/core/pyproject.toml`

```toml
[project]
name = "my-core"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "pydantic>=2.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

### Member referencing another workspace member

```toml
[project]
name = "my-api"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "my-core",       # resolved from workspace, not PyPI
    "fastapi>=0.115",
]

[tool.uv.sources]
my-core = { workspace = true }

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

### Workspace commands

```bash
# Sync all workspace members
uv sync

# Run a command in a specific member
uv run --package my-api python -m my_api

# Add a dependency to a specific member
uv add --package my-api httpx
```

## Optional Dependency Groups

```toml
[project]
name = "my-ml-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "numpy>=1.26",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "ruff>=0.8",
    "pre-commit>=4.0",
    "mypy>=1.11",
]
docs = [
    "mkdocs-material>=9.0",
    "mkdocstrings[python]>=0.25",
]
train = [
    "torch>=2.4",
    "lightning>=2.4",
    "wandb>=0.18",
]
serve = [
    "fastapi>=0.115",
    "uvicorn[standard]>=0.30",
]
all = [
    "my-ml-project[dev,docs,train,serve]",
]
```

### uv dev dependency groups (alternative)

uv supports its own dev dependency groups that are separate from `[project.optional-dependencies]`:

```toml
[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "ruff>=0.8",
]

# Named dev dependency groups (uv 0.5+)
[dependency-groups]
test = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "pytest-xdist>=3.0",
]
lint = [
    "ruff>=0.8",
    "mypy>=1.11",
]
docs = [
    "mkdocs-material>=9.0",
]
dev = [
    { include-group = "test" },
    { include-group = "lint" },
]
```

```bash
# Sync only specific groups
uv sync --group test
uv sync --group lint
uv sync --group test --group lint

# Sync without any dev groups
uv sync --no-dev
```

## Console Scripts and Entry Points

### Console scripts

Register CLI commands installed into the environment's `bin/`:

```toml
[project.scripts]
my-cli = "my_project.cli:main"
my-serve = "my_project.server:run"

# For GUI applications (Windows-specific, no console window)
[project.gui-scripts]
my-gui = "my_project.gui:launch"
```

After `uv sync`, run with `uv run my-cli --verbose`.

### Plugin entry points

Register plugins discoverable by other packages:

```toml
[project.entry-points."my_app.plugins"]
csv_loader = "my_project.plugins.csv:CsvLoader"
json_loader = "my_project.plugins.json:JsonLoader"

[project.entry-points."pytest11"]
my_fixtures = "my_project.testing.fixtures"
```

## Build Backends

### Hatchling (recommended default)

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/my_project"]

[tool.hatch.version]
path = "src/my_project/__init__.py"
```

Best for: pure Python packages, src layout, simple builds.

### Setuptools (legacy compatibility)

```toml
[build-system]
requires = ["setuptools>=75.0", "wheel"]
build-backend = "setuptools.build_meta"

[tool.setuptools.packages.find]
where = ["src"]

[tool.setuptools.package-data]
my_project = ["py.typed", "data/*.json"]
```

Best for: C/C++ extensions, legacy codebases migrating from `setup.py`.

### Maturin (Rust extensions)

Build Python packages with Rust (PyO3) extensions.

```toml
[build-system]
requires = ["maturin>=1.7"]
build-backend = "maturin"

[tool.maturin]
features = ["pyo3/extension-module"]
python-source = "python"
module-name = "my_project._core"
```

Layout: `Cargo.toml` + `src/lib.rs` (Rust) alongside `python/my_project/` (Python + `.pyi` stubs).

Best for: performance-critical code, replacing C extensions with Rust, PyO3 bindings.

### scikit-build-core (CMake extensions)

```toml
[build-system]
requires = ["scikit-build-core>=0.10"]
build-backend = "scikit_build_core.build"

[tool.scikit-build]
cmake.build-type = "Release"
wheel.packages = ["src/my_project"]
```

Best for: CUDA kernels, complex C++ builds, projects using CMake.

## Build Backend Decision Guide

| Criteria | Hatchling | Setuptools | Maturin | scikit-build-core |
|---|---|---|---|---|
| Pure Python | ✅ Best | ✅ Works | ❌ | ❌ |
| C/C++ extensions | ❌ | ✅ Best | ❌ | ✅ Best |
| Rust extensions | ❌ | ❌ | ✅ Best | ❌ |
| CUDA kernels | ❌ | ⚠️ Complex | ❌ | ✅ Best |
| Build speed | Fast | Moderate | Fast | Moderate |
| Config complexity | Minimal | Moderate | Minimal | Moderate |
| src layout support | ✅ Native | ✅ Config needed | ✅ Native | ✅ Config needed |

## Platform-Specific Dependencies

```toml
[project]
dependencies = [
    "numpy>=1.26",
    "colorama>=0.4; sys_platform == 'win32'",
    "uvloop>=0.20; sys_platform != 'win32'",
]
```

## Source Overrides with uv

Pin packages to Git repos, local paths, or custom indexes:

```toml
[tool.uv.sources]
# Git dependency
my-lib = { git = "https://github.com/org/my-lib", branch = "main" }

# Local editable dependency
my-utils = { path = "../my-utils", editable = true }

# Custom index for CUDA wheels
torch = { index = "pytorch-cu124" }

[[tool.uv.index]]
name = "pytorch-cu124"
url = "https://download.pytorch.org/whl/cu124"
explicit = true
```

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for CUDA-specific PyTorch index configuration and ML dependency patterns
