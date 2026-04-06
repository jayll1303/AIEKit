# Project Scaffold — OpenAI-Compatible Audio API

## Directory Structure

```
my_audio_server/
├── my_audio_server/
│   ├── __init__.py              # __version__
│   ├── __main__.py              # from .cli import main; main()
│   ├── app.py                   # FastAPI factory + lifespan
│   ├── cli.py                   # argparse → Settings → uvicorn
│   ├── config.py                # pydantic-settings
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── speech.py            # POST /v1/audio/speech
│   │   ├── models.py            # GET /v1/models
│   │   └── health.py            # GET /health, /metrics
│   ├── services/
│   │   ├── __init__.py
│   │   ├── model.py             # Model singleton, async load
│   │   ├── inference.py         # Semaphore + ThreadPool + Adapter
│   │   └── metrics.py           # Thread-safe counters
│   └── utils/
│       ├── __init__.py
│       ├── audio.py             # tensor → WAV/PCM bytes
│       └── text.py              # Sentence splitting
├── tests/
│   ├── conftest.py
│   ├── test_speech.py
│   ├── test_streaming.py
│   └── test_health.py
├── pyproject.toml
├── Dockerfile
├── docker-compose.yml
└── README.md
```

## pyproject.toml Template

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "my-audio-server"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
    "python-multipart>=0.0.12",
    "pydantic>=2.0.0",
    "pydantic-settings>=2.0.0",
    "psutil>=6.0.0",
    "torchaudio>=2.0.0",
    # Add your model's package here
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.24.0",
    "pytest-cov>=5.0.0",
    "httpx>=0.27.0",
    "ruff>=0.6.0",
]

[project.scripts]
my-audio-server = "my_audio_server.cli:main"

[tool.ruff]
line-length = 100
target-version = "py310"

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

## Dockerfile Template (Multi-stage)

```dockerfile
FROM python:3.10-slim AS builder
WORKDIR /build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*
COPY pyproject.toml README.md ./
COPY my_audio_server ./my_audio_server
RUN pip install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir .

FROM python:3.10-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libsndfile1 libgomp1 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin/my-audio-server /usr/local/bin/my-audio-server
EXPOSE 8880
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8880/health')" || exit 1
CMD ["my-audio-server", "--host", "0.0.0.0", "--port", "8880"]
```

## docker-compose.yml Template

```yaml
services:
  audio-server:
    build: .
    ports:
      - "8880:8880"
    environment:
      - MYAPP_HOST=0.0.0.0
      - MYAPP_PORT=8880
      - MYAPP_DEVICE=cpu
      - MYAPP_MAX_CONCURRENT=2
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8880/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

## Implementation Checklist

- [ ] `config.py` — pydantic-settings with env prefix
- [ ] `services/model.py` — Async model loading with dtype fallback
- [ ] `services/inference.py` — Semaphore + ThreadPoolExecutor + Adapter
- [ ] `services/metrics.py` — Thread-safe counters
- [ ] `utils/audio.py` — tensor → WAV/PCM conversion
- [ ] `utils/text.py` — Sentence splitting for streaming
- [ ] `routers/speech.py` — POST /v1/audio/speech (streaming + non-streaming)
- [ ] `routers/models.py` — GET /v1/models (OpenAI SDK needs this)
- [ ] `routers/health.py` — GET /health + /metrics
- [ ] `app.py` — Factory + lifespan + auth middleware
- [ ] `cli.py` — argparse → Settings → uvicorn
- [ ] `tests/conftest.py` — Mock model, TestClient fixture
- [ ] `Dockerfile` — Multi-stage build
- [ ] Memory cleanup: gc.collect() + empty_cache() in finally block
