# Error Handling & Logging

Custom exceptions, global handlers, structlog JSON logging, and correlation IDs.

## When to Load
Setting up error handling, structured logging, or observability for production.

## Custom Exception Hierarchy

```python
# src/core/exceptions.py
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

class AppException(Exception):
    """Base exception for all application errors."""
    def __init__(self, message: str, status_code: int = 500, error_code: str = "INTERNAL_ERROR"):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code

class NotFoundError(AppException):
    def __init__(self, resource: str, id: str | int):
        super().__init__(
            message=f"{resource} with id '{id}' not found",
            status_code=404,
            error_code="NOT_FOUND",
        )

class ConflictError(AppException):
    def __init__(self, message: str):
        super().__init__(message=message, status_code=409, error_code="CONFLICT")

class ValidationError(AppException):
    def __init__(self, message: str):
        super().__init__(message=message, status_code=422, error_code="VALIDATION_ERROR")

class AuthenticationError(AppException):
    def __init__(self, message: str = "Authentication required"):
        super().__init__(message=message, status_code=401, error_code="UNAUTHORIZED")

class PermissionError(AppException):
    def __init__(self, message: str = "Insufficient permissions"):
        super().__init__(message=message, status_code=403, error_code="FORBIDDEN")
```

## Global Exception Handlers

```python
# src/core/exceptions.py (continued)
import structlog

logger = structlog.get_logger()

def register_exception_handlers(app: FastAPI):
    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException):
        logger.warning(
            "app_exception",
            error_code=exc.error_code,
            message=exc.message,
            status_code=exc.status_code,
            path=request.url.path,
            request_id=getattr(request.state, "request_id", None),
        )
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": exc.error_code,
                "message": exc.message,
            },
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        logger.error(
            "unhandled_exception",
            error=str(exc),
            error_type=type(exc).__name__,
            path=request.url.path,
            request_id=getattr(request.state, "request_id", None),
        )
        return JSONResponse(
            status_code=500,
            content={
                "error": "INTERNAL_ERROR",
                "message": "An unexpected error occurred",
            },
        )
```

## Structlog Configuration

```python
# src/core/logging.py
import structlog
import logging
from src.core.config import settings

def setup_logging():
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
    ]

    if settings.DEBUG:
        # Pretty console output for development
        renderer = structlog.dev.ConsoleRenderer()
    else:
        # JSON output for production (ELK, Datadog, etc.)
        renderer = structlog.processors.JSONRenderer()

    structlog.configure(
        processors=[
            *shared_processors,
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    formatter = structlog.stdlib.ProcessorFormatter(
        processors=[*shared_processors, renderer],
    )

    handler = logging.StreamHandler()
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.handlers = [handler]
    root_logger.setLevel(logging.INFO if not settings.DEBUG else logging.DEBUG)

    # Quiet noisy loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(
        logging.INFO if settings.DEBUG else logging.WARNING
    )
```

## Request Logging Middleware

```python
# src/core/middleware.py
import time
import structlog

logger = structlog.get_logger()

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.perf_counter()
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            request_id=getattr(request.state, "request_id", "unknown"),
            method=request.method,
            path=request.url.path,
        )

        response = await call_next(request)

        duration_ms = (time.perf_counter() - start_time) * 1000
        logger.info(
            "request_completed",
            status_code=response.status_code,
            duration_ms=round(duration_ms, 2),
        )
        return response
```

## Usage in Services

```python
import structlog

logger = structlog.get_logger()

class UserService:
    async def create_user(self, data: UserCreate) -> User:
        existing = await self.repo.get_by_email(data.email)
        if existing:
            logger.warning("user_already_exists", email=data.email)
            raise ConflictError(f"User with email '{data.email}' already exists")

        user = await self.repo.create(data)
        logger.info("user_created", user_id=user.id, email=user.email)
        return user
```

## Consistent Error Response Format

All errors return the same JSON structure:

```json
{
    "error": "NOT_FOUND",
    "message": "User with id '42' not found"
}
```

For validation errors (Pydantic):

```json
{
    "error": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
        {"field": "email", "message": "Invalid email format"}
    ]
}
```

## Health Check Endpoint

```python
@router.get("/health")
async def health_check(db: AsyncSession = Depends(get_db)):
    try:
        await db.execute(text("SELECT 1"))
        db_status = "healthy"
    except Exception:
        db_status = "unhealthy"
    return {
        "status": "healthy" if db_status == "healthy" else "degraded",
        "database": db_status,
        "version": settings.APP_VERSION,
    }
```
