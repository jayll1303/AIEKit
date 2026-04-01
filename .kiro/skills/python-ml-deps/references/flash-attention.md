# Flash-Attention Build Guide

Building Flash-Attention from source with `uv`, including CUDA toolkit requirements, build flags, and fixes for common compilation errors.

> **Last verified**: Flash-Attention v2.6.x / v2.7.x with PyTorch 2.4–2.6

## Prerequisites

Before attempting to install Flash-Attention, verify all of these:

```bash
# 1. CUDA toolkit installed and on PATH
nvcc --version          # Needs CUDA ≥ 11.6 (≥ 12.x recommended)

# 2. PyTorch already installed with matching CUDA version
python -c "import torch; print(torch.__version__, torch.version.cuda)"

# 3. C++ compiler available
gcc --version           # Linux: needs gcc/g++
# or
cl                      # Windows: needs MSVC (Visual Studio Build Tools)

# 4. Python headers installed
python -c "import sysconfig; print(sysconfig.get_path('include'))"
# If missing on Linux: sudo apt install python3-dev

# 5. Sufficient disk space (~8 GB for build artifacts)
df -h /tmp
```

### CUDA Toolkit Compatibility

| Flash-Attention | Min CUDA | Recommended CUDA | Notes |
|-----------------|----------|------------------|-------|
| v2.7.x          | 11.8     | 12.4+            | Best performance on Hopper (sm_90) |
| v2.6.x          | 11.6     | 12.1+            | Stable, widely tested |
| v2.5.x          | 11.6     | 12.1+            | Last version before API changes |

### Supported GPU Architectures

Flash-Attention requires Ampere (sm_80) or newer:

| Architecture | Compute Capability | GPUs | Supported |
|---|---|---|---|
| Turing | sm_75 | RTX 2080, T4 | ❌ (v2 dropped support) |
| Ampere | sm_80 | A100, A30 | ✅ |
| Ampere | sm_86 | RTX 3090, A40 | ✅ |
| Ada Lovelace | sm_89 | RTX 4090, L40 | ✅ |
| Hopper | sm_90 | H100, H200 | ✅ |

---

## Basic Install

```bash
# Standard install (builds from source)
MAX_JOBS=4 uv pip install flash-attn --no-build-isolation
```

**Why `--no-build-isolation`?** Flash-Attention's build needs access to the already-installed PyTorch and CUDA headers. Build isolation creates a clean venv that can't see them.

---

## Build Environment Variables

Control the build process with these environment variables:

### Core Build Flags

| Variable | Default | Description |
|---|---|---|
| `MAX_JOBS` | nproc | Number of parallel compilation jobs. Lower this if you run out of RAM. |
| `FLASH_ATTENTION_FORCE_BUILD` | `FALSE` | Set to `TRUE` to force building from source even if a wheel exists. |
| `FLASH_ATTENTION_SKIP_CUDA_BUILD` | `FALSE` | Set to `TRUE` to skip CUDA kernel compilation (Python-only install). |
| `FLASH_ATTENTION_FORCE_CXX11_ABI` | (auto) | Force C++11 ABI. Set to `TRUE` if you get ABI mismatch errors with PyTorch. |

### GPU Architecture Targeting

| Variable | Default | Description |
|---|---|---|
| `TORCH_CUDA_ARCH_LIST` | (auto-detected) | Semicolon-separated list of target architectures. |

```bash
# Build only for your specific GPU (faster compilation)
TORCH_CUDA_ARCH_LIST="8.0" MAX_JOBS=4 uv pip install flash-attn --no-build-isolation

# Build for multiple architectures (e.g., A100 + H100)
TORCH_CUDA_ARCH_LIST="8.0;9.0" MAX_JOBS=4 uv pip install flash-attn --no-build-isolation

# Build for all supported architectures (slowest, but portable)
TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0" MAX_JOBS=4 uv pip install flash-attn --no-build-isolation
```

**Rule of thumb**: Each compilation job uses ~2–4 GB RAM. Set `MAX_JOBS` to `total_RAM_GB / 4`.

---

## Common Errors and Fixes

### Error: `nvcc not found` / `CUDA_HOME not set`

```
RuntimeError: The current installed version of nvcc is not supported.
```

**Fix**: Ensure CUDA toolkit is installed and on PATH:

```bash
# Check if nvcc is available
which nvcc

# If not found, add CUDA to PATH
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Or set CUDA_HOME explicitly
export CUDA_HOME=/usr/local/cuda

# For multiple CUDA versions, point to the correct one
export CUDA_HOME=/usr/local/cuda-12.4
```

### Error: `No matching distribution found`

```
ERROR: No matching distribution found for flash-attn
```

**Fix**: Flash-Attention rarely has pre-built wheels. Build from source:

```bash
# Force source build
FLASH_ATTENTION_FORCE_BUILD=TRUE uv pip install flash-attn --no-build-isolation
```

### Error: `gcc/g++ not found` or compiler version mismatch

