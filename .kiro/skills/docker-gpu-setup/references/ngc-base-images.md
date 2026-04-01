# NGC Base Images Guide

Detailed reference for selecting NVIDIA GPU Cloud (NGC) container images. Covers the three main image families, their tag conventions, included software, approximate sizes, and when to pick each one.

> Last verified against NGC catalog: July 2024 (24.07 release)

## Tag Naming Convention

NGC images follow predictable tag patterns:

| Image Family | Tag Format | Example |
|---|---|---|
| Framework (PyTorch, TF) | `YY.MM-py3` | `nvcr.io/nvidia/pytorch:24.07-py3` |
| Triton Server | `YY.MM-py3` | `nvcr.io/nvidia/tritonserver:24.07-py3` |
| CUDA (devel) | `MAJOR.MINOR.PATCH-devel-OS` | `nvcr.io/nvidia/cuda:12.4.1-devel-ubuntu22.04` |
| CUDA (runtime) | `MAJOR.MINOR.PATCH-runtime-OS` | `nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04` |
| CUDA (base) | `MAJOR.MINOR.PATCH-base-OS` | `nvcr.io/nvidia/cuda:12.4.1-base-ubuntu22.04` |

- `YY.MM` = year and month of the NGC release (e.g., `24.07` = July 2024)
- `-py3` suffix indicates Python 3 is included
- CUDA images use the full CUDA toolkit version + OS variant
- Newer tags generally require newer host drivers — check with `nvidia-smi`

## Image Family Overview

### 1. `nvcr.io/nvidia/pytorch` — Framework Image

Pre-built PyTorch with the full NVIDIA optimization stack.

| Aspect | Detail |
|---|---|
| Compressed size | ~8-9 GB |
| Uncompressed size | ~18-20 GB |
| Python | 3.10 (varies by release) |
| Included | PyTorch, CUDA toolkit, cuDNN, NCCL, TensorRT, DALI, Apex, Transformer Engine |
| OS | Ubuntu 22.04 |
| CUDA | Matches release (e.g., 24.07 → CUDA 12.5) |

**When to use**:
- Training models with PyTorch (single or multi-GPU)
- Fine-tuning LLMs or diffusion models
- Development and experimentation (Jupyter, interactive work)
- Any workload where you need PyTorch + CUDA and don't want to compile anything

**When NOT to use**:
- Production inference where image size matters — use CUDA runtime instead
- You need TensorFlow — use `nvcr.io/nvidia/tensorflow` instead
- You only need CUDA (no framework) — use the CUDA images

**Example**:
```dockerfile
FROM nvcr.io/nvidia/pytorch:24.07-py3
# PyTorch is already installed — do NOT reinstall via pip/uv
```

### 2. `nvcr.io/nvidia/tritonserver` — Inference Server

NVIDIA Triton Inference Server with multi-backend support.

| Aspect | Detail |
|---|---|
| Compressed size | ~10-12 GB |
| Uncompressed size | ~22-25 GB |
| Python | 3.10 (varies by release) |
| Included | Triton Server, CUDA toolkit, cuDNN, TensorRT, ONNX Runtime, PyTorch backend, Python backend |
| OS | Ubuntu 22.04 |
| Backends | ONNX Runtime, TensorRT, PyTorch, TensorFlow, Python, OpenVINO, FIL |

**When to use**:
- Production model serving with Triton
- Multi-model serving (different frameworks in one server)
- Ensemble pipelines (preprocessing → model → postprocessing)
- Dynamic batching and model concurrency

**When NOT to use**:
- Training — this is an inference-only image
- Simple single-model serving — may be overkill; consider a CUDA runtime image with your own server
- You don't need Triton's features — the image is large

**Example**:
```dockerfile
FROM nvcr.io/nvidia/tritonserver:24.07-py3
# Configure model repository and start server
CMD ["tritonserver", "--model-repository=/models"]
```

> **See also**: [triton-deployment](../../triton-deployment/SKILL.md) for model repository layout and config.pbtxt patterns

### 3. `nvcr.io/nvidia/cuda` — Bare CUDA Images

Minimal CUDA images in three variants. You install everything else yourself.

#### 3a. `cuda:*-devel-*` (Development)

| Aspect | Detail |
|---|---|
| Compressed size | ~3-4 GB |
| Uncompressed size | ~7-9 GB |
| Python | Not included (install yourself) |
| Included | CUDA toolkit (nvcc compiler), cuDNN headers, development libraries |
| OS | Ubuntu 22.04 or 20.04 |

**When to use**:
- Building CUDA extensions from source (Flash-Attention, custom kernels)
- Compiling packages that need `nvcc` (xformers, bitsandbytes from source)
- Multi-stage builds: use `devel` in the build stage, `runtime` in the final stage

#### 3b. `cuda:*-runtime-*` (Runtime)

