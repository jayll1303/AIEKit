# Testing Patterns

httpx AsyncClient, pytest-asyncio, DB rollback, dependency overrides, and mocking.

## When to Load
Writing tests for FastAPI endpoints or setting up test infrastructure.

## Test Stack

```bash
pip install pytest pytest-anyio httpx respx
```

| Package | Purpose |
|---|---|
| `pytest` | Test runner |
| `pytest-anyio` | Async test support (replaces pytest-asyncio) |
| `httpx` | Async HTTP client for testing |
| `respx` | Mock external HTTP calls |
| `factory-boy` | Test data factories |

## Core Fixtures

```python
# tests/conftest.py
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from src.main import create_app
from src.core.database import Base, get_db

TEST_DATABASE_URL = "postgresql+asyncpg://test:test@localhost:5432/test_db"

test_engine = create_async_engine(TEST_DATABASE_URL)
TestSession = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)

@pytest.fixture(scope="session", autouse=True)
async def setup_database():
    """Create tables once for entire test session."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await test_engine.dispose()

@pytest.fixture
async def db_session():
    """Per-test session with transaction rollback."""
    async with test_engine.connect() as conn:
        trans = await conn.begin()
        session = AsyncSession(bind=conn, expire_on_commit=False)
        try:
            yield session
        finally:
            await trans.rollback()
            await session.close()

@pytest.fixture
async def app(db_session):
    """App with test DB override."""
    app = create_app()
    async def override_get_db():
        yield db_session
    app.dependency_overrides[get_db] = override_get_db
    yield app
    app.dependency_overrides.clear()

@pytest.fixture
async def client(app):
    """Async HTTP client."""
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac
```

## Authenticated Client Fixture

```python
from src.auth.dependencies import get_current_user
from src.users.models import User

@pytest.fixture
async def authenticated_client(app):
    """Client with mocked authentication."""
    mock_user = User(id=1, email="test@example.com", role="user", is_active=True)
    app.dependency_overrides[get_current_user] = lambda: mock_user
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac

@pytest.fixture
async def admin_client(app):
    """Client with admin role."""
    mock_admin = User(id=1, email="admin@example.com", role="admin", is_active=True)
    app.dependency_overrides[get_current_user] = lambda: mock_admin
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac
```

## Test Examples

### Route Tests

```python
# tests/users/test_routes.py
import pytest

@pytest.mark.anyio
async def test_create_user(client):
    response = await client.post("/api/v1/users/", json={
        "email": "new@example.com",
        "password": "StrongPass123",
    })
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "new@example.com"
    assert "id" in data
    assert "password" not in data  # Never expose password

@pytest.mark.anyio
async def test_create_user_duplicate_email(client, db_session):
    # Seed existing user
    user = User(email="existing@example.com", hashed_password="hashed")
    db_session.add(user)
    await db_session.flush()

    response = await client.post("/api/v1/users/", json={
        "email": "existing@example.com",
        "password": "StrongPass123",
    })
    assert response.status_code == 409

@pytest.mark.anyio
async def test_get_user_unauthorized(client):
    response = await client.get("/api/v1/users/me")
    assert response.status_code == 401

@pytest.mark.anyio
async def test_get_user_authenticated(authenticated_client):
    response = await authenticated_client.get("/api/v1/users/me")
    assert response.status_code == 200
    assert response.json()["email"] == "test@example.com"
```

### Service Tests (Unit)

```python
# tests/users/test_service.py
import pytest
from unittest.mock import AsyncMock
from src.users.service import UserService
from src.users.schemas import UserCreate

@pytest.mark.anyio
async def test_create_user_service():
    mock_repo = AsyncMock()
    mock_repo.get_by_email.return_value = None
    mock_repo.create.return_value = User(id=1, email="test@example.com")

    service = UserService(repo=mock_repo)
    result = await service.create_user(UserCreate(email="test@example.com", password="pass"))

    assert result.email == "test@example.com"
    mock_repo.create.assert_called_once()
```

## Mocking External Services

```python
# tests/test_external.py
import respx
from httpx import Response

@pytest.mark.anyio
@respx.mock
async def test_external_api_call(client):
    # Mock external API
    respx.get("https://api.external.com/data").mock(
        return_value=Response(200, json={"result": "ok"})
    )
    response = await client.get("/api/v1/external-data")
    assert response.status_code == 200
```

## Test Configuration

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
filterwarnings = ["ignore::DeprecationWarning"]

[tool.coverage.run]
source = ["src"]
omit = ["src/core/celery_app.py", "*/migrations/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
```

## Running Tests

```bash
# Run all tests
pytest -v

# Run with coverage
pytest --cov=src --cov-report=term-missing

# Run specific domain
pytest tests/users/ -v

# Run single test
pytest tests/users/test_routes.py::test_create_user -v

# Parallel execution
pytest -n auto  # requires pytest-xdist
```

## Test Organization

```
tests/
├── conftest.py              # Shared fixtures (db, client, auth)
├── auth/
│   ├── test_routes.py       # Auth endpoint tests
│   └── test_service.py      # Auth service unit tests
├── users/
│   ├── test_routes.py       # User endpoint tests
│   ├── test_service.py      # User service unit tests
│   └── test_repository.py   # Repository integration tests
└── core/
    ├── test_middleware.py    # Middleware tests
    └── test_exceptions.py   # Exception handler tests
```