```
error: command 'gcc' failed: No such file or directory
```

**Fix**:

```bash
# Install build tools (Ubuntu/Debian)
sudo apt install build-essential

# Install build tools (RHEL/CentOS/Fedora)
sudo dnf groupinstall "Development Tools"
```

For CUDA 11.x, you may need an older gcc:

```bash
# CUDA 11.x supports gcc ≤ 11 (gcc 12+ may fail)
sudo apt install gcc-11 g++-11
export CC=gcc-11
export CXX=g++-11
MAX_JOBS=4 uv pip install flash-attn --no-build-isolation
```

### Error: `No space left on device`

```
OSError: [Errno 28] No space left on device
```

**Fix**: The build generates ~8 GB of temporary files:

```bash
# Point temp directory to a partition with more space
export TMPDIR=/path/with/space/tmp
mkdir -p $TMPDIR

# Clean caches first
uv cache clean
pip cache purge

# Then retry
MAX_JOBS=4 uv pip install flash-attn --no-build-isolation
```

### Error: `undefined symbol` / ABI mismatch

```
ImportError: undefined symbol: _ZN2at...
```

**Fix**: C++ ABI mismatch between Flash-Attention and PyTorch:

```bash
# Check PyTorch's ABI setting
python -c "import torch; print(torch._C._GLIBCXX_USE_CXX11_ABI)"

# Force matching ABI during build
FLASH_ATTENTION_FORCE_CXX11_ABI=TRUE MAX_JOBS=4 \
  uv pip install flash-attn --no-build-isolation --force-reinstall
```

### Error: `unsupported gpu architecture 'compute_XX'`

```
nvcc fatal: Unsupported gpu architecture 'compute_75'
```

**Fix**: Flash-Attention v2 requires Ampere (sm_80) or newer. Turing GPUs (sm_75) are not supported.

```bash
# Explicitly set architecture to avoid auto-detecting unsupported GPUs
TORCH_CUDA_ARCH_LIST="8.0" MAX_JOBS=4 uv pip install flash-attn --no-build-isolation
```

If you have a Turing GPU, use `xformers` instead — it supports sm_75.

### Error: Build killed (OOM)

```
g++: fatal error: Killed signal terminated program cc1plus
```

**Fix**: Reduce parallel jobs (`MAX_JOBS=1`) or add temporary swap space. Each job uses ~2–4 GB RAM.

### Error: `ninja: build stopped: subcommand failed`

```
ninja: build stopped: subcommand failed.
```

**Fix**: This is a generic wrapper error. Scroll up in the build log to find the real error. Common causes:

1. **OOM** → reduce `MAX_JOBS`
2. **CUDA version mismatch** → verify `nvcc --version` matches PyTorch's CUDA
3. **Missing headers** → install `python3-dev` and ensure CUDA headers are present

```bash
# Verbose build to see the actual error
MAX_JOBS=2 uv pip install flash-attn --no-build-isolation -v 2>&1 | tee build.log
grep -i "error" build.log
```

---

## Verifying the Installation

```bash
# Basic import check
python -c "import flash_attn; print(flash_attn.__version__)"

# Verify CUDA kernel is loaded
python -c "
from flash_attn import flash_attn_func
import torch

# Quick smoke test on GPU
q = torch.randn(1, 8, 128, 64, device='cuda', dtype=torch.float16)
k = torch.randn(1, 8, 128, 64, device='cuda', dtype=torch.float16)
v = torch.randn(1, 8, 128, 64, device='cuda', dtype=torch.float16)
out = flash_attn_func(q, k, v)
print(f'Flash-Attention working. Output shape: {out.shape}')
"
```

---

## Docker Build Pattern

Flash-Attention inside Docker — put the install in an early layer to cache the long build:

```dockerfile
FROM nvcr.io/nvidia/pytorch:24.07-py3

RUN --mount=type=cache,target=/root/.cache/uv \
    MAX_JOBS=4 TORCH_CUDA_ARCH_LIST="8.0;9.0" \
    uv pip install flash-attn --no-build-isolation --system

COPY . /app
```

> **See also**: [docker-gpu-setup](../../docker-gpu-setup/SKILL.md) for full multi-stage Dockerfile patterns

---

## Alternatives When Flash-Attention Won't Build

If you can't get Flash-Attention to compile, these alternatives provide similar functionality:

| Alternative | GPU Support | Install |
|---|---|---|
| PyTorch SDPA | Turing+ (sm_75) | Built into `torch>=2.0` — no install needed |
| xformers | Turing+ (sm_75) | `uv pip install xformers --index-url https://download.pytorch.org/whl/cu124` |
| FlashAttention via SDPA | Ampere+ (sm_80) | `torch.nn.functional.scaled_dot_product_attention` auto-selects Flash backend |

```python
# PyTorch's SDPA automatically uses Flash-Attention backend when available
import torch.nn.functional as F

out = F.scaled_dot_product_attention(query, key, value)
# Uses flash_attention backend on Ampere+, efficient_attention on Turing
```
