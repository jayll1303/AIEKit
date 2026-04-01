# xformers & RAPIDS

Installing xformers (pre-built wheels vs source build) and RAPIDS (cuDF, cuML) with `uv`, including version matching, conda-vs-pip options, and fixes for common errors.

> **Last verified**: xformers 0.0.27.x–0.0.29.x with PyTorch 2.4–2.6; RAPIDS 24.06–24.12

---

## xformers

### Overview

xformers provides memory-efficient attention and other optimized transformer building blocks. Unlike Flash-Attention, xformers supports Turing GPUs (sm_75+) and ships pre-built wheels for common PyTorch + CUDA combinations.

### Pre-Built Wheels (Recommended)

xformers wheels are published to the PyTorch index. The wheel must match your exact PyTorch version and CUDA version:

```bash
# Install from PyTorch index (must match your PyTorch + CUDA)
uv pip install xformers --index-url https://download.pytorch.org/whl/cu124
```

#### Wheel Availability Matrix

| PyTorch | CUDA 11.8 | CUDA 12.1 | CUDA 12.4 | CUDA 12.6 |
|---------|-----------|-----------|-----------|-----------|
| 2.4.x   | ✅        | ✅        | ✅        | ❌        |
| 2.5.x   | ✅        | ✅        | ✅        | ❌        |
| 2.6.x   | ❌        | ✅        | ✅        | ✅        |

**Rule**: xformers wheels are tightly coupled to PyTorch versions. A wheel built for PyTorch 2.5 will not work with PyTorch 2.6. Always install xformers from the same index URL you used for PyTorch.

### Checking Wheel Availability

```bash
# Check your current PyTorch version and CUDA
python -c "import torch; print(f'PyTorch {torch.__version__}, CUDA {torch.version.cuda}')"
```

### Building from Source

When no pre-built wheel matches your PyTorch + CUDA combination, build from source:

```bash
# Requires: CUDA toolkit, C++ compiler, PyTorch already installed
uv pip install xformers --no-build-isolation
```

#### Source Build Environment Variables

| Variable | Default | Description |
|---|---|---|
| `MAX_JOBS` | nproc | Parallel compilation jobs. Lower if OOM. |
| `TORCH_CUDA_ARCH_LIST` | (auto) | Target GPU architectures (semicolon-separated) |
| `XFORMERS_FORCE_DISABLE_TRITON` | `0` | Set to `1` to skip Triton-based kernels |

```bash
# Build for specific GPU (faster compilation)
TORCH_CUDA_ARCH_LIST="8.0" MAX_JOBS=4 \
  uv pip install xformers --no-build-isolation

# Build for multiple architectures
TORCH_CUDA_ARCH_LIST="7.5;8.0;9.0" MAX_JOBS=4 \
  uv pip install xformers --no-build-isolation
```

**Build time**: 5–15 minutes depending on `MAX_JOBS` and target architectures. Much faster than Flash-Attention.

### Verifying xformers Installation

```bash
# Basic import check
python -c "import xformers; print(xformers.__version__)"

# Check available ops and GPU support
python -m xformers.info
```


---

## RAPIDS (cuDF, cuML)

### Overview

RAPIDS provides GPU-accelerated DataFrames (cuDF) and machine learning (cuML) that are API-compatible with pandas and scikit-learn. Requires CUDA 12.x and GPU compute capability ≥ 7.0 (Volta+).

### Installation Options

