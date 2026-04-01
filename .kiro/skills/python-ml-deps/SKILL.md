---
name: python-ml-deps
description: "Install ML/AI Python deps with uv, resolve NVIDIA version conflicts. Use when installing PyTorch with CUDA index URLs, building Flash-Attention from source, resolving CUDA/cuDNN/driver version conflicts, installing bitsandbytes, or configuring pyproject.toml with CUDA-specific extras."
---

# Python ML Dependencies

Install ML libraries (PyTorch, Flash-Attention, DeepSpeed, bitsandbytes, xformers, RAPIDS, llama-cpp-python) with uv while avoiding CUDA version hell.

## Scope

This skill handles:
- Installing ML/AI Python packages with `uv pip install` and CUDA-aware index URLs
- Resolving CUDA/cuDNN/driver version conflicts across the NVIDIA deep learning stack
- Configuring `pyproject.toml` with CUDA-specific extras and uv index sources
- Diagnosing ML dependency install failures (compiler errors, missing wheels, GPU not detected)
- NVIDIA version resolution: compatibility matrices, driver ↔ CUDA, ORT ↔ CUDA

Does NOT handle:
- Project scaffolding, ruff/pytest config, pre-commit hooks (→ python-project-setup)
- Type annotations, property-based testing, mutation testing (→ python-quality-testing)
- Fine-tuning models with Trainer/TRL/PEFT (→ hf-transformers-trainer)
- Building GPU Docker containers (→ docker-gpu-setup)

## When to Use

- Installing PyTorch and need the correct CUDA index URL for your GPU
- Building Flash-Attention from source and hitting compilation errors
- CUDA version conflicts between packages (e.g., PyTorch wants CUDA 12.4 but system has 11.8)
- Installing bitsandbytes and getting "CUDA not detected" errors
- Compiling DeepSpeed custom ops and missing build dependencies
- Installing xformers (wheels vs source build)
- Setting up RAPIDS (cuDF, cuML) alongside PyTorch
- Building llama-cpp-python with CUDA/Metal/ROCm backend
- Pinning ML dependencies in pyproject.toml with CUDA-aware extras
- "CUDAExecutionProvider is not available" errors
- cuDNN version mismatch between PyTorch and ONNX Runtime
- CUDA driver version insufficient for container
- TensorRT engine won't load (version mismatch)

## CUDA → PyTorch Index Decision Table

Determine your CUDA version first, then use the matching index URL:

```bash
nvidia-smi          # Shows driver CUDA version (upper bound)
nvcc --version      # Shows toolkit CUDA version (what matters for builds)
```

| CUDA Version | PyTorch Index URL | Notes |
|---|---|---|
| 11.8 | `https://download.pytorch.org/whl/cu118` | Last CUDA 11.x supported by PyTorch 2.x |
| 12.1 | `https://download.pytorch.org/whl/cu121` | Widely supported, safe default for CUDA 12 |
| 12.4 | `https://download.pytorch.org/whl/cu124` | PyTorch ≥ 2.4 |
| 12.6 | `https://download.pytorch.org/whl/cu126` | PyTorch ≥ 2.6 |
| CPU only | `https://download.pytorch.org/whl/cpu` | No GPU required |

**Rule**: Match the index URL to your *toolkit* CUDA version (`nvcc --version`), not the driver version from `nvidia-smi`. The driver version is an upper bound — your toolkit can be equal or lower.

## Quick Install Commands

All commands use `uv pip install`. Set the index URL once or pass it per command.

⚠️ **HARD GATE:** Do NOT install PyTorch or any CUDA-dependent package before verifying CUDA toolkit version with `nvcc --version` and matching it to the decision table above.

### 1. PyTorch (with CUDA 12.4)

```bash
uv pip install torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu124
```

**Validate:** Run `python3 -c "import torch; print(torch.cuda.is_available(), torch.version.cuda)"` — must print `True` and matching CUDA version. If not → check you used the correct index URL for your `nvcc --version` output.

### 2. Flash-Attention