| Aspect | Detail |
|---|---|
| Compressed size | ~1-2 GB |
| Uncompressed size | ~3-4 GB |
| Python | Not included (install yourself) |
| Included | CUDA runtime libraries (libcudart, libcublas, etc.), cuDNN runtime |
| OS | Ubuntu 22.04 or 20.04 |

**When to use**:
- Production deployment where image size matters
- All dependencies are pre-built wheels (no compilation needed)
- Final stage of multi-stage builds
- Inference containers with custom serving code

#### 3c. `cuda:*-base-*` (Base)

| Aspect | Detail |
|---|---|
| Compressed size | ~200-400 MB |
| Uncompressed size | ~600 MB - 1 GB |
| Python | Not included |
| Included | Minimal CUDA runtime (libcudart only) |
| OS | Ubuntu 22.04 or 20.04 |

**When to use**:
- Absolute minimum CUDA footprint
- Applications that only need basic CUDA runtime
- Rarely used for ML — most workloads need cuBLAS/cuDNN from `runtime`

## Decision Table

| Use Case | Recommended Image | Why |
|---|---|---|
| PyTorch training | `nvidia/pytorch:24.07-py3` | Full stack, optimized, multi-GPU ready |
| TensorFlow training | `nvidia/tensorflow:24.07-tf2-py3` | Pre-built TF2 + CUDA + NCCL |
| Triton model serving | `nvidia/tritonserver:24.07-py3` | Multi-backend, dynamic batching, production-ready |
| Inference (custom server) | `cuda:12.4.1-runtime-ubuntu22.04` | Small image, pre-built wheel deps only |
| Build CUDA extensions | `cuda:12.4.1-devel-ubuntu22.04` | Has `nvcc` and dev headers |
| Multi-stage (build+deploy) | `devel` → `runtime` | Compile in devel, run in runtime |
| Jupyter / dev environment | `nvidia/pytorch:24.07-py3` | Full stack, add JupyterLab on top |
| Minimal CUDA footprint | `cuda:12.4.1-base-ubuntu22.04` | Smallest possible, libcudart only |

## Common Version Tags

Recent stable tags (as of mid-2024):

| Release | PyTorch Image | Triton Image | CUDA Version | Min Driver |
|---|---|---|---|---|
| 24.07 | `pytorch:24.07-py3` | `tritonserver:24.07-py3` | 12.5 | 555.42+ |
| 24.05 | `pytorch:24.05-py3` | `tritonserver:24.05-py3` | 12.4 | 550.54+ |
| 24.03 | `pytorch:24.03-py3` | `tritonserver:24.03-py3` | 12.4 | 550.54+ |
| 24.01 | `pytorch:24.01-py3` | `tritonserver:24.01-py3` | 12.3 | 545.23+ |
| 23.12 | `pytorch:23.12-py3` | `tritonserver:23.12-py3` | 12.3 | 545.23+ |

For CUDA images, pick the CUDA version that matches your PyTorch/framework needs:

| CUDA Version | Devel Tag | Runtime Tag |
|---|---|---|
| 12.5.1 | `cuda:12.5.1-devel-ubuntu22.04` | `cuda:12.5.1-runtime-ubuntu22.04` |
| 12.4.1 | `cuda:12.4.1-devel-ubuntu22.04` | `cuda:12.4.1-runtime-ubuntu22.04` |
| 12.1.1 | `cuda:12.1.1-devel-ubuntu22.04` | `cuda:12.1.1-runtime-ubuntu22.04` |
| 11.8.0 | `cuda:11.8.0-devel-ubuntu22.04` | `cuda:11.8.0-runtime-ubuntu22.04` |

> **See also**: [python-ml-deps](../../python-ml-deps/SKILL.md) for full driver ↔ CUDA compatibility matrix

## Tips

- **Don't reinstall the framework**: NGC framework images (pytorch, tensorflow) include the framework pre-built with NVIDIA optimizations. Installing PyTorch via pip/uv on top will overwrite the optimized build.
- **Match CUDA versions**: If using a CUDA base image + PyTorch wheel, the CUDA version in the image must match the PyTorch CUDA variant (e.g., `cu124` wheel needs CUDA 12.4 image).
- **Check driver compat first**: Run `nvidia-smi` on the host to see your driver version. The container's CUDA version must be supported by that driver.
- **Use `devel` only when needed**: The devel images are 2-4x larger than runtime. Use multi-stage builds to keep final images small.
- **Pin your tags**: Always use a specific `YY.MM` tag, never `latest`. NGC `latest` can change without notice and break reproducibility.
- **Layer sharing**: If you run multiple containers from the same NGC base, Docker shares the base layers — disk usage is only counted once.

> **See also**: [Layer Caching](layer-caching.md) for strategies to minimize rebuild times with large NGC base images
