---
name: fastapi-at-scale
description: "Build production-grade FastAPI at scale. Use when structuring projects, async SQLAlchemy, Alembic migrations, JWT auth, rate limiting, testing with httpx, deploying uvicorn/gunicorn/Docker."
---

# FastAPI at Scale

Production patterns for building, testing, and deploying FastAPI applications that handle thousands of concurrent requests. Covers domain-driven structure, async database access, authentication, background processing, and deployment.

## Scope

This skill handles:
- Domain-driven project structure for large FastAPI codebases
- Application factory pattern with lifespan events
- Async SQLAlchemy 2.0 session management and connection pooling
- Alembic async migrations
- Dependency injection patterns (scoped, cached, overridable)
- JWT/OAuth2 authentication and RBAC middleware
- Rate limiting, CORS, and security middleware
- Custom exception handling and structured logging (structlog)
- Background tasks (FastAPI BackgroundTasks, Celery + Redis)
- Redis caching patterns
- Testing with httpx AsyncClient, pytest-asyncio, dependency overrides
- Deployment with uvicorn workers, gunicorn, Docker, Kubernetes

Does NOT handle:
- Generic backend concepts (REST design, GraphQL, gRPC theory) (→ backend-development)
- ML model serving behind FastAPI (→ vllm-tgi-inference, triton-deployment)
- Audio/TTS API serving (→ openai-audio-api)
- Python project bootstrapping (uv, ruff, pyproject.toml) (→ python-project-setup)
- Docker GPU setup for ML workloads (→ docker-gpu-setup)
- Frontend/full-stack frameworks (Next.js, React) (→ web-frameworks)

## When to Use

- Starting a new FastAPI project and need production-ready structure
- Adding async SQLAlchemy + Alembic to an existing FastAPI app
- Implementing JWT authentication with role-based access control
- Setting up background task processing with Celery
- Writing async tests with httpx and pytest
- Deploying FastAPI to Docker/Kubernetes with proper worker config
- Diagnosing slow endpoints, connection pool exhaustion, or event loop blocking
- Adding structured logging and observability to FastAPI

## Project Structure Decision Table

| Project Size | Structure | When |
|---|---|---|
| Prototype / <5 routes | Flat (`main.py` + `models.py` + `schemas.py`) | Solo dev, quick iteration |
| Small app / 5-20 routes | Layer-based (`routers/`, `services/`, `models/`) | Small team, single domain |
| Medium app / 20-50 routes | Domain-driven (`src/auth/`, `src/users/`, `src/orders/`) | Multiple domains, 2-5 devs |
| Large app / 50+ routes | Domain-driven + shared kernel + event bus | Multiple teams, microservice candidate |

## Domain-Driven Structure (Recommended for Scale)

Key directories: `src/{domain}/` (router, schemas, models, service, dependencies), `src/core/` (config, database, security, middleware), `alembic/`, `tests/`, `docker/`.

> For full directory tree and app factory pattern, see [Project Structure](references/project-structure.md)

## Application Factory Quick Start

```python
# src/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.execute(text("SELECT 1"))
    yield
    await engine.dispose()

def create_app() -> FastAPI:
    app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)
    setup_middleware(app)
    register_exception_handlers(app)
    app.include_router(auth_router, prefix="/api/v1/auth", tags=["auth"])
    return app

app = create_app()
```

**Validate:** `uvicorn src.main:app --reload` starts without errors. `GET /docs` shows Swagger UI.

## Async Database Setup (SQLAlchemy 2.0)

```python
# src/core/database.py
engine = create_async_engine(
    settings.DATABASE_URL,  pool_size=20, max_overflow=10,
    pool_pre_ping=True, pool_recycle=3600,
)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

**Validate:** `await session.execute(text("SELECT 1"))` succeeds.

> For connection pool tuning, repository pattern, and Alembic async migrations, see [Database Patterns](references/database-patterns.md)

## Dependency Injection Quick Reference

```python
# Scoped (per-request)
async def get_db() -> AsyncSession: ...

# Cached (computed once per request)
async def get_current_user(token=Depends(oauth2_scheme), db=Depends(get_db)) -> User: ...

# Role-based
def require_role(*roles: str):
    async def checker(user: User = Depends(get_current_user)):
        if user.role not in roles:
            raise HTTPException(403, "Insufficient permissions")
        return user
    return checker
```

> For service injection, test overrides, and sub-dependencies, see [Dependency Injection](references/dependency-injection.md)

## Testing Quick Start

```python
@pytest.fixture
async def client():
    app = create_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac

@pytest.mark.anyio
async def test_login_success(client):
    response = await client.post("/api/v1/auth/login", json={"email": "user@example.com", "password": "securepassword"})
    assert response.status_code == 200
    assert "access_token" in response.json()