```bash
# Requires: CUDA toolkit ≥ 11.6, gcc/g++ installed, PyTorch already installed
MAX_JOBS=4 uv pip install flash-attn --no-build-isolation
```

> Build takes 10-30 min. See [Flash-Attention reference](references/flash-attention.md) for build flags and troubleshooting.

**Validate:** Run `python3 -c "from flash_attn import flash_attn_func; print('OK')"` — must print `OK`. If not → check gcc version (needs ≤12 for CUDA 11.x) and that PyTorch is installed first.

### 3. bitsandbytes

```bash
# Pre-built wheels auto-detect CUDA — just install
uv pip install bitsandbytes
```

### 4. DeepSpeed

```bash
# Pre-built (no custom ops)
uv pip install deepspeed

# With custom ops (requires CUDA toolkit + compiler)
DS_BUILD_OPS=1 uv pip install deepspeed --no-build-isolation
```

### 5. xformers

```bash
# Pre-built wheel (must match PyTorch + CUDA version)
uv pip install xformers --index-url https://download.pytorch.org/whl/cu124

# From source (when no matching wheel exists)
uv pip install xformers --no-build-isolation
```

### 6. RAPIDS (cuDF, cuML)

```bash
# RAPIDS uses its own index — CUDA 12.x only
uv pip install cudf-cu12 cuml-cu12 \
  --extra-index-url https://pypi.nvidia.com
```

### 7. llama-cpp-python

```bash
# CUDA backend
CMAKE_ARGS="-DGGML_CUDA=on" uv pip install llama-cpp-python --no-build-isolation

# Metal backend (macOS)
CMAKE_ARGS="-DGGML_METAL=on" uv pip install llama-cpp-python --no-build-isolation

# Pre-built CUDA wheels (alternative)
uv pip install llama-cpp-python \
  --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124
```

**Validate:** Run `python3 -c "from llama_cpp import Llama; print('OK')"` — must print `OK`. If not → verify CMAKE_ARGS matched your target backend and CUDA toolkit is on PATH.

## pyproject.toml Snippets

Pin ML deps with CUDA-specific extras using uv's index configuration.

### Basic ML project with PyTorch CUDA 12.4

```toml
[project]
name = "my-ml-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "torch>=2.4",
    "torchvision>=0.19",
    "torchaudio>=2.4",
]

[[tool.uv.index]]
name = "pytorch-cu124"
url = "https://download.pytorch.org/whl/cu124"
explicit = true

[tool.uv.sources]
torch = { index = "pytorch-cu124" }
torchvision = { index = "pytorch-cu124" }
torchaudio = { index = "pytorch-cu124" }
```

### With Flash-Attention and bitsandbytes

```toml
[project]
dependencies = [
    "torch>=2.4",
    "flash-attn>=2.6",
    "bitsandbytes>=0.43",
    "transformers>=4.40",
    "accelerate>=0.30",
]

[project.optional-dependencies]
deepspeed = ["deepspeed>=0.14"]
xformers = ["xformers>=0.0.27"]

[[tool.uv.index]]
name = "pytorch-cu124"
url = "https://download.pytorch.org/whl/cu124"
explicit = true

[tool.uv.sources]
torch = { index = "pytorch-cu124" }
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

## Diagnostic Flowchart

When an ML dependency install fails, walk through this:

```
Install failed?
├─ "CUDA not found" / "nvcc not found"
│   ├─ Is CUDA toolkit installed?  → Install: https://developer.nvidia.com/cuda-downloads
│   ├─ Is nvcc on PATH?           → export PATH=/usr/local/cuda/bin:$PATH
│   └─ Wrong CUDA version?        → Check table above, install matching toolkit
│
├─ "gcc/g++ not found" / compiler error
│   ├─ Linux: sudo apt install build-essential
│   ├─ Is gcc version compatible? → Flash-Attention needs gcc ≤ 12 for CUDA 11.x
│   └─ Missing Python headers?    → sudo apt install python3-dev
│
├─ "No space left on device"
│   ├─ Flash-Attention build needs ~8 GB temp space
│   ├─ Set TMPDIR to a larger partition: export TMPDIR=/path/with/space
│   └─ Clean pip/uv cache: uv cache clean
│
├─ "No matching distribution" / wheel not found
│   ├─ Check Python version matches available wheels
│   ├─ Check platform (linux x86_64 vs aarch64)
│   ├─ Try --no-build-isolation for source builds
│   └─ Check if package supports your CUDA version
│
├─ Architecture mismatch (aarch64 / ARM)
│   ├─ Most ML wheels are x86_64 only
│   ├─ Flash-Attention: must build from source on ARM
│   ├─ bitsandbytes: limited ARM support
│   └─ llama-cpp-python: use CMAKE_ARGS for target arch
│
└─ Import works but GPU not detected
    ├─ torch.cuda.is_available() returns False?
    │   ├─ Installed CPU-only PyTorch by mistake → reinstall with CUDA index
    │   └─ Driver too old → nvidia-smi, check driver ≥ minimum for your CUDA
    └─ NVIDIA stack version conflict?
        ├─ ONNX RT + CUDA          → See references/onnxruntime-cuda.md
        ├─ PyTorch + ONNX RT cuDNN → cuDNN major version must match
        ├─ Triton container select  → See references/triton-containers.md
        ├─ Driver too old           → See references/driver-cuda.md
        └─ TensorRT engine fail     → Engine must be rebuilt with matching TRT version
