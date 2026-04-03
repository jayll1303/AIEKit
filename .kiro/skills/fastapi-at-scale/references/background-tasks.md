# Background Tasks

FastAPI BackgroundTasks, Celery + Redis integration, and task patterns.

## When to Load
Adding background processing, task queues, or scheduled jobs.

## Task Strategy Decision Table

| Scenario | Solution | Why |
|---|---|---|
| Quick fire-and-forget (<1s) | `BackgroundTasks` | Built-in, no infra needed |
| Must complete even if server restarts | Celery + Redis | Persistent queue, retries |
| Periodic/scheduled tasks | Celery Beat | Cron-like scheduling |
| CPU-heavy computation | Celery worker | Separate process, no event loop blocking |
| Fan-out to multiple consumers | Celery + RabbitMQ | Message broker with routing |

## FastAPI BackgroundTasks

```python
from fastapi import BackgroundTasks

async def send_welcome_email(email: str):
    # Simulate email sending
    await asyncio.sleep(2)
    logger.info("welcome_email_sent", email=email)

@router.post("/register")
async def register(
    data: UserCreate,
    background_tasks: BackgroundTasks,
    service: UserService = Depends(get_user_service),
):
    user = await service.create_user(data)
    background_tasks.add_task(send_welcome_email, user.email)
    return {"id": user.id, "message": "User created"}
```

⚠️ **Limitation:** BackgroundTasks run in the same process. If the server restarts, pending tasks are lost. Use only for non-critical, fast tasks.

## Celery + Redis Setup

### Installation

```bash
pip install celery[redis] redis
```

### Celery Configuration

```python
# src/core/celery_app.py
from celery import Celery
from src.core.config import settings

celery_app = Celery(
    "worker",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,           # Acknowledge after completion (reliability)
    worker_prefetch_multiplier=1,  # One task at a time per worker
    result_expires=3600,           # Results expire after 1 hour
)

# Auto-discover tasks from all domains
celery_app.autodiscover_tasks(["src.users", "src.orders", "src.notifications"])
```

### Task Definition

```python
# src/users/tasks.py
from src.core.celery_app import celery_app

@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=60,
    acks_late=True,
)
def send_verification_email(self, user_id: int, email: str):
    try:
        # Email sending logic
        send_email(to=email, template="verification", context={"user_id": user_id})
    except Exception as exc:
        self.retry(exc=exc)

@celery_app.task(bind=True, max_retries=5)
def process_large_upload(self, file_path: str, user_id: int):
    try:
        # Heavy processing
        result = process_file(file_path)
        save_result(user_id, result)
    except Exception as exc:
        self.retry(exc=exc, countdown=2 ** self.request.retries)  # Exponential backoff
```

### Calling Tasks from FastAPI

```python
# src/users/router.py
from src.users.tasks import send_verification_email

@router.post("/register")
async def register(data: UserCreate, service: UserService = Depends(get_user_service)):
    user = await service.create_user(data)
    # Dispatch to Celery (non-blocking)
    send_verification_email.delay(user.id, user.email)
    return {"id": user.id, "message": "User created, verification email queued"}
```

### Task Status Tracking

```python
# src/tasks/router.py
from celery.result import AsyncResult
from src.core.celery_app import celery_app

@router.get("/tasks/{task_id}")
async def get_task_status(task_id: str):
    result = AsyncResult(task_id, app=celery_app)
    return {
        "task_id": task_id,
        "status": result.status,
        "result": result.result if result.ready() else None,
    }
```

### Periodic Tasks (Celery Beat)

```python
# src/core/celery_app.py
from celery.schedules import crontab

celery_app.conf.beat_schedule = {
    "cleanup-expired-tokens": {
        "task": "src.auth.tasks.cleanup_expired_tokens",
        "schedule": crontab(hour=2, minute=0),  # Daily at 2 AM
    },
    "generate-daily-report": {
        "task": "src.reports.tasks.generate_daily_report",
        "schedule": crontab(hour=6, minute=0),
    },
}
```

### Running Workers

```bash
# Start Celery worker
celery -A src.core.celery_app worker --loglevel=info --concurrency=4

# Start Celery Beat (scheduler)
celery -A src.core.celery_app beat --loglevel=info

# Combined (dev only)
celery -A src.core.celery_app worker --beat --loglevel=info
```

## Docker Compose for Celery

```yaml
# docker-compose.yml
services:
  api:
    build: .
    command: gunicorn src.main:app -k uvicorn.workers.UvicornWorker -w 4 -b 0.0.0.0:8000
    depends_on: [redis, postgres]

  celery-worker:
    build: .
    command: celery -A src.core.celery_app worker --loglevel=info --concurrency=4
    depends_on: [redis, postgres]

  celery-beat:
    build: .
    command: celery -A src.core.celery_app beat --loglevel=info
    depends_on: [redis]

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    ports: ["5432:5432"]
```

## Troubleshooting

```
Tasks not executing?
├─ Worker not running → check `celery -A src.core.celery_app worker` is up
├─ Redis not reachable → check REDIS_URL and `redis-cli ping`
├─ Task not discovered → check autodiscover_tasks includes the module
└─ Task stuck in PENDING → check worker logs for import errors
```
