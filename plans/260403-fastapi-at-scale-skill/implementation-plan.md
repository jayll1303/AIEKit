# FastAPI at Scale Skill — Implementation Plan

## Objective
Create a comprehensive Kiro skill for building production-grade FastAPI applications at scale.

## Scope
- Domain-driven project structure
- Async SQLAlchemy 2.0 + Alembic migrations
- Dependency injection patterns
- Authentication/authorization middleware
- Error handling & structured logging
- Background tasks (Celery + Redis)
- Caching strategies (Redis)
- Testing (httpx, pytest-asyncio, dependency overrides)
- Deployment (uvicorn workers, gunicorn, Docker, K8s)
- Performance optimization & observability

## Deliverables

### 1. SKILL.md (~280 lines)
- Frontmatter with pushy description
- Scope boundaries (does NOT overlap with backend-development generic skill)
- Decision tables for project structure, DB, deployment
- Core workflows with validation gates
- Troubleshooting flowchart
- Anti-patterns table
- Cross-references to related skills

### 2. References (load on demand)
- `project-structure.md` — Domain-driven structure, app factory, settings
- `database-patterns.md` — Async SQLAlchemy 2.0, Alembic, connection pooling, repository pattern
- `dependency-injection.md` — DI patterns, scoped deps, testing overrides
- `auth-middleware.md` — JWT, OAuth2, RBAC, rate limiting, CORS
- `error-handling-logging.md` — Custom exceptions, structured logging, observability
- `background-tasks.md` — BackgroundTasks, Celery+Redis, task patterns
- `testing-patterns.md` — httpx AsyncClient, pytest fixtures, DB rollback, mocking
- `deployment-scaling.md` — Uvicorn/Gunicorn workers, Docker, K8s, health checks

### 3. Interconnection Map Update
- Add fastapi-at-scale to Application layer
- Dependencies: python-project-setup, docker-gpu-setup (optional)
- Reverse: backend-development scope boundary update (optional)

### 4. README.md Update
- Add skill to table (skill count 25→26)

## Status
- [x] SKILL.md (229 lines)
- [x] References (8 files, all <300 lines)
- [x] Interconnection map update (layer + dependency matrix + workflow chain 7)
- [x] README update (skill count 26, table entry added)
