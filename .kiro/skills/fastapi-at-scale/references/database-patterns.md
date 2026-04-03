# Database Patterns

Async SQLAlchemy 2.0, connection pooling, repository pattern, and Alembic async migrations.

## When to Load
Setting up database layer, writing migrations, or diagnosing connection pool issues.

## Async Engine Configuration

```python
# src/core/database.py
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from src.core.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=settings.DB_POOL_SIZE,       # Default: 20
    max_overflow=settings.DB_MAX_OVERFLOW,  # Default: 10
    pool_pre_ping=True,                     # Detect stale connections
    pool_recycle=3600,                      # Recycle after 1 hour
    echo=settings.DEBUG,                    # SQL logging in debug mode
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,  # Prevent lazy load after commit
)

class Base(DeclarativeBase):
    pass
```

## Pool Sizing Guide

| Metric | Formula | Example (4 workers, 50 concurrent) |
|---|---|---|
| pool_size | concurrent_requests / workers | 50 / 4 ≈ 13 → 15 |
| max_overflow | pool_size × 0.5 | 15 × 0.5 ≈ 8 |
| Total max connections | (pool_size + max_overflow) × workers | (15 + 8) × 4 = 92 |
| PostgreSQL max_connections | Total + 10 headroom | 102 |

⚠️ **HARD GATE:** Total max connections across all workers MUST NOT exceed PostgreSQL `max_connections`. Check: `SHOW max_connections;`

## Session Dependency

```python
# src/core/dependencies.py
from src.core.database import AsyncSessionLocal

async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

## Model Patterns

```python
# src/core/models.py — Base mixin for all models
from datetime import datetime
from sqlalchemy import func
from sqlalchemy.orm import Mapped, mapped_column

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(), onupdate=func.now()
    )

# src/users/models.py
from sqlalchemy import String, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from src.core.database import Base
from src.core.models import TimestampMixin

class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    role: Mapped[str] = mapped_column(String(50), default="user")

    # Relationships
    posts: Mapped[list["Post"]] = relationship(back_populates="author", lazy="selectin")
```

## Relationship Loading Strategies

| Strategy | When | Code |
|---|---|---|
| `selectinload` | One-to-many, moderate data | `options(selectinload(User.posts))` |
| `joinedload` | One-to-one, small related data | `options(joinedload(User.profile))` |
| `subqueryload` | Many-to-many, large datasets | `options(subqueryload(User.roles))` |
| `lazyload` | NEVER in async | Raises `MissingGreenlet` error |

```python
# Correct: eager load in async
result = await session.execute(
    select(User)
    .where(User.id == user_id)
    .options(selectinload(User.posts))
)
user = result.scalar_one_or_none()
```

## Repository Pattern

```python
# src/core/repository.py — Generic base
from typing import TypeVar, Generic, Type
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

ModelType = TypeVar("ModelType")

class BaseRepository(Generic[ModelType]):
    def __init__(self, session: AsyncSession, model: Type[ModelType]):
        self.session = session
        self.model = model

    async def get_by_id(self, id: int) -> ModelType | None:
        return await self.session.get(self.model, id)

    async def get_all(self, skip: int = 0, limit: int = 100) -> list[ModelType]:
        result = await self.session.execute(
            select(self.model).offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def create(self, obj: ModelType) -> ModelType:
        self.session.add(obj)
        await self.session.flush()
        return obj

    async def delete(self, obj: ModelType) -> None:
        await self.session.delete(obj)

    async def count(self) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(self.model)
        )
        return result.scalar_one()
```

## Alembic Async Setup

### Initialize

```bash
alembic init -t async alembic
```

### Configure env.py

```python
# alembic/env.py
from src.core.database import Base, engine
from src.core.config import settings

# Import ALL models so Alembic sees them
from src.users.models import User  # noqa
from src.auth.models import RefreshToken  # noqa

target_metadata = Base.metadata

async def run_async_migrations():
    async with engine.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await engine.dispose()

def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()
```

### Common Commands

```bash
# Generate migration from model changes
alembic revision --autogenerate -m "add users table"

# Apply all pending migrations
alembic upgrade head

# Rollback one migration
alembic downgrade -1

# Show current revision
alembic current

# Show migration history
alembic history --verbose
```

**Validate:** `alembic upgrade head` completes without errors. `alembic current` shows latest revision.

## Troubleshooting

```
Connection pool exhaustion?
├─ Symptom: "QueuePool limit of X overflow Y reached"
│   ├─ Check: sessions not closed → ensure get_db uses `async with`
│   ├─ Check: long transactions → add query timeout
│   ├─ Fix: increase pool_size and max_overflow
│   └─ Fix: add pool_timeout=30 to engine config
│
├─ MissingGreenlet error?
│   ├─ Cause: lazy loading in async context
│   └─ Fix: use selectinload/joinedload in query options
│
└─ Alembic can't detect changes?
    ├─ Check: all models imported in env.py
    ├─ Check: target_metadata = Base.metadata
    └─ Check: model inherits from correct Base class
```
