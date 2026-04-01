# llama-cpp-python

Building and installing `llama-cpp-python` with GPU acceleration (CUDA, Metal, ROCm) using `uv`, including CMAKE_ARGS configuration, pre-built wheel index URLs, and fixes for common build errors.

> **Last verified**: llama-cpp-python 0.2.x–0.3.x with llama.cpp (GGML backend)

---

## Overview

`llama-cpp-python` is a Python binding for [llama.cpp](https://github.com/ggerganov/llama.cpp), providing high-performance inference for GGUF models. It uses CMake to build the native C++ backend, and the `CMAKE_ARGS` environment variable controls which GPU backend is compiled.

Key decision: **pre-built wheels** (fast, no compiler needed) vs **source build** (full control over backend and flags).

---

## Backend Selection

| Backend | Platform | CMAKE_ARGS | Notes |
|---|---|---|---|
| CUDA | Linux, Windows | `-DGGML_CUDA=on` | Requires CUDA toolkit ≥ 11.7 |
| Metal | macOS (Apple Silicon) | `-DGGML_METAL=on` | Built-in on macOS, no extra deps |
| ROCm | Linux (AMD GPUs) | `-DGGML_HIPBLAS=on` | Requires ROCm ≥ 5.6 |
| Vulkan | Linux, Windows, macOS | `-DGGML_VULKAN=on` | Cross-platform, requires Vulkan SDK |
| OpenBLAS (CPU) | All | `-DGGML_BLAS=on -DGGML_BLAS_VENDOR=OpenBLAS` | CPU-only, needs `libopenblas-dev` |
| CPU (default) | All | *(none)* | No acceleration, pure CPU |

---

## Source Build Instructions

### CUDA Backend (NVIDIA GPUs)

```bash
# Prerequisites: CUDA toolkit on PATH, C++ compiler
nvcc --version   # Verify CUDA toolkit is installed

# Install with CUDA support
CMAKE_ARGS="-DGGML_CUDA=on" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

#### Targeting Specific GPU Architectures

Restricting the target architecture speeds up compilation significantly:

```bash
# Single architecture (e.g., A100 = sm_80)
CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=80" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall

# Multiple architectures (e.g., A100 + H100)
CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=80;90" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

Common architecture codes: T4=`75`, A10/A40/RTX 3090=`86`, A100=`80`, L4/L40/RTX 4090=`89`, H100=`90`

### Metal Backend (macOS Apple Silicon)

```bash
# Metal is the default GPU backend on macOS — just enable it
CMAKE_ARGS="-DGGML_METAL=on" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

Metal requires no additional dependencies on macOS. The Xcode Command Line Tools provide the necessary compiler.

```bash
# Verify Xcode CLI tools are installed
xcode-select --install   # Install if missing
```

### ROCm Backend (AMD GPUs)

```bash
# Prerequisites: ROCm toolkit installed
rocminfo   # Verify ROCm is working

# Install with ROCm/HIP support
CMAKE_ARGS="-DGGML_HIPBLAS=on" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

#### Targeting Specific AMD GPU Architectures

```bash
# Target a specific AMD GPU (e.g., MI250 = gfx90a, MI300X = gfx942)
CMAKE_ARGS="-DGGML_HIPBLAS=on -DAMDGPU_TARGETS=gfx90a" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

---

## Pre-Built Wheels

Pre-built wheels skip the compilation step entirely. Use the `--extra-index-url` flag to pull from the llama-cpp-python wheel index.

### CUDA Wheels

```bash
# CUDA 12.1
uv pip install llama-cpp-python \
  --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu121

# CUDA 12.2
uv pip install llama-cpp-python \
  --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu122

# CUDA 12.4
uv pip install llama-cpp-python \
  --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124
```

### Other Backends

```bash
# Metal (macOS)
uv pip install llama-cpp-python \
  --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/metal

# CPU-only (default PyPI wheel)
uv pip install llama-cpp-python
```

### Wheel Index URL Pattern

```
https://abetlen.github.io/llama-cpp-python/whl/<backend>
```

Available backends: `cu121`, `cu122`, `cu123`, `cu124`, `metal`, `cpu`

> **Note**: Pre-built wheels may lag behind the latest llama.cpp release. Build from source if you need the newest features.

---

## pyproject.toml Patterns

### Basic llama-cpp-python with CUDA Wheels

```toml
[project]
name = "my-llm-project"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "llama-cpp-python>=0.2.80",
]

