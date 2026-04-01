---
name: docker-gpu-setup
description: "Build reproducible GPU-enabled Docker containers for ML/CUDA workloads. Use when writing GPU Dockerfiles, selecting NGC base images, configuring docker-compose GPU passthrough, setting up NVIDIA Container Toolkit, or installing uv inside Docker containers."
---

# Docker GPU Setup

Dockerfile patterns and docker-compose configuration for GPU-enabled ML containers, using NGC base images, uv for dependency management, and NVIDIA Container Toolkit for GPU passthrough.

## Scope

This skill handles:
- Writing multi-stage Dockerfiles for ML/CUDA workloads with NGC base images
- Configuring docker-compose GPU passthrough with NVIDIA Container Toolkit
- Installing uv inside Docker containers for fast, reproducible dependency management
- Selecting the right NGC base image (training, inference, dev, runtime)
- Troubleshooting GPU not visible inside containers

Does NOT handle:
- Installing ML Python packages or resolving CUDA version conflicts on host (→ python-ml-deps)
- Deploying models on Triton Inference Server (→ triton-deployment)
- Fine-tuning models with Trainer/LoRA/PEFT (→ hf-transformers-trainer)

## When to Use

- Writing a Dockerfile for ML/CUDA workloads
- Choosing an NGC base image for training, inference, or development
- Installing Python dependencies with uv inside a Docker build
- Configuring docker-compose for GPU passthrough
- GPU not visible inside a running container
- Optimizing Docker layer caching for large ML dependencies
- Setting up a Jupyter or dev container with GPU access

## Multi-stage Dockerfile Template

A production-ready multi-stage Dockerfile for ML workloads using NGC base images and uv.

⚠️ **HARD GATE:** Do NOT build a GPU container before verifying NVIDIA Container Toolkit is installed on the host. Run `docker info | grep -i nvidia` — if no output, install the toolkit first (see Prerequisites below).

### 1. Dependencies stage

```dockerfile
# ---- Stage 1: Dependencies ----
FROM nvcr.io/nvidia/pytorch:24.07-py3 AS deps

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app

# Copy dependency files first (layer caching)
COPY pyproject.toml uv.lock ./

# Install dependencies (no dev deps in production)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project
```

**Validate:** Run `docker build --target deps -t test-deps .` — must complete without errors. If not → check that `pyproject.toml` and `uv.lock` exist and are valid.

### 2. Application stage

```dockerfile
# ---- Stage 2: Application ----
FROM nvcr.io/nvidia/pytorch:24.07-py3 AS runtime

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app

# Copy installed dependencies from deps stage
COPY --from=deps /app/.venv /app/.venv

# Copy application code
COPY . .

# Install the project itself
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# Ensure venv is on PATH
ENV PATH="/app/.venv/bin:$PATH"

CMD ["python", "-m", "myapp"]
```

**Validate:** Run `docker build -t my-ml-app .` then `docker run --rm --gpus all my-ml-app nvidia-smi` — must show GPU info. If not → verify NVIDIA Container Toolkit is installed and Docker is configured (see Troubleshooting).

**Key points**:
- Dependencies are installed in a separate stage so code changes don't invalidate the dep layer
- `--mount=type=cache` keeps the uv cache across builds (requires BuildKit)
- `--frozen` ensures the lock file is respected exactly
- NGC base already includes CUDA, cuDNN, NCCL, and PyTorch

## NGC Base Image Decision Guide

Pick the right base image for your use case:

| Use Case | Recommended Base | Why |
|---|---|---|
| Training (PyTorch) | `nvcr.io/nvidia/pytorch:24.07-py3` | Pre-built PyTorch + CUDA + NCCL + cuDNN, optimized for multi-GPU |
| Training (TensorFlow) | `nvcr.io/nvidia/tensorflow:24.07-tf2-py3` | Pre-built TF2 + CUDA + NCCL |
| Inference (Triton) | `nvcr.io/nvidia/tritonserver:24.07-py3` | Multi-backend inference server, production-ready |
| Inference (TensorRT) | `nvcr.io/nvidia/tensorrt:24.07-py3` | TensorRT + CUDA for optimized inference |
| General CUDA dev | `nvcr.io/nvidia/cuda:12.4.1-devel-ubuntu22.04` | Minimal CUDA toolkit, you install everything else |
| Runtime only | `nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04` | Smallest image, CUDA runtime libs only (no compiler) |
| Jupyter / dev | `nvcr.io/nvidia/pytorch:24.07-py3` | Full stack, add JupyterLab on top |

**Rules**:
- Use `devel` images when you need to compile CUDA code (Flash-Attention, custom kernels)
- Use `runtime` images for deployment when all deps are pre-built wheels
- NGC framework images (pytorch, tensorflow) include the framework — don't reinstall it via pip
- Tag format: `YY.MM-py3` (e.g., `24.07-py3` = July 2024 release)
- Check driver compatibility: `nvidia-smi` driver version must meet the container's minimum

## uv-in-Docker Pattern

Install uv in any Docker image using the official multi-stage copy:

```dockerfile
# Copy uv binary from official image (no curl/pip needed)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
```

### Full pattern with cache mount

```dockerfile
FROM nvcr.io/nvidia/cuda:12.4.1-devel-ubuntu22.04

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app
COPY pyproject.toml uv.lock ./

# Cache uv downloads across builds
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"
```

