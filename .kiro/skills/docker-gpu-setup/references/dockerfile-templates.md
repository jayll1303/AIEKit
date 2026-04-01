# Dockerfile Templates

Complete, copy-pasteable Dockerfiles for common GPU ML workloads. All templates use NGC base images, uv for dependency management, and BuildKit cache mounts (`DOCKER_BUILDKIT=1`).

All templates assume a `pyproject.toml` + `uv.lock` in the build context.

## 1. Training Dockerfile

Multi-GPU training with PyTorch. NGC base includes CUDA, cuDNN, NCCL.

```dockerfile
# ---- Stage 1: Dependencies ----
FROM nvcr.io/nvidia/pytorch:24.07-py3 AS deps

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# ---- Stage 2: Runtime ----
FROM nvcr.io/nvidia/pytorch:24.07-py3 AS runtime

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY --from=deps /app/.venv /app/.venv
COPY . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"
ENV NCCL_DEBUG=INFO

CMD ["python", "-m", "train"]
```

Run: `docker run --gpus all --shm-size=8g -v ./data:/app/data my-training:latest`

## 2. Inference Dockerfile

Minimal image for serving. Uses CUDA runtime base (no compiler, ~2GB smaller).

```dockerfile
# ---- Stage 1: Build deps ----
FROM nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS deps

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# ---- Stage 2: Runtime ----
FROM nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY --from=deps /app/.venv /app/.venv
COPY . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"

RUN useradd --create-home appuser
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python3.11 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

CMD ["python", "-m", "serve", "--host", "0.0.0.0", "--port", "8080"]
```

Run: `docker run --gpus '"device=0"' -p 8080:8080 my-inference:latest`

If deps need CUDA compilation at install time, use `devel` in the deps stage and `runtime` in the final stage.

## 3. Development Dockerfile

Full dev environment with tools, debugger support, and editable installs. Single stage — image size matters less in dev.

```dockerfile
FROM nvcr.io/nvidia/pytorch:24.07-py3

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

RUN apt-get update && apt-get install -y --no-install-recommends \
    git vim curl htop tmux \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install all deps including dev (ruff, pytest, mypy, etc.)
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project

COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

ENV PATH="/app/.venv/bin:$PATH"
EXPOSE 5678

CMD ["/bin/bash"]
```

Recommended docker-compose for dev (volume mount for live reload):
```yaml
services:
  dev:
    build: { context: ., dockerfile: Dockerfile.dev }
    deploy:
      resources:
        reservations:
          devices: [{ driver: nvidia, count: all, capabilities: [gpu] }]
    volumes:
      - .:/app
      - dev-venv:/app/.venv
    shm_size: "4g"
    stdin_open: true
    tty: true
    ports: ["5678:5678"]
volumes:
  dev-venv:
```

## 4. Jupyter Dockerfile

GPU-enabled JupyterLab for interactive experimentation.

```dockerfile
FROM nvcr.io/nvidia/pytorch:24.07-py3

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install jupyterlab>=4.0 ipywidgets matplotlib plotly

COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

ENV PATH="/app/.venv/bin:$PATH"
ENV JUPYTER_TOKEN=""
EXPOSE 8888

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", \
     "--no-browser", "--allow-root", \
     "--NotebookApp.token=${JUPYTER_TOKEN}"]
```

Run: `docker run --gpus all -p 8888:8888 -v ./notebooks:/app/notebooks my-jupyter:latest`

Set `JUPYTER_TOKEN` to a real value when exposing to a network. Add `--shm-size=4g` if notebooks use PyTorch DataLoaders with `num_workers > 0`.

## 5. Multi-Model Serving Dockerfile

Serve multiple models from one container. Uses devel→runtime multi-stage for CUDA extension compilation.

```dockerfile
# ---- Stage 1: Builder (devel for compilation) ----
FROM nvcr.io/nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# ---- Stage 2: Runtime ----
FROM nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app /app

ENV PATH="/app/.venv/bin:$PATH"
VOLUME ["/app/models"]

RUN useradd --create-home appuser
USER appuser

EXPOSE 8080 8081

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python3.11 -c "import urllib.request; urllib.request.urlopen('http://localhost:8081/health')"

CMD ["python", "-m", "serve_multi", "--model-dir", "/app/models", \
     "--host", "0.0.0.0", "--port", "8080", "--management-port", "8081"]
```

Run: `docker run --gpus all -p 8080:8080 -p 8081:8081 -v ./models:/app/models:ro my-multi-model:latest`

Models are mounted read-only — swap models without rebuilding. Use `CUDA_VISIBLE_DEVICES` or `MODEL_DEVICE_MAP` env vars to assign models to specific GPUs.

## Template Selection Guide

| Scenario | Template | Base Image | Stages |
|---|---|---|---|
| Training a model | Training | NGC PyTorch | 2 |
| Deploying a model API | Inference | CUDA runtime | 2 |
| Day-to-day development | Development | NGC PyTorch | 1 |
| Interactive notebooks | Jupyter | NGC PyTorch | 1 |
| Serving multiple models | Multi-Model | CUDA devel → runtime | 2 |

## Common Customizations

### Add Flash-Attention (requires devel base)

```dockerfile
ENV MAX_JOBS=4
ENV FLASH_ATTENTION_FORCE_BUILD=TRUE
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install flash-attn --no-build-isolation
```

> **See also**: [python-ml-deps — Flash-Attention](../../python-ml-deps/references/flash-attention.md)

### Pin Python version

```dockerfile
RUN uv python install 3.11
ENV UV_PYTHON=3.11
```

> **See also**: [Layer Caching](layer-caching.md) for strategies to speed up rebuilds with large ML dependencies
