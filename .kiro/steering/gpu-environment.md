---
inclusion: fileMatch
fileMatchPattern: ["**/Dockerfile*", "**/docker-compose*", "**/.dockerignore"]
---

# GPU Environment Conventions

Khi làm việc với Dockerfile hoặc docker-compose cho GPU/ML workloads, tuân thủ các conventions sau.

## NGC Base Image Selection

| Use case | Base Image | Lý do |
|----------|-----------|-------|
| Training (PyTorch) | `nvcr.io/nvidia/pytorch:<tag>-py3` | Pre-built PyTorch + CUDA + NCCL |
| Training (TensorFlow) | `nvcr.io/nvidia/tensorflow:<tag>-tf2-py3` | Pre-built TF + CUDA |
| Inference (Triton) | `nvcr.io/nvidia/tritonserver:<tag>-py3` | Triton + all backends |
| Inference (TGI) | `ghcr.io/huggingface/text-generation-inference:latest` | HF official |
| Lightweight/custom | `nvidia/cuda:<cuda_ver>-devel-ubuntu22.04` | Minimal, build from scratch |

## Dockerfile Rules

- LUÔN dùng multi-stage build (deps → runtime)
- Install uv cho dependency management: `COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/`
- KHÔNG `pip install` trực tiếp — dùng `uv pip install --system`
- Pin CUDA version trong base image — KHÔNG dùng `latest` tag
- `.dockerignore`: exclude `.git/`, `__pycache__/`, `*.pyc`, model weights (mount thay vì copy)

## docker-compose GPU Passthrough

```yaml
services:
  app:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all  # hoặc số GPU cụ thể
              capabilities: [gpu]
```

## Pre-build Check — HARD GATE

Trước khi build GPU container:
1. `docker info | grep -i nvidia` — NVIDIA runtime phải available
2. `nvidia-smi` — Driver phải compatible với CUDA version trong base image
3. Check CUDA compatibility: driver version ≥ minimum cho CUDA target

Tham khảo skill `docker-gpu-setup` cho chi tiết và `python-ml-deps` cho CUDA version matrix.
