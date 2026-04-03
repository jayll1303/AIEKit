# Project Structure

Domain-driven layout, application factory, and configuration management for production FastAPI.

## When to Load
Starting a new FastAPI project or restructuring an existing one for scale.

## Pydantic Settings

```python
# src/core/config.py
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    APP_NAME: str = "MyAPI"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://user:pass@localhost:5432/mydb"
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 10

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Auth
    SECRET_KEY: str = "change-me-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ALGORITHM: str = "HS256"

    # CORS
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}

@lru_cache
def get_settings() -> Settings:
    return Settings()

settings = get_settings()
```

## Environment Files

```bash
# .env.example — commit this, NEVER commit .env
APP_NAME=MyAPI
DEBUG=false
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/mydb
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=generate-with-openssl-rand-hex-32
ALLOWED_ORIGINS=["https://myapp.com"]
```

## Domain Module Template

Each domain follows the same internal structure:

```
src/users/
├── router.py          # HTTP layer — routes, request parsing, response formatting
├── schemas.py         # Pydantic models — request/response validation
├── models.py          # SQLAlchemy ORM models — database table definitions
├── service.py         # Business logic — orchestrates repository + external calls
├── repository.py      # Data access — raw DB queries, no business logic
├── dependencies.py    # FastAPI Depends — domain-specific injections
└── exceptions.py      # Domain exceptions — UserNotFoundError, etc.
```

### Layer responsibilities

| Layer | Knows about | Does NOT know about |
|---|---|---|
| router.py | schemas, service, dependencies | SQLAlchemy models, raw SQL |
| service.py | repository, schemas, external APIs | HTTP request/response, FastAPI |
| repository.py | SQLAlchemy models, session | Business rules, HTTP |
| schemas.py | Pydantic only | SQLAlchemy, business logic |

### Example: users/service.py

```python
from src.users.repository import UserRepository
from src.users.schemas import UserCreate, UserResponse

class UserService:
    def __init__(self, repo: UserRepository):
        self.repo = repo

    async def create_user(self, data: UserCreate) -> UserResponse:
        # Business logic: check duplicates, hash password, etc.
        existing = await self.repo.get_by_email(data.email)
        if existing:
            raise UserAlreadyExistsError(data.email)
        user = await self.repo.create(data)
        return UserResponse.model_validate(user)
```

### Example: users/repository.py

```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from src.users.models import User

class UserRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_email(self, email: str) -> User | None:
        result = await self.session.execute(
            select(User).where(User.email == email)
        )
        return result.scalar_one_or_none()

    async def create(self, data) -> User:
        user = User(**data.model_dump())
        self.session.add(user)
        await self.session.flush()
        return user
```

## Shared Core Module

`src/core/` contains cross-cutting concerns shared by all domains:

| File | Purpose |
|---|---|
| `config.py` | Pydantic Settings, environment loading |
| `database.py` | Async engine, session factory, Base |
| `dependencies.py` | `get_db`, `get_redis`, `get_settings` |
| `exceptions.py` | Base exception classes + global handlers |
| `logging.py` | Structlog configuration |
| `middleware.py` | CORS, rate limiting, request ID |
| `security.py` | JWT encode/decode, password hashing |

## API Versioning

```python
# src/main.py
from fastapi import APIRouter

v1_router = APIRouter(prefix="/api/v1")
v1_router.include_router(auth_router, prefix="/auth", tags=["auth"])
v1_router.include_router(users_router, prefix="/users", tags=["users"])

app.include_router(v1_router)

# When v2 is needed:
v2_router = APIRouter(prefix="/api/v2")
v2_router.include_router(users_v2_router, prefix="/users", tags=["users-v2"])
app.include_router(v2_router)
```

## Lifespan Events

```python
from contextlib import asynccontextmanager
import redis.asyncio as redis

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    app.state.redis = redis.from_url(settings.REDIS_URL)
    async with engine.begin() as conn:
        await conn.execute(text("SELECT 1"))  # Validate DB connection
    yield
    # Shutdown
    await app.state.redis.close()
    await engine.dispose()
```

**Validate:** App starts without errors. `GET /docs` shows all versioned routes. `GET /health` returns 200.
