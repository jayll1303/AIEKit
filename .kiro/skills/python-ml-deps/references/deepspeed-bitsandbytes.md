# DeepSpeed & bitsandbytes

Installing DeepSpeed custom ops and bitsandbytes quantization with `uv`, including CUDA detection, build configuration, and fixes for common errors.

> **Last verified**: DeepSpeed 0.14.x–0.15.x, bitsandbytes 0.43.x–0.44.x with PyTorch 2.4–2.6

---

## DeepSpeed

### Install Modes

DeepSpeed has two install modes — pre-built (no custom ops) and source build (with custom ops):

```bash
# Mode 1: Pre-built — fast, no compiler needed, JIT-compiles ops at runtime
uv pip install deepspeed

# Mode 2: Build all ops ahead of time (requires CUDA toolkit + C++ compiler)
DS_BUILD_OPS=1 uv pip install deepspeed --no-build-isolation
```

**When to use Mode 2**: If you need custom ops (fused Adam, sparse attention, quantization kernels) and want to avoid JIT compilation overhead at runtime. Required in Docker images where you don't want runtime compilation.

### Build Environment Variables

Control which ops are compiled during install:

| Variable | Default | Description |
|---|---|---|
| `DS_BUILD_OPS` | `0` | Set to `1` to build all custom ops |
| `DS_BUILD_AIO` | `0` | Build async I/O op (requires `libaio-dev`) |
| `DS_BUILD_CPU_ADAM` | `0` | Build CPU Adam optimizer |
| `DS_BUILD_FUSED_ADAM` | `0` | Build fused CUDA Adam optimizer |
| `DS_BUILD_FUSED_LAMB` | `0` | Build fused CUDA LAMB optimizer |
| `DS_BUILD_QUANTIZATION` | `0` | Build quantization kernels |
| `DS_BUILD_SPARSE_ATTN` | `0` | Build sparse attention (requires Triton) |
| `DS_BUILD_TRANSFORMER_INFERENCE` | `0` | Build inference-optimized transformer |

Other ops: `DS_BUILD_CCL_COMM`, `DS_BUILD_CPU_ADAGRAD`, `DS_BUILD_CPU_LION`, `DS_BUILD_FUSED_LION`, `DS_BUILD_TRANSFORMER`, `DS_BUILD_STOCHASTIC_TRANSFORMER` — all default `0`, same pattern.

```bash
# Build only the ops you need (faster than DS_BUILD_OPS=1)
DS_BUILD_FUSED_ADAM=1 DS_BUILD_QUANTIZATION=1 \
  uv pip install deepspeed --no-build-isolation
```

### Prerequisites for Building Ops

```bash
# 1. CUDA toolkit on PATH
nvcc --version

# 2. C++ compiler
gcc --version    # Linux

# 3. For async I/O op
sudo apt install libaio-dev    # Ubuntu/Debian
sudo dnf install libaio-devel  # RHEL/Fedora

# 4. PyTorch already installed with matching CUDA
python -c "import torch; print(torch.__version__, torch.version.cuda)"
```

### GPU Architecture Targeting

```bash
# Build for specific GPU architecture (faster compilation)
TORCH_CUDA_ARCH_LIST="8.0" DS_BUILD_OPS=1 \
  uv pip install deepspeed --no-build-isolation

# Multiple architectures (e.g., A100 + H100)
TORCH_CUDA_ARCH_LIST="8.0;9.0" DS_BUILD_OPS=1 \
  uv pip install deepspeed --no-build-isolation
```

### Verifying DeepSpeed Installation

```bash
# Check install and which ops are available
ds_report
```

`ds_report` prints a table showing each op's status: installed (pre-built), compatible (can JIT-compile), or not compatible.

---

## bitsandbytes

### Install

bitsandbytes ships pre-built wheels with CUDA auto-detection — no source build needed in most cases:

```bash
# Standard install — auto-detects CUDA version
uv pip install bitsandbytes
```

Starting with bitsandbytes ≥ 0.43, the package includes multi-CUDA support in a single wheel. It detects your CUDA version at runtime and loads the matching compiled library.

### CUDA Auto-Detection

bitsandbytes finds CUDA in this order:

1. `CUDA_HOME` / `CUDA_PATH` environment variable
2. `nvcc` on `PATH`
3. PyTorch's bundled CUDA (`torch.version.cuda`)
4. Common paths: `/usr/local/cuda`, `/usr/local/cuda-XX.Y`

```bash
# Check what bitsandbytes detects
python -m bitsandbytes
```

### Manual CUDA Override

If auto-detection picks the wrong CUDA version:

```bash
# Force a specific CUDA path
export CUDA_HOME=/usr/local/cuda-12.4
export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH
uv pip install bitsandbytes --force-reinstall

# Or set the library path directly for runtime
export BNB_CUDA_VERSION=124
```

### Verifying bitsandbytes Installation

