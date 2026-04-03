# Dependency Injection

Advanced DI patterns for FastAPI: scoped, cached, service injection, and test overrides.

## When to Load
Designing complex dependency trees, injecting services, or overriding deps for testing.

## Dependency Types

| Type | Scope | Example |
|---|---|---|
| Simple | Per-call | `get_settings()` |
| Generator (yield) | Per-request, with cleanup | `get_db()` session |
| Cached | Once per app lifetime | `@lru_cache` settings |
| Class-based | Per-request, stateful | `UserService(repo, cache)` |
| Parameterized | Factory function | `require_role("admin")` |

## Service Injection Pattern

```python
# src/users/dependencies.py
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from src.core.dependencies import get_db
from src.users.repository import UserRepository
from src.users.service import UserService

def get_user_repository(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)

def get_user_service(repo: UserRepository = Depends(get_user_repository)) -> UserService:
    return UserService(repo)

# src/users/router.py
from src.users.dependencies import get_user_service

@router.get("/{user_id}")
async def get_user(
    user_id: int,
    service: UserService = Depends(get_user_service),
):
    return await service.get_user(user_id)
```

## Parameterized Dependencies

```python
# Role-based access
def require_role(*roles: str):
    async def dependency(user: User = Depends(get_current_user)):
        if user.role not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return user
    return dependency

# Permission-based access
def require_permission(permission: str):
    async def dependency(user: User = Depends(get_current_user)):
        if permission not in user.permissions:
            raise HTTPException(status_code=403, detail=f"Missing permission: {permission}")
        return user
    return dependency

# Usage
@router.delete("/{user_id}")
async def delete_user(
    user_id: int,
    admin: User = Depends(require_role("admin")),
    service: UserService = Depends(get_user_service),
):
    return await service.delete_user(user_id)
```

## Pagination Dependency

```python
from dataclasses import dataclass

@dataclass
class Pagination:
    skip: int = 0
    limit: int = 20

def get_pagination(skip: int = 0, limit: int = 20) -> Pagination:
    return Pagination(skip=min(skip, 10000), limit=min(limit, 100))

@router.get("/")
async def list_users(
    pagination: Pagination = Depends(get_pagination),
    service: UserService = Depends(get_user_service),
):
    return await service.list_users(pagination.skip, pagination.limit)
```

## Redis Cache Dependency

```python
# src/core/dependencies.py
import redis.asyncio as redis
from fastapi import Request

async def get_redis(request: Request) -> redis.Redis:
    return request.app.state.redis
```

## Test Overrides

```python
# tests/conftest.py
from src.core.dependencies import get_db
from src.core.database import Base

# Test database
TEST_DATABASE_URL = "postgresql+asyncpg://test:test@localhost:5432/test_db"
test_engine = create_async_engine(TEST_DATABASE_URL)
TestSession = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)

async def override_get_db():
    async with TestSession() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

@pytest.fixture
async def app():
    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    yield app
    app.dependency_overrides.clear()

# Override auth for testing
async def override_get_current_user():
    return User(id=1, email="test@example.com", role="admin")

@pytest.fixture
async def authenticated_client(app):
    app.dependency_overrides[get_current_user] = override_get_current_user
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
```

## Dependency Graph Visualization

```
get_user (route)
├── get_user_service
│   └── get_user_repository
│       └── get_db (session)
└── get_current_user (auth)
    ├── oauth2_scheme (token extraction)
    └── get_db (session)
```

FastAPI resolves shared dependencies once per request. `get_db` is called once even if multiple deps need it.

## Anti-Patterns

| Pattern | Problem | Fix |
|---|---|---|
| Global session object | Shared across requests → race conditions | Use `Depends(get_db)` per request |
| Business logic in dependencies | Hard to test, unclear responsibility | Keep deps thin, logic in services |
| Deep dependency chains (>4 levels) | Slow resolution, hard to debug | Flatten or use class-based injection |
| Not clearing overrides in tests | Test pollution across test cases | Use fixture with `app.dependency_overrides.clear()` |