```

## NVIDIA Version Resolution

Core rules for resolving conflicts across the NVIDIA deep learning stack (CUDA, cuDNN, PyTorch, ONNX Runtime, TensorRT, Triton, GPU drivers).

### Core Rules

1. **CUDA minor version compatibility**: ORT built with CUDA 11.8 works with any CUDA 11.x; ORT built with CUDA 12.x works with any CUDA 12.x
2. **cuDNN major version is a hard boundary**: cuDNN 8.x and 9.x are NOT interchangeable. PyTorch and ONNX RT must use the same cuDNN major
3. **PyTorch >= 2.4 uses cuDNN 9.x** → needs ONNX RT >= 1.18.1. PyTorch <= 2.3 uses cuDNN 8.x → needs ONNX RT with cuDNN 8.x build
4. **TensorRT engines are NOT portable** across TRT major versions or GPU architectures
5. **Data center GPUs** (T4, A100, H100) support forward driver compatibility — older drivers can run newer CUDA via compat package
6. **NGC containers are the safest path** — all deps pre-tested together

### Resolution Steps

⚠️ **HARD GATE:** Do NOT attempt to fix version conflicts before completing Step 1 (inventory all current versions). Blind upgrades create cascading mismatches.

**Step 1: Inventory current versions**
```bash
nvidia-smi                          # Driver + CUDA version
python3 -c "import torch; print(torch.__version__, torch.version.cuda, torch.backends.cudnn.version())"
python3 -c "import onnxruntime; print(onnxruntime.__version__, onnxruntime.get_device())"
```

**Validate:** All three commands must succeed and print version numbers. If any fails → the package is not installed or not importable; install it first before diagnosing conflicts.

**Step 2: Identify the conflict**
Cross-reference versions against [Compatibility Matrix](references/compatibility-matrix.md).

**Step 3: Fix**
- If inside NGC container: versions are pre-matched, check config not code
- If custom env: align cuDNN major first, then CUDA major, then specific package versions
- If driver issue on data center GPU: check forward compat in [Driver ↔ CUDA](references/driver-cuda.md)

**Validate:** Re-run Step 1 commands after fix — all versions must align per the compatibility matrix. If not → repeat Step 2 with updated version output.

### Common Fix Patterns

- **ONNX RT can't find CUDA**: `pip install onnxruntime-gpu` (not `onnxruntime`). If PyTorch installed, `import torch` before creating ORT session.
- **cuDNN mismatch**: Check PyTorch cuDNN version, match ONNX RT build.
- **Container driver mismatch**: Use `--gpus all` with Docker. For old drivers on data center GPUs, forward compat usually works.

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "CUDA version doesn't matter, just install the latest PyTorch" | PyTorch index URL MUST match `nvcc --version` output. Wrong index → CPU-only install or import errors. Always check toolkit version first. |
| "I'll skip `nvcc --version` — `nvidia-smi` shows CUDA 12.6 so we're fine" | `nvidia-smi` shows driver's max supported CUDA, not the installed toolkit. The toolkit version (from `nvcc`) is what matters for builds and index URL selection. |
| "bitsandbytes install failed, let me try a different CUDA index" | bitsandbytes auto-detects CUDA from pre-built wheels — no index URL needed. The real issue is usually missing CUDA toolkit or wrong PATH. Check `nvcc --version` first. |
| "Flash-Attention build is slow, let me skip `--no-build-isolation`" | `--no-build-isolation` is required for Flash-Attention. Without it, the build can't find the installed PyTorch and CUDA headers, causing cryptic compilation failures. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to build a GPU-enabled Docker container | docker-gpu-setup | Handles Dockerfile, NGC base images, NVIDIA Container Toolkit setup |
| Fine-tuning a model with Trainer/LoRA/QLoRA | hf-transformers-trainer | Covers TrainingArguments, PEFT config, VRAM estimation |
| Deploying model on Triton Inference Server | triton-deployment | Handles config.pbtxt, model repository, ensemble pipelines |
| Quantizing model to GGUF/GPTQ/AWQ | model-quantization | Covers quantization methods, calibration, quality comparison |
| Serving model with vLLM or TGI | vllm-tgi-inference | Handles vllm serve, TGI Docker, tensor parallelism |
| Setting up pyproject.toml, ruff, pytest from scratch | python-project-setup | Covers uv init, project scaffolding, linter/formatter config |

## References

- [PyTorch CUDA Matrix](references/pytorch-cuda-matrix.md) — Full PyTorch version × CUDA version compatibility table with uv commands
  **Load when:** selecting the correct `--index-url` for a specific PyTorch + CUDA version combination
- [Flash-Attention](references/flash-attention.md) — CUDA toolkit requirements, build flags, common compilation errors
  **Load when:** building Flash-Attention from source or hitting compilation errors during `uv pip install flash-attn`
- [DeepSpeed & bitsandbytes](references/deepspeed-bitsandbytes.md) — DeepSpeed ops builder, bitsandbytes CUDA detection, pre-built wheels
  **Load when:** installing DeepSpeed with custom ops (`DS_BUILD_OPS=1`) or debugging bitsandbytes CUDA detection failures
- [xformers & RAPIDS](references/xformers-rapids.md) — xformers build from source vs wheels, RAPIDS cuDF/cuML conda-vs-pip
  **Load when:** installing xformers without a matching pre-built wheel or setting up RAPIDS alongside PyTorch
- [llama-cpp-python](references/llama-cpp-python.md) — CMAKE_ARGS for CUDA, Metal, ROCm; pre-built wheel index URLs
  **Load when:** building llama-cpp-python with a specific backend (CUDA, Metal, ROCm) or finding pre-built wheels
- [Compatibility Matrix](references/compatibility-matrix.md) — Full NVIDIA stack version tables (CUDA, cuDNN, PyTorch, ONNX RT, TensorRT)
  **Load when:** diagnosing version conflicts across multiple NVIDIA stack components (PyTorch + ORT + cuDNN + TensorRT)
- [Driver ↔ CUDA](references/driver-cuda.md) — Driver requirements and forward compatibility for data center GPUs
  **Load when:** seeing "CUDA driver version insufficient" errors or checking forward compatibility on data center GPUs (T4, A100, H100)
- [ONNX Runtime ↔ CUDA](references/onnxruntime-cuda.md) — ORT CUDA/cuDNN version compatibility table
  **Load when:** "CUDAExecutionProvider is not available" errors or cuDNN major version mismatch between PyTorch and ONNX Runtime
- [Triton Containers](references/triton-containers.md) — NGC container version mapping for Triton Inference Server
  **Load when:** selecting the correct NGC Triton container version to match your CUDA/TensorRT/PyTorch stack