[[tool.uv.index]]
name = "llama-cpp-cu124"
url = "https://abetlen.github.io/llama-cpp-python/whl/cu124"
explicit = true

[tool.uv.sources]
llama-cpp-python = { index = "llama-cpp-cu124" }
```

### With OpenAI-Compatible Server

Add the `[server]` extra for the built-in OpenAI-compatible API server (`uvicorn`, `fastapi`):

```toml
[project]
dependencies = [
    "llama-cpp-python[server]>=0.2.80",
]

[[tool.uv.index]]
name = "llama-cpp-cu124"
url = "https://abetlen.github.io/llama-cpp-python/whl/cu124"
explicit = true

[tool.uv.sources]
llama-cpp-python = { index = "llama-cpp-cu124" }
```

---

## Advanced Build Flags

| Flag | Description |
|---|---|
| `-DGGML_CUDA=on` | Enable CUDA backend |
| `-DGGML_METAL=on` | Enable Metal backend |
| `-DGGML_HIPBLAS=on` | Enable ROCm/HIP backend |
| `-DGGML_VULKAN=on` | Enable Vulkan backend |
| `-DCMAKE_CUDA_ARCHITECTURES=XX` | Target specific NVIDIA GPU arch |
| `-DAMDGPU_TARGETS=gfxXXX` | Target specific AMD GPU arch |
| `-DGGML_CUDA_F16=on` | Enable CUDA FP16 (faster on Ampere+) |
| `-DLLAMA_CURL=on` | Enable downloading models via URL |

```bash
# Combine multiple flags
CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=89 -DGGML_CUDA_F16=on" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

---

## Common Errors and Fixes

### `CMake Error: CMAKE_CUDA_COMPILER not set`

**Fix**: CUDA toolkit not on PATH:

```bash
nvcc --version   # Verify installed
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
CMAKE_ARGS="-DGGML_CUDA=on" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

### `No matching distribution found`

**Fix**: No pre-built wheel for your Python version or platform — build from source instead:

```bash
CMAKE_ARGS="-DGGML_CUDA=on" \
  uv pip install llama-cpp-python --no-build-isolation
```

### Compiler errors during build

**Fix**: Missing C++ compiler or CMake:

```bash
sudo apt install build-essential cmake    # Ubuntu/Debian
sudo dnf install gcc-c++ cmake            # RHEL/Fedora
# Needs CMake ≥ 3.21
```

### `CUDA error: no kernel image is available`

**Fix**: Rebuild targeting your GPU's compute capability:

```bash
python -c "import torch; print(torch.cuda.get_device_capability())"
# Rebuild (e.g., RTX 4090 = 89)
CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=89" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

### Metal: `unable to find utility "metal"`

**Fix**: Install or reset Xcode Command Line Tools:

```bash
xcode-select --install
# If broken: sudo xcode-select --reset
```

### ROCm: `hipErrorNoBinaryForGpu`

**Fix**: Rebuild targeting your AMD GPU architecture:

```bash
rocminfo | grep "Name:"
# Rebuild (e.g., MI300X = gfx942)
CMAKE_ARGS="-DGGML_HIPBLAS=on -DAMDGPU_TARGETS=gfx942" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

### Build hangs or OOM

**Fix**: Limit parallel jobs:

```bash
CMAKE_BUILD_PARALLEL_LEVEL=4 CMAKE_ARGS="-DGGML_CUDA=on" \
  uv pip install llama-cpp-python --no-build-isolation --force-reinstall
```

---

## Docker Pattern

```dockerfile
# Source build with CUDA in Docker
FROM nvcr.io/nvidia/cuda:12.4.1-devel-ubuntu22.04
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
RUN --mount=type=cache,target=/root/.cache/uv \
    CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=80;89;90" \
    uv pip install llama-cpp-python --no-build-isolation --system

# Pre-built wheel (faster, no compiler needed)
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install llama-cpp-python \
      --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124 \
      --system
```

> **See also**: [docker-gpu-setup](../../docker-gpu-setup/SKILL.md) for full multi-stage Dockerfile patterns

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for CUDA/cuDNN version conflict resolution
