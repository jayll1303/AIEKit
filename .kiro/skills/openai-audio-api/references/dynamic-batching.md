# Dynamic Batching for Audio Inference

## Semaphore-based vs Dynamic Batching

| Scenario | Approach |
|----------|----------|
| Single GPU, low traffic | Semaphore-based (simple) |
| Single GPU, high traffic | Dynamic batching |
| Multi-GPU | Dynamic batching + device routing |
| CPU only | Semaphore-based (batching ít lợi ích trên CPU) |
| Streaming required | Semaphore-based (batching khó combine với streaming) |

## Dynamic Batcher Implementation

```python
import asyncio
import time
import threading
from dataclasses import dataclass, field
from collections import deque

@dataclass
class BatchItem:
    request: SynthesisRequest
    future: asyncio.Future
    created_at: float = field(default_factory=time.monotonic)

class DynamicBatcher:
    """Collect requests trong time window rồi batch cho inference."""

    def __init__(
        self,
        model_svc,
        max_batch_size: int = 8,
        batch_timeout_ms: float = 50.0,
        max_concurrent_batches: int = 2,
    ):
        self._model_svc = model_svc
        self._max_batch_size = max_batch_size
        self._batch_timeout = batch_timeout_ms / 1000.0
        self._queue: asyncio.Queue[BatchItem] = asyncio.Queue()
        self._semaphore = asyncio.Semaphore(max_concurrent_batches)
        self._running = False

    async def start(self):
        self._running = True
        asyncio.create_task(self._batch_loop())

    async def stop(self):
        self._running = False

    async def submit(self, req: SynthesisRequest) -> SynthesisResult:
        """Submit request, wait for result."""
        loop = asyncio.get_running_loop()
        future = loop.create_future()
        await self._queue.put(BatchItem(request=req, future=future))
        return await future

    async def _batch_loop(self):
        while self._running:
            batch = await self._collect_batch()
            if batch:
                asyncio.create_task(self._process_batch(batch))

    async def _collect_batch(self) -> list[BatchItem]:
        """Block-wait for first item, then collect more within timeout."""
        batch: list[BatchItem] = []
        try:
            first = await asyncio.wait_for(self._queue.get(), timeout=1.0)
            batch.append(first)
        except asyncio.TimeoutError:
            return []

        deadline = time.monotonic() + self._batch_timeout
        while len(batch) < self._max_batch_size:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            try:
                item = await asyncio.wait_for(self._queue.get(), timeout=remaining)
                batch.append(item)
            except asyncio.TimeoutError:
                break
        return batch

    async def _process_batch(self, batch: list[BatchItem]):
        async with self._semaphore:
            loop = asyncio.get_running_loop()
            try:
                results = await loop.run_in_executor(
                    None, self._run_batch_sync, batch
                )
                for item, result in zip(batch, results):
                    if isinstance(result, Exception):
                        item.future.set_exception(result)
                    else:
                        item.future.set_result(result)
            except Exception as e:
                for item in batch:
                    if not item.future.done():
                        item.future.set_exception(e)

    def _run_batch_sync(self, batch: list[BatchItem]) -> list:
        """Blocking batch inference in thread."""
        # If model supports native batching:
        # texts = [item.request.text for item in batch]
        # return model.generate_batch(texts=texts, ...)

        # Otherwise sequential in same thread (still reduces context switching):
        results = []
        for item in batch:
            try:
                result = self._single_inference(item.request)
                results.append(result)
            except Exception as e:
                results.append(e)
        return results
```

## Config Extension

```python
class Settings(BaseSettings):
    # ... base settings ...

    # Dynamic batching
    batch_enabled: bool = Field(default=False)
    max_batch_size: int = Field(default=8, ge=1, le=32)
    batch_timeout_ms: float = Field(default=50.0, ge=1.0, le=500.0)
    max_concurrent_batches: int = Field(default=2, ge=1, le=8)
```

## Lifespan Integration

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    cfg = app.state.cfg
    model_svc = ModelService(cfg)
    await model_svc.load()

    if cfg.batch_enabled:
        batcher = DynamicBatcher(
            model_svc=model_svc,
            max_batch_size=cfg.max_batch_size,
            batch_timeout_ms=cfg.batch_timeout_ms,
        )
        await batcher.start()
        app.state.batcher = batcher
    else:
        executor = ThreadPoolExecutor(max_workers=cfg.max_concurrent)
        app.state.inference_svc = InferenceService(model_svc, executor, cfg)

    yield

    if cfg.batch_enabled:
        await batcher.stop()
```

## Batch Metrics

```python
class BatchMetrics:
    def __init__(self):
        self._lock = threading.Lock()
        self.batches_processed = 0
        self.total_items = 0
        self._batch_sizes: deque[int] = deque(maxlen=200)
        self._wait_times: deque[float] = deque(maxlen=200)

    def record_batch(self, batch_size: int, wait_time_ms: float):
        with self._lock:
            self.batches_processed += 1
            self.total_items += batch_size
            self._batch_sizes.append(batch_size)
            self._wait_times.append(wait_time_ms)

    def snapshot(self) -> dict:
        with self._lock:
            sizes = list(self._batch_sizes)
            waits = list(self._wait_times)
        return {
            "batches_processed": self.batches_processed,
            "avg_batch_size": round(sum(sizes)/len(sizes), 1) if sizes else 0,
            "avg_wait_time_ms": round(sum(waits)/len(waits), 1) if waits else 0,
        }
```
