---
inclusion: fileMatch
fileMatchPattern: ["**/Dockerfile*", "**/docker-compose*", "**/.dockerignore"]
description: Conventions for GPU-enabled Docker containers and docker-compose. Applies when editing Dockerfile, docker-compose, or .dockerignore for ML/CUDA workloads.
---

# GPU Environment Conventions

When working with Dockerfiles or docker-compose for GPU/ML workloads, follow these conventions.

## NGC Base Image Selection

| Use case | Base Image | Reason |
|----------|-----------|--------|
| Training (PyTorch) | `nvcr.io/nvidia/pytorch:<tag>-py3` | Pre-built PyTorch + CUDA + NCCL |
| Training (TensorFlow) | `nvcr.io/nvidia/tensorflow:<tag>-tf2-py3` | Pre-built TF + CUDA |
| Inference (Triton) | `nvcr.io/nvidia/tritonserver:<tag>-py3` | Triton + all backends |
| Inference (TGI) | `ghcr.io/huggingface/text-generation-inference:latest` | HF official |
| Lightweight/custom | `nvidia/cuda:<cuda_ver>-devel-ubuntu22.04` | Minimal, build from scratch |

## Dockerfile Rules

- ALWAYS use multi-stage builds (deps → runtime)
- Install uv for dependency management: `COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/`
- Do NOT use `pip install` directly — use `uv pip install --system`
- Pin CUDA version in base image — do NOT use `latest` tag
- `.dockerignore`: exclude `.git/`, `__pycache__/`, `*.pyc`, model weights (mount instead of copy)

## docker-compose GPU Passthrough

```yaml
services:
  app:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all  # or specific GPU count
              capabilities: [gpu]
```

## Pre-build Check — HARD GATE

Before building a GPU container:
1. `docker info | grep -i nvidia` — NVIDIA runtime must be available
2. `nvidia-smi` — Driver must be compatible with the CUDA version in base image
3. Check CUDA compatibility: driver version ≥ minimum required for CUDA target

See skill `docker-gpu-setup` for details and `python-ml-deps` for CUDA version matrix.