```bash
python -c "import bitsandbytes as bnb; print('bitsandbytes', bnb.__version__)"
python -m bitsandbytes   # Full diagnostic output
```

---

## Common Errors and Fixes

### DeepSpeed: `nvcc fatal: Unsupported gpu architecture`

```
nvcc fatal: Unsupported gpu architecture 'compute_XX'
```

**Fix**: Your CUDA toolkit doesn't support the target GPU architecture. Either upgrade CUDA or set the arch explicitly:

```bash
# Target only your GPU
TORCH_CUDA_ARCH_LIST="8.0" DS_BUILD_OPS=1 \
  uv pip install deepspeed --no-build-isolation
```

### DeepSpeed: `No module named 'torch'` during build

```
ModuleNotFoundError: No module named 'torch'
```

**Fix**: PyTorch must be installed before building DeepSpeed ops. Use `--no-build-isolation`:

```bash
# Ensure PyTorch is installed first
uv pip install torch --index-url https://download.pytorch.org/whl/cu124

# Then install DeepSpeed
DS_BUILD_OPS=1 uv pip install deepspeed --no-build-isolation
```

### DeepSpeed: `libaio.h: No such file or directory`

```
fatal error: libaio.h: No such file or directory
```

**Fix**: The async I/O op needs `libaio-dev`. Either install it or skip the AIO op:

```bash
# Option 1: Install the dependency
sudo apt install libaio-dev    # Ubuntu/Debian
sudo dnf install libaio-devel  # RHEL/Fedora

# Option 2: Build without AIO
DS_BUILD_OPS=1 DS_BUILD_AIO=0 uv pip install deepspeed --no-build-isolation
```

### DeepSpeed: `fused_adam` not found at runtime

**Fix**: The fused Adam op wasn't pre-built. Pre-build it or use the fallback:

```bash
DS_BUILD_FUSED_ADAM=1 uv pip install deepspeed --no-build-isolation --force-reinstall
```

Or switch to non-fused Adam in your DeepSpeed config: `"type": "Adam"` instead of `"FusedAdam"`.

### bitsandbytes: `CUDA Setup failed` / `libcudart.so not found`

```
CUDA Setup failed despite GPU being available. Please run the following command to get more information:
```

**Fix**: bitsandbytes can't find the CUDA runtime library:

```bash
# Point to the correct CUDA installation
export CUDA_HOME=/usr/local/cuda
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# Verify the library exists
ls $CUDA_HOME/lib64/libcudart.so*

# If using conda/mamba, the CUDA runtime may be in the env
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH
```

### bitsandbytes: `CUDA version mismatch` / `no kernel image`

```
RuntimeError: CUDA error: no kernel image is available for execution on the device
```

**Fix**: Force the correct CUDA version:

```bash
python -m bitsandbytes                    # Check what was detected
export BNB_CUDA_VERSION=124               # Force correct version
export CUDA_HOME=/usr/local/cuda-12.4     # Or set CUDA_HOME
uv pip install bitsandbytes --force-reinstall
```

### bitsandbytes: `AttributeError` on older versions

**Fix**: Upgrade to ≥ 0.43 — older versions have a different API:

```bash
uv pip install "bitsandbytes>=0.43" --force-reinstall
```

---

## pyproject.toml Patterns

### DeepSpeed as Optional Dependency

```toml
[project]
dependencies = [
    "torch>=2.4",
    "transformers>=4.40",
    "accelerate>=0.30",
]

[project.optional-dependencies]
deepspeed = ["deepspeed>=0.14"]

# Install with: uv pip install -e ".[deepspeed]"
# Build ops with: DS_BUILD_OPS=1 uv pip install -e ".[deepspeed]" --no-build-isolation
```

### bitsandbytes for Quantization

```toml
[project]
dependencies = [
    "torch>=2.4",
    "transformers>=4.40",
    "bitsandbytes>=0.43",
]

[project.optional-dependencies]
quantization = [
    "bitsandbytes>=0.43",
    "accelerate>=0.30",
    "auto-gptq>=0.7",
]
```

---

## Docker Patterns

```dockerfile
# DeepSpeed with pre-built ops
FROM nvcr.io/nvidia/pytorch:24.07-py3
RUN apt-get update && apt-get install -y libaio-dev && rm -rf /var/lib/apt/lists/*
RUN --mount=type=cache,target=/root/.cache/uv \
    DS_BUILD_OPS=1 TORCH_CUDA_ARCH_LIST="8.0;9.0" \
    uv pip install deepspeed --no-build-isolation --system
```

```dockerfile
# bitsandbytes — auto-detects CUDA from NGC base image
FROM nvcr.io/nvidia/pytorch:24.07-py3
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install bitsandbytes --system
```

> **See also**: [docker-gpu-setup](../../docker-gpu-setup/SKILL.md) for full multi-stage Dockerfile patterns

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for CUDA/cuDNN version conflict resolution