**Why uv in Docker?**
- Single static binary — no pip bootstrap needed
- Faster installs than pip (10-100x in cached scenarios)
- Lock file support (`uv.lock`) for reproducible builds
- Cache mounts work well with BuildKit

## docker-compose GPU Snippet

GPU passthrough requires the NVIDIA Container Toolkit installed on the host.

⚠️ **HARD GATE:** Do NOT configure docker-compose GPU passthrough before verifying the host has a working NVIDIA driver (`nvidia-smi` must succeed) and NVIDIA Container Toolkit is installed (`docker info | grep -i nvidia` must show nvidia runtime).

### docker-compose.yml (Compose v2.x)

```yaml
services:
  training:
    build: .
    image: my-ml-app:latest
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all        # or specific count: 1, 2, etc.
              capabilities: [gpu]
    volumes:
      - ./data:/app/data
      - ./models:/app/models
    shm_size: "8g"              # Required for PyTorch DataLoader workers
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=compute,utility
```

**Validate:** Run `docker compose run --rm training nvidia-smi` — must show GPU info. If not → check Prerequisites below.

### Specific GPU selection

```yaml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ["0", "2"]   # Use GPU 0 and GPU 2 only
              capabilities: [gpu]
```

### Prerequisites

1. **NVIDIA Driver** installed on host (`nvidia-smi` works)
2. **NVIDIA Container Toolkit** installed:
   ```bash
   # Ubuntu/Debian
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
     sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```
3. **Docker Compose v2** (the `deploy.resources.reservations.devices` syntax requires Compose v2)

**Validate:** Run `docker info | grep -i nvidia` — must show `nvidia` in runtimes. If not → re-run `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`.

## GPU Troubleshooting Quick Check

When GPU is not visible inside a container:

```
GPU not visible in container?
├─ Host: does `nvidia-smi` work?
│   └─ No → Install/update NVIDIA driver
│
├─ Is NVIDIA Container Toolkit installed?
│   └─ No → Install it (see Prerequisites above)
│
├─ Is Docker configured to use nvidia runtime?
│   ├─ Check: docker info | grep -i nvidia
│   └─ Fix: sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker
│
├─ Using docker run?
│   └─ Add: --gpus all
│
├─ Using docker compose?
│   └─ Add deploy.resources.reservations.devices (see snippet above)
│
├─ Driver version too old for container CUDA?
│   ├─ Check: nvidia-smi shows driver version
│   └─ See python-ml-deps for driver/CUDA compat
│
└─ Multiple GPUs but only some visible?
    └─ Set NVIDIA_VISIBLE_DEVICES=0,1 or use device_ids in compose
```

> For detailed troubleshooting, see [Troubleshooting reference](references/troubleshooting.md)

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "The host has `nvidia-smi`, so Docker GPU passthrough will just work" | NVIDIA driver alone is not enough. NVIDIA Container Toolkit must be installed AND Docker must be configured to use the nvidia runtime. Always verify with `docker info \| grep -i nvidia` before building. |
| "I'll reinstall PyTorch inside the NGC container to get the latest version" | NGC framework images (pytorch, tensorflow) ship with a pre-tested, optimized framework build. Reinstalling via pip breaks NCCL/cuDNN alignment and loses NVIDIA's optimizations. Use the included version. |
| "Layer caching doesn't matter for ML containers" | ML base images are 5-15 GB. Without multi-stage builds and `--mount=type=cache`, every code change triggers a full dependency reinstall. Always copy `pyproject.toml`/`uv.lock` before application code. |
| "I'll use `docker run --runtime=nvidia` — it's the same as `--gpus all`" | `--runtime=nvidia` is the legacy approach. Modern Docker (19.03+) uses `--gpus all` which is simpler and works with Compose v2's `deploy.resources.reservations.devices` syntax. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need to install ML Python packages or resolve CUDA version conflicts | python-ml-deps | Handles `uv pip install`, PyTorch CUDA index URLs, NVIDIA stack version resolution |
| Deploying model inside a Triton Inference Server container | triton-deployment | Covers config.pbtxt, model repository structure, Triton NGC container selection |
| Serving models with vLLM or TGI in Docker | vllm-tgi-inference | Handles vllm serve, TGI Docker setup, tensor parallelism, KV cache tuning |
| Fine-tuning inside a container and need VRAM estimation | hf-transformers-trainer | Covers TrainingArguments, LoRA/QLoRA config, VRAM requirements |

## References

- [Dockerfile Templates](references/dockerfile-templates.md) — Full Dockerfile examples for training, inference, dev, Jupyter, and multi-model setups
  **Load when:** need a complete Dockerfile for a specific use case (training, inference, Jupyter) beyond the multi-stage template above
- [NGC Base Images](references/ngc-base-images.md) — Detailed NGC image guide with version tags, sizes, and included software
  **Load when:** choosing between NGC image versions or need to check what software/CUDA version is included in a specific tag
- [Layer Caching](references/layer-caching.md) — Strategies for caching large ML deps: requirements-first copy, BuildKit cache mounts, multi-stage dep layers
  **Load when:** Docker builds are slow due to large ML dependencies and need advanced caching strategies beyond the basic pattern
- [Troubleshooting](references/troubleshooting.md) — GPU not visible checklist, NVIDIA Container Toolkit setup, Docker runtime config, driver compatibility
  **Load when:** GPU is not visible inside a container or `docker compose run` fails with NVIDIA-related errors