RAPIDS can be installed via pip (from NVIDIA's index) or conda. Both are officially supported.

#### Option 1: pip via NVIDIA Index (Recommended with uv)

```bash
uv pip install cudf-cu12 cuml-cu12 \
  --extra-index-url https://pypi.nvidia.com
```

**Package naming**: RAPIDS pip packages use the `-cu12` suffix. There are no `-cu11` pip packages — CUDA 11 users must use conda.

#### Option 2: conda / mamba

conda is the original RAPIDS install method and supports CUDA 11 and 12:

```bash
# CUDA 12 (recommended)
conda install -c rapidsai -c conda-forge -c nvidia \
  cudf=24.12 cuml=24.12 python=3.11 cuda-version=12.4

# CUDA 11 (only available via conda)
conda install -c rapidsai -c conda-forge -c nvidia \
  cudf=24.12 cuml=24.12 python=3.11 cuda-version=11.8
```

### pip vs conda Decision Guide

| Factor | pip (uv) | conda |
|--------|----------|-------|
| CUDA 12 support | ✅ | ✅ |
| CUDA 11 support | ❌ | ✅ |
| Speed of install | Fast (pre-built wheels) | Slower (solver + large packages) |
| Coexists with PyTorch (pip) | ✅ Natural | ⚠️ Can conflict |
| Isolated environments | uv venv | conda env |
| Recommended when | Using uv/pip for everything | Need CUDA 11 or full RAPIDS stack |

**Rule**: If your project already uses `uv` and CUDA 12, use the pip path. Only use conda if you need CUDA 11 support or encounter dependency conflicts with the pip packages.

### RAPIDS Version Compatibility

RAPIDS 24.06+ requires CUDA ≥ 12.0, Python 3.10–3.12, and GPU compute capability ≥ sm_70 (V100+). For CUDA 11.x, use conda.

### Verifying RAPIDS Installation

```bash
python -c "import cudf; print('cuDF', cudf.__version__)"
python -c "import cuml; print('cuML', cuml.__version__)"
```

---

## Common Errors and Fixes

### xformers: `No matching distribution found`

```
ERROR: No matching distribution found for xformers
```

**Fix**: No pre-built wheel for your PyTorch + CUDA combination. Check the wheel matrix above, then either:

```bash
# Option 1: Use the correct index URL for your CUDA version
uv pip install xformers --index-url https://download.pytorch.org/whl/cu124

# Option 2: Build from source
uv pip install xformers --no-build-isolation
```

### xformers: `RuntimeError: CUDA error: no kernel image`

```
RuntimeError: CUDA error: no kernel image is available for execution on the device
```

**Fix**: The installed xformers was built for a different GPU architecture. Rebuild for your GPU:

```bash
# Check your GPU's compute capability
python -c "import torch; print(torch.cuda.get_device_capability())"

# Rebuild targeting your architecture
TORCH_CUDA_ARCH_LIST="7.5" uv pip install xformers --no-build-isolation --force-reinstall
```

### xformers: Version mismatch with PyTorch

```
RuntimeError: Detected that PyTorch and xformers were compiled with different CUDA versions
```

**Fix**: Reinstall both from the same index:

```bash
uv pip install torch torchvision xformers \
  --index-url https://download.pytorch.org/whl/cu124 --force-reinstall
```

### RAPIDS: `ModuleNotFoundError: No module named 'cudf'`

**Fix**: Check you installed the correct package name:

```bash
# Correct package name for pip (note the -cu12 suffix)
uv pip install cudf-cu12 --extra-index-url https://pypi.nvidia.com

# NOT: uv pip install cudf  (this is a different/empty package)
```

### RAPIDS: `CUDA driver version is insufficient`

```
RuntimeError: CUDA driver version is insufficient for CUDA runtime version
```

**Fix**: Your NVIDIA driver is too old for the CUDA version RAPIDS was built against:

```bash
# Check driver version
nvidia-smi

# RAPIDS 24.x needs CUDA 12.x, which needs driver ≥ 525.60
# Upgrade driver: https://www.nvidia.com/drivers
```

### RAPIDS: `libcudf.so: cannot open shared object file`

**Fix**: Add CUDA runtime libraries to the library path:

```bash
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

### RAPIDS: Conflicts with PyTorch CUDA version

When RAPIDS and PyTorch disagree on CUDA version, ensure both target CUDA 12.x:

```bash
uv pip install torch --index-url https://download.pytorch.org/whl/cu124
uv pip install cudf-cu12 cuml-cu12 --extra-index-url https://pypi.nvidia.com
```

---

## pyproject.toml Patterns

### xformers as Optional Dependency

```toml
[project]
dependencies = [
    "torch>=2.4",
    "transformers>=4.40",
]

[project.optional-dependencies]
xformers = ["xformers>=0.0.27"]

[[tool.uv.index]]
name = "pytorch-cu124"
url = "https://download.pytorch.org/whl/cu124"
explicit = true

[tool.uv.sources]
torch = { index = "pytorch-cu124" }
xformers = { index = "pytorch-cu124" }
```

### RAPIDS alongside PyTorch

```toml
[project]
dependencies = [
    "torch>=2.4",
    "cudf-cu12>=24.06",
    "cuml-cu12>=24.06",
]

[[tool.uv.index]]
name = "pytorch-cu124"
url = "https://download.pytorch.org/whl/cu124"
explicit = true

[[tool.uv.index]]
name = "nvidia"
url = "https://pypi.nvidia.com"
explicit = true

[tool.uv.sources]
torch = { index = "pytorch-cu124" }
cudf-cu12 = { index = "nvidia" }
cuml-cu12 = { index = "nvidia" }
```

---

## Docker Patterns

```dockerfile
# xformers — install from same index as PyTorch
FROM nvcr.io/nvidia/pytorch:24.07-py3
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install xformers --index-url https://download.pytorch.org/whl/cu124 --system

# RAPIDS — use NVIDIA index
# RUN uv pip install cudf-cu12 cuml-cu12 --extra-index-url https://pypi.nvidia.com --system
```

> **See also**: [docker-gpu-setup](../../docker-gpu-setup/SKILL.md) for full multi-stage Dockerfile patterns

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for CUDA/cuDNN version conflict resolution