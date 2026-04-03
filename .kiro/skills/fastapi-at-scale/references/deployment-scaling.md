# Deployment & Scaling

Uvicorn/Gunicorn workers, Docker multi-stage builds, Kubernetes manifests, health checks, and graceful shutdown.

## When to Load
Deploying to production, configuring workers, or setting up Kubernetes.

## Worker Configuration

### Uvicorn (Development / Simple)

```bash
# Development
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Production (single server)
uvicorn src.main:app --host 0.0.0.0 --port 8000 --workers 4
```

### Gunicorn + Uvicorn Workers (Production)

```bash
gunicorn src.main:app \
  -k uvicorn.workers.UvicornWorker \
  -w 4 \
  -b 0.0.0.0:8000 \
  --timeout 120 \
  --graceful-timeout 30 \
  --keep-alive 5 \
  --access-logfile - \
  --error-logfile -
```

### Worker Count Guide

| Environment | Formula | Example (4 CPU) |
|---|---|---|
| CPU-bound | 2 × CPU + 1 | 9 workers |
| I/O-bound (typical API) | 2 × CPU + 1 | 9 workers |
| Kubernetes (1 worker/pod) | 1 | 1 worker, HPA scales pods |
| Memory-constrained | Available RAM / per-worker RAM | Varies |

⚠️ Each worker is a separate process with its own memory. 4 workers × 500 MB = 2 GB total.

## Docker Multi-Stage Build

```dockerfile
# Dockerfile
# Stage 1: Build
FROM python:3.12-slim AS builder

WORKDIR /app
RUN pip install --no-cache-dir uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-editable

COPY src/ src/
COPY alembic/ alembic/
COPY alembic.ini .

# Stage 2: Runtime
FROM python:3.12-slim AS runtime

WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/src /app/src
COPY --from=builder /app/alembic /app/alembic
COPY --from=builder /app/alembic.ini /app/alembic.ini

ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

USER appuser

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import httpx; httpx.get('http://localhost:8000/health').raise_for_status()"

CMD ["gunicorn", "src.main:app", "-k", "uvicorn.workers.UvicornWorker", "-w", "4", "-b", "0.0.0.0:8000", "--timeout", "120"]
```

## Docker Compose (Full Stack)

```yaml
# docker-compose.yml
services:
  api:
    build: .
    ports: ["8000:8000"]
    env_file: .env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    command: >
      sh -c "alembic upgrade head &&
             gunicorn src.main:app -k uvicorn.workers.UvicornWorker -w 4 -b 0.0.0.0:8000"

  celery-worker:
    build: .
    env_file: .env
    command: celery -A src.core.celery_app worker --loglevel=info --concurrency=4
    depends_on: [redis, postgres]

  celery-beat:
    build: .
    env_file: .env
    command: celery -A src.core.celery_app beat --loglevel=info
    depends_on: [redis]

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${DB_NAME:-mydb}
      POSTGRES_USER: ${DB_USER:-user}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-password}
    volumes: [postgres_data:/var/lib/postgresql/data]
    ports: ["5432:5432"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-user}"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

volumes:
  postgres_data:
```

## Kubernetes Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastapi-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: fastapi-app
  template:
    metadata:
      labels:
        app: fastapi-app
    spec:
      containers:
        - name: api
          image: myregistry/fastapi-app:latest
          ports:
            - containerPort: 8000
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: database-url
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 15
            periodSeconds: 10
          lifecycle:
            preStop:
              exec:
                command: ["sleep", "10"]  # Graceful shutdown
---
apiVersion: v1
kind: Service
metadata:
  name: fastapi-service
spec:
  selector:
    app: fastapi-app
  ports:
    - port: 80
      targetPort: 8000
  type: ClusterIP
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fastapi-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fastapi-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## Health Check Endpoints

```python
# src/core/health.py
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from src.core.dependencies import get_db

router = APIRouter(tags=["health"])

@router.get("/health")
async def health():
    """Liveness probe — app is running."""
    return {"status": "ok"}

@router.get("/ready")
async def readiness(db: AsyncSession = Depends(get_db)):
    """Readiness probe — app can serve traffic."""
    checks = {}
    try:
        await db.execute(text("SELECT 1"))
        checks["database"] = "healthy"
    except Exception:
        checks["database"] = "unhealthy"

    status = "ready" if all(v == "healthy" for v in checks.values()) else "not_ready"
    return {"status": status, "checks": checks}
```

## Graceful Shutdown

```python
# src/main.py
import signal

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    yield
    # Shutdown — cleanup resources
    logger.info("shutting_down")
    await engine.dispose()
    if hasattr(app.state, "redis"):
        await app.state.redis.close()
```

Gunicorn handles SIGTERM gracefully:
- Stops accepting new connections
- Waits for in-flight requests (up to `--graceful-timeout`)
- Shuts down workers

## Performance Checklist

- [ ] Workers = 2 × CPU + 1 (or 1 per K8s pod)
- [ ] Connection pool sized for worker count
- [ ] Health check endpoints for liveness + readiness
- [ ] Graceful shutdown configured
- [ ] Non-root user in Docker
- [ ] Multi-stage Docker build (smaller image)
- [ ] Resource limits in K8s
- [ ] HPA configured for auto-scaling
