# Layer Caching Strategies for ML Dependencies

Docker layer caching is critical for ML workloads where dependency installs can take 10-30+ minutes (PyTorch alone is ~2GB). These strategies minimize rebuild times by ensuring expensive dependency layers are cached and only invalidated when dependencies actually change.

## Strategy 1: Requirements-First Copy

The most impactful optimization. Copy dependency files before application code so the dep layer is cached when only code changes.

### Bad — Code change invalidates deps

```dockerfile
FROM nvcr.io/nvidia/pytorch:24.07-py3
WORKDIR /app

# COPY everything — any code change busts the cache for ALL layers below
COPY . .
RUN pip install -r requirements.txt

CMD ["python", "-m", "train"]
```

### Good — Deps cached independently of code

```dockerfile
FROM nvcr.io/nvidia/pytorch:24.07-py3
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

# Step 1: Copy ONLY dependency files
COPY pyproject.toml uv.lock ./

# Step 2: Install deps (cached unless pyproject.toml or uv.lock changes)
RUN uv sync --frozen --no-dev --no-install-project

# Step 3: Copy application code (changes here don't bust the dep layer)
COPY . .
RUN uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"
CMD ["python", "-m", "train"]
```

### What to copy first

| Package Manager | Files to Copy |
|---|---|
| uv | `pyproject.toml`, `uv.lock` |
| pip | `requirements.txt` (and `requirements-dev.txt` if needed) |
| Poetry | `pyproject.toml`, `poetry.lock` |
| pip-tools | `requirements.in`, `requirements.txt` |

### Key rule

Only copy files that define dependencies. Never `COPY . .` before installing deps.

## Strategy 2: BuildKit Cache Mounts

BuildKit cache mounts persist downloaded wheels and compiled artifacts across builds, even when the dependency layer is invalidated. This turns a 15-minute PyTorch reinstall into a ~30-second cache hit.

### Enable BuildKit

```bash
# Option 1: Environment variable
export DOCKER_BUILDKIT=1
docker build .

# Option 2: Docker Buildx (recommended)
docker buildx build .

# Option 3: Set as default in /etc/docker/daemon.json
{
  "features": { "buildkit": true }
}
```

### uv cache mount

```dockerfile
COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project
```

The `/root/.cache/uv` directory stores downloaded wheels. On cache hit, uv skips the download entirely.

### pip cache mount

```dockerfile
COPY requirements.txt ./

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-deps -r requirements.txt
```

### Multiple cache mounts for compiled packages

When building packages from source (Flash-Attention, custom CUDA kernels), cache the build artifacts too:

```dockerfile
ENV MAX_JOBS=4
ENV FLASH_ATTENTION_FORCE_BUILD=TRUE

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=cache,target=/tmp/flash-attn-build \
    uv pip install flash-attn --no-build-isolation
```

### Cache mount limitations

- Cache mounts are local to the build host — they don't transfer between machines
- CI runners with ephemeral VMs won't benefit unless you use remote BuildKit cache (see CI section below)
- Cache contents are not included in the final image (this is a feature, not a bug)

## Strategy 3: Multi-Stage Dependency Layers

Use a dedicated build stage for dependencies. This isolates dep installation from the final image and enables parallel builds.

### Basic two-stage pattern

```dockerfile
# ---- Stage 1: Install dependencies ----
FROM nvcr.io/nvidia/pytorch:24.07-py3 AS deps

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# ---- Stage 2: Application ----
FROM nvcr.io/nvidia/pytorch:24.07-py3 AS runtime

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

# Copy pre-built venv from deps stage
COPY --from=deps /app/.venv /app/.venv
COPY . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"
CMD ["python", "-m", "train"]
```

### Three-stage pattern with CUDA compilation

When some deps need `devel` (compiler) but the final image only needs `runtime`:

```dockerfile
# ---- Stage 1: Compile CUDA extensions ----
FROM nvcr.io/nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# ---- Stage 2: Slim runtime ----
FROM nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY . .

ENV PATH="/app/.venv/bin:$PATH"
CMD ["python", "-m", "serve"]
```

This saves 3-5GB in the final image by dropping the CUDA compiler toolchain.

### When to use multi-stage

| Scenario | Stages | Why |
|---|---|---|
| Standard ML app | 2 (deps → runtime) | Isolate dep install from code changes |
| CUDA compilation needed | 3 (devel → deps → runtime) | Compile in devel, run in runtime |
| Dev + prod from one Dockerfile | 2 targets | `docker build --target dev` vs `--target prod` |

## Combining All Three Strategies

The optimal Dockerfile uses all three strategies together:

```dockerfile
# syntax=docker/dockerfile:1

# ---- Stage 1: Dependencies ----
FROM nvcr.io/nvidia/pytorch:24.07-py3 AS deps

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

# Strategy 1: Copy only dependency files first
COPY pyproject.toml uv.lock ./

# Strategy 2: BuildKit cache mount for uv downloads
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# ---- Stage 2: Application (Strategy 3: multi-stage) ----
FROM nvcr.io/nvidia/pytorch:24.07-py3 AS runtime

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app

COPY --from=deps /app/.venv /app/.venv
COPY . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"
CMD ["python", "-m", "train"]
```

Build: `docker buildx build -t my-ml-app:latest .`

## CI/CD Cache Strategies

### GitHub Actions with BuildKit cache

```yaml
- name: Build Docker image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: my-ml-app:latest
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

`type=gha` stores BuildKit layer cache in GitHub Actions cache. `mode=max` caches all layers, not just the final image.

### Registry-based cache (works with any CI)

```yaml
- name: Build with registry cache
  run: |
    docker buildx build \
      --cache-from type=registry,ref=myregistry.io/my-ml-app:cache \
      --cache-to type=registry,ref=myregistry.io/my-ml-app:cache,mode=max \
      -t my-ml-app:latest \
      --push .
```

### Pre-built base image for deps

For teams where deps change rarely, build a base image with deps pre-installed and push it to a registry:

```dockerfile
# deps-base.Dockerfile — rebuild only when deps change
FROM nvcr.io/nvidia/pytorch:24.07-py3
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project
ENV PATH="/app/.venv/bin:$PATH"
```

```dockerfile
# Dockerfile — fast builds, just copies code
FROM myregistry.io/my-ml-deps:latest
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev
CMD ["python", "-m", "train"]
```

Automate the deps-base rebuild with a CI trigger on `pyproject.toml` or `uv.lock` changes.

## Quick Reference

| Problem | Strategy | Impact |
|---|---|---|
| Code change reinstalls all deps | Requirements-first copy | Deps cached unless lock file changes |
| Deps reinstall downloads wheels again | BuildKit cache mount | Wheels cached on disk across builds |
| Final image too large | Multi-stage (devel → runtime) | Drop compiler, save 3-5GB |
| CI builds always cold | Registry cache or pre-built base | Share cache across CI runs |
| Flash-Attention recompiles every build | Cache mount on build dir | Compiled artifacts persist |

> **See also**: [Dockerfile Templates](dockerfile-templates.md) for complete Dockerfiles using these caching strategies

> **See also**: [python-ml-deps — Flash-Attention](../../python-ml-deps/references/flash-attention.md) for Flash-Attention build flags and requirements