```

**Validate:** `pytest --tb=short` passes.

> For DB rollback fixtures, dependency overrides, and load testing, see [Testing Patterns](references/testing-patterns.md)

## Deployment Decision Table

| Scenario | Setup | Workers |
|---|---|---|
| Development | `uvicorn src.main:app --reload` | 1 |
| Single server, low traffic | `uvicorn src.main:app --workers 4` | CPU cores |
| Single server, production | `gunicorn src.main:app -k uvicorn.workers.UvicornWorker -w 4` | 2×CPU+1 |
| Docker container | Multi-stage Dockerfile + gunicorn | 2×CPU+1 |
| Kubernetes | 1 worker per pod, HPA scales pods | 1 per pod |

> For Dockerfile templates, K8s manifests, health checks, and graceful shutdown, see [Deployment & Scaling](references/deployment-scaling.md)

## Diagnostic Checklist

```
Slow endpoints?
├─ Event loop blocking?
│   ├─ Check: sync DB calls in async route → use async SQLAlchemy
│   ├─ Check: CPU-heavy code → offload to run_in_executor or Celery
│   └─ Check: sync file I/O → use aiofiles
│
├─ Connection pool exhaustion?
│   ├─ Symptom: "QueuePool limit reached" or timeouts
│   ├─ Fix: increase pool_size or max_overflow
│   ├─ Fix: ensure sessions are properly closed (use async with)
│   └─ Check: long-running transactions holding connections
│
├─ N+1 query problem?
│   ├─ Check: SQLAlchemy lazy loading in async context → use selectinload/joinedload
│   └─ Fix: eager load relationships in query
│
├─ Memory leak?
│   ├─ Check: sessions not closed → use get_db dependency properly
│   ├─ Check: large response objects cached in memory
│   └─ Profile: tracemalloc or memray
│
└─ High latency under load?
    ├─ Check: worker count (too few = queuing, too many = context switching)
    ├─ Check: missing Redis cache for hot paths
    └─ Check: missing DB indexes → EXPLAIN ANALYZE
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Sync SQLAlchemy works fine in FastAPI" | Sync DB calls block the event loop. Under 10+ concurrent requests, response times spike. ALWAYS use async SQLAlchemy with asyncpg/aiosqlite. |
| "I'll use `def` routes, FastAPI handles it" | `def` routes run in a threadpool — limited concurrency. Use `async def` for I/O-bound routes. Only use `def` for CPU-bound sync code. |
| "One worker is enough for Docker" | One worker = one event loop = one CPU core. Use `2×CPU+1` workers with gunicorn, or 1 worker per K8s pod with HPA. |
| "I'll add auth later" | Auth shapes your dependency tree. Adding it late means refactoring every route. Design auth dependencies from day one. |
| "BackgroundTasks is enough for everything" | BackgroundTasks runs in the same process — if the server restarts, tasks are lost. Use Celery + Redis for anything that must complete reliably. |
| "No need for structured logging" | `print()` and basic logging are unsearchable in production. Use structlog with JSON output for observability from the start. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need Python project setup (uv, ruff, pyproject.toml) | python-project-setup | Handles bootstrapping, linting, formatting |
| Need generic backend patterns (REST design, GraphQL) | backend-development | Covers cross-framework backend concepts |
| Deploying FastAPI in GPU Docker container | docker-gpu-setup | NVIDIA Container Toolkit, GPU passthrough |
| Adding type annotations and property-based testing | python-quality-testing | Hypothesis, mutation testing, type coverage |
| Serving ML models behind FastAPI | vllm-tgi-inference | LLM inference server patterns |
| Building OpenAI-compatible audio/TTS API | openai-audio-api | Concurrency, streaming, batching for audio inference |

## References

- [Project Structure](references/project-structure.md) — Domain-driven layout, app factory, Pydantic Settings, environment management
  **Load when:** starting a new FastAPI project or restructuring an existing one
- [Database Patterns](references/database-patterns.md) — Async SQLAlchemy 2.0, connection pooling, repository pattern, Alembic async migrations
  **Load when:** setting up database layer, writing migrations, or diagnosing pool exhaustion
- [Dependency Injection](references/dependency-injection.md) — Scoped/cached deps, service injection, sub-dependencies, test overrides
  **Load when:** designing complex dependency trees or overriding deps for testing
- [Auth & Middleware](references/auth-middleware.md) — JWT, OAuth2 password flow, RBAC, rate limiting, CORS, request ID middleware
  **Load when:** implementing authentication, authorization, or security middleware
- [Error Handling & Logging](references/error-handling-logging.md) — Custom exceptions, global handlers, structlog JSON logging, correlation IDs
  **Load when:** setting up error handling or structured logging/observability
- [Background Tasks](references/background-tasks.md) — FastAPI BackgroundTasks, Celery + Redis, task patterns, periodic tasks
  **Load when:** adding background processing, task queues, or scheduled jobs
- [Testing Patterns](references/testing-patterns.md) — httpx AsyncClient, pytest-asyncio, DB rollback, dependency overrides, mocking
  **Load when:** writing tests for FastAPI endpoints or setting up test infrastructure
- [Deployment & Scaling](references/deployment-scaling.md) — Uvicorn/Gunicorn workers, Docker multi-stage, K8s manifests, health checks, graceful shutdown
  **Load when:** deploying to production, configuring workers, or setting up K8s
