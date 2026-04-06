# Architecture Guide — OpenAI-Compatible Audio API

## 1. Layer Architecture

```
HTTP Surface (routers/) → Middleware (auth) → Service Layer (services/) → Utilities (utils/) → Config
```

| Layer | Responsibility | Does NOT do |
|-------|---------------|-------------|
| Routers | Parse request, format response, map errors → HTTP status | Business logic |
| Middleware | Auth gate, rate limiting | Routing |
| Services | Orchestrate inference, manage state, record metrics | HTTP concerns |
| Utilities | Pure functions (audio encoding, text splitting) | Side effects |
| Config | Single source of truth for all tunables | Domain logic |

## 2. Concurrency Model (Critical Decision)

```python
# INVARIANT: workers=1 + ThreadPoolExecutor(N) + asyncio.Semaphore(N)
#
# Why workers=1: One model in VRAM. Multi-process = N copies of weights.
# Why Semaphore: Prevents > N concurrent inferences. Queue forms in asyncio.
# Why ThreadPool: Unblocks event loop during blocking model inference.
# Why wait_for: Timeout protection → 504 Gateway Timeout.

import asyncio
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass

@dataclass
class SynthesisRequest:
    text: str
    mode: str  # "auto" | "design" | "clone"
    instruct: str | None = None
    ref_audio_path: str | None = None
    ref_text: str | None = None
    speed: float = 1.0
    num_step: int | None = None
    # Model-specific params as needed...

@dataclass
class SynthesisResult:
    tensors: list          # list[torch.Tensor], each (1, T)
    duration_s: float
    latency_s: float

class InferenceService:
    def __init__(self, model_svc, executor: ThreadPoolExecutor, cfg):
        self._model_svc = model_svc
        self._executor = executor
        self._cfg = cfg
        self._semaphore = asyncio.Semaphore(cfg.max_concurrent)
        self._adapter = ModelAdapter(cfg)

    async def synthesize(self, req: SynthesisRequest) -> SynthesisResult:
        loop = asyncio.get_running_loop()
        async with self._semaphore:
            result = await asyncio.wait_for(
                loop.run_in_executor(self._executor, self._run_sync, req),
                timeout=self._cfg.request_timeout_s,
            )
        return result

    def _run_sync(self, req: SynthesisRequest) -> SynthesisResult:
        """Blocking inference in thread pool thread."""
        import gc, time, torch
        t0 = time.monotonic()
        model = self._model_svc.model
        try:
            tensors = self._adapter.call(req, model)
        finally:
            # Post-inference memory cleanup (mitigates Torch memory growth)
            gc.collect()
            if self._cfg.device == "cuda":
                torch.cuda.empty_cache()
            elif self._cfg.device == "mps":
                torch.mps.empty_cache()

        duration_s = sum(t.shape[-1] for t in tensors) / 24_000
        return SynthesisResult(
            tensors=tensors,
            duration_s=duration_s,
            latency_s=time.monotonic() - t0,
        )
```

### What happens under load

```
1 request  → runs immediately
2 requests → both run simultaneously (N=2 default)
3 requests → req #3 suspends on semaphore, event loop stays live
N+k reqs   → k requests queue in asyncio, none rejected
             (until request_timeout_s exceeded → 504)
```

## 3. Adapter Pattern (Isolate Upstream Changes)

```python
class ModelAdapter:
    """Single seam between your server and the upstream ML library.
    When upstream adds/renames params, only this class changes."""

    def __init__(self, cfg):
        self._cfg = cfg

    def build_kwargs(self, req: SynthesisRequest, model) -> dict:
        kwargs = {
            "text": req.text,
            "num_step": req.num_step or self._cfg.num_step,
            # Map all request params → model.generate() kwargs here
        }
        if req.mode == "design" and req.instruct:
            kwargs["instruct"] = req.instruct
        elif req.mode == "clone" and req.ref_audio_path:
            kwargs["ref_audio"] = req.ref_audio_path
            if req.ref_text:
                kwargs["ref_text"] = req.ref_text
        return kwargs

    def call(self, req: SynthesisRequest, model):
        kwargs = self.build_kwargs(req, model)
        try:
            return model.generate(**kwargs)
        except TypeError as exc:
            # Graceful fallback if upstream renamed/removed params
            import logging
            logging.warning(f"model.generate() TypeError: {exc}. Falling back to minimal kwargs.")
            minimal = {"text": kwargs["text"], "num_step": kwargs.get("num_step", 16)}
            return model.generate(**minimal)
```

## 4. OpenAI-Compatible Endpoints

### Minimum required endpoints:

```python
# POST /v1/audio/speech — Main synthesis (OpenAI drop-in)
# GET  /v1/models       — Model listing (OpenAI SDK needs this at init)
# GET  /v1/models/{id}  — Model detail
# GET  /health          — Liveness check
# GET  /metrics         — Request metrics
```

### Request schema:

```python
from pydantic import BaseModel, Field
from typing import Literal

class SpeechRequest(BaseModel):
    model: str = Field(default="your-model")
    input: str = Field(..., min_length=1, max_length=10_000)
    voice: str = Field(default="auto")
    response_format: Literal["wav", "pcm"] = Field(default="wav")
    speed: float = Field(default=1.0, ge=0.25, le=4.0)
    stream: bool = Field(default=False)
    # Add model-specific params as needed
```

### Model aliases for drop-in compatibility:

```python
@router.get("/models")
async def list_models(request: Request):
    cfg = request.app.state.cfg
    return {
        "object": "list",
        "data": [
            {"id": "your-model", "object": "model", "owned_by": "your-org", ...},
            {"id": "tts-1", "object": "model", "parent": "your-model", ...},
            {"id": "tts-1-hd", "object": "model", "parent": "your-model", ...},
        ],
    }
```

## 5. Streaming Architecture

Sentence-level streaming reduces perceived latency:

```python
from fastapi.responses import StreamingResponse

@router.post("/audio/speech")
async def create_speech(body: SpeechRequest, ...):
    if body.stream:
        return StreamingResponse(
            _stream_sentences(body.input, req, inference_svc, metrics_svc, cfg),
            media_type="audio/pcm",
            headers={
                "X-Audio-Sample-Rate": "24000",
                "X-Audio-Channels": "1",
                "X-Audio-Bit-Depth": "16",
                "X-Audio-Format": "pcm-int16-le",
            },
        )
    # Non-streaming path...

async def _stream_sentences(text, base_req, inference_svc, metrics_svc, cfg):
    sentences = split_sentences(text, max_chars=cfg.stream_chunk_max_chars)
    for sentence in sentences:
        req = SynthesisRequest(text=sentence, mode=base_req.mode, ...)
        try:
            result = await inference_svc.synthesize(req)
            metrics_svc.record_success(result.latency_s)
            for tensor in result.tensors:
                yield tensor_to_pcm16_bytes(tensor)
        except (asyncio.TimeoutError, Exception):
            return  # Truncated but valid PCM stream
```

### Streaming vs Non-streaming

| | Non-streaming | Streaming |
|---|---|---|
| First audio byte | After full synthesis | After first sentence |
| Error recovery | HTTP 500/504 | Truncated stream (silent) |
| Use case | Batch, short texts | Real-time, long texts |

## 6. Configuration Pattern

```python
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="MYAPP_", env_file=".env")

    # Server
    host: str = "127.0.0.1"
    port: int = Field(default=8880, ge=1, le=65535)
    log_level: Literal["debug", "info", "warning", "error"] = "info"

    # Model
    model_id: str = "your-model-id"
    device: Literal["auto", "cuda", "mps", "cpu"] = "cpu"

    # Inference
    max_concurrent: int = Field(default=2, ge=1, le=16)
    request_timeout_s: int = 120

    # Auth
    api_key: str = ""  # Empty = no auth

    # Streaming
    stream_chunk_max_chars: int = 400

    @field_validator("device")
    @classmethod
    def resolve_auto_device(cls, v):
        if v != "auto": return v
        import torch
        if torch.cuda.is_available(): return "cuda"
        if torch.backends.mps.is_available(): return "mps"
        return "cpu"

    @property
    def torch_dtype(self):
        import torch
        return torch.float16 if self.device in ("cuda", "mps") else torch.float32
```

Priority: CLI flags > env vars > .env file > defaults

## 7. Model Loading Pattern

```python
class ModelService:
    async def load(self):
        """Load in thread — blocking op, must not block event loop."""
        loop = asyncio.get_running_loop()
        with ThreadPoolExecutor(max_workers=1) as ex:
            await loop.run_in_executor(ex, self._load_sync)

    def _load_sync(self):
        for dtype in self._dtype_candidates():
            try:
                model = YourModel.from_pretrained(self.cfg.model_id, dtype=dtype)
                test = model.generate(text="test", num_step=4)
                if self._has_nan(test): continue  # NaN detection
                self._model = model
                break
            except Exception: continue
        if self._model is None:
            raise RuntimeError("Failed to load model on all dtype candidates")
```

## 8. Audio Encoding Utilities

```python
import io, torch, torchaudio

SAMPLE_RATE = 24_000

def tensor_to_wav_bytes(tensor: torch.Tensor) -> bytes:
    """(1, T) float32 → 16-bit PCM WAV bytes."""
    buf = io.BytesIO()
    torchaudio.save(buf, tensor.cpu().unsqueeze(0) if tensor.dim() == 1 else tensor.cpu(),
                    SAMPLE_RATE, format="wav", encoding="PCM_S", bits_per_sample=16)
    buf.seek(0)
    return buf.read()

def tensor_to_pcm16_bytes(tensor: torch.Tensor) -> bytes:
    """(1, T) float32 → raw PCM int16 bytes (streaming, no WAV header)."""
    flat = tensor.squeeze(0).cpu()
    return (flat * 32767).clamp(-32768, 32767).to(torch.int16).numpy().tobytes()

def tensors_to_wav_bytes(tensors: list[torch.Tensor]) -> bytes:
    """Concatenate multiple tensors → single WAV."""
    combined = torch.cat([t.cpu() for t in tensors], dim=-1)
    return tensor_to_wav_bytes(combined)
```

## 9. App Factory + Lifespan

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

@asynccontextmanager
async def lifespan(app: FastAPI):
    cfg = app.state.cfg
    # Startup
    model_svc = ModelService(cfg)
    await model_svc.load()
    app.state.model_svc = model_svc
    executor = ThreadPoolExecutor(max_workers=cfg.max_concurrent)
    app.state.inference_svc = InferenceService(model_svc, executor, cfg)
    app.state.metrics_svc = MetricsService()
    app.state.start_time = time.monotonic()
    yield
    # Shutdown
    executor.shutdown(wait=False)

def create_app(cfg: Settings) -> FastAPI:
    app = FastAPI(title="my-audio-server", lifespan=lifespan)
    app.state.cfg = cfg

    if cfg.api_key:
        @app.middleware("http")
        async def auth_middleware(request: Request, call_next):
            if request.url.path in ("/health", "/metrics", "/v1/models"):
                return await call_next(request)
            auth = request.headers.get("Authorization", "")
            if auth != f"Bearer {cfg.api_key}":
                return JSONResponse(status_code=401, content={"error": "Invalid API key"})
            return await call_next(request)

    app.include_router(speech_router, prefix="/v1")
    app.include_router(models_router, prefix="/v1")
    app.include_router(health_router)
    return app
```

## 10. Error Taxonomy

| Code | When |
|------|------|
| 401 | Wrong/missing Bearer token |
| 404 | Resource not found (profile, model) |
| 409 | Conflict (resource already exists) |
| 422 | Pydantic validation failure |
| 500 | Unexpected inference error |
| 504 | Timeout (request_timeout_s exceeded) |

## 11. Metrics Service

```python
import threading
from collections import deque

class MetricsService:
    def __init__(self, latency_window: int = 200):
        self._lock = threading.Lock()
        self.total = self.success = self.error = self.timeout = 0
        self._latencies: deque[float] = deque(maxlen=latency_window)

    def record_success(self, latency_s: float):
        with self._lock:
            self.total += 1; self.success += 1
            self._latencies.append(latency_s * 1000)

    def record_error(self):
        with self._lock: self.total += 1; self.error += 1

    def record_timeout(self):
        with self._lock: self.total += 1; self.timeout += 1

    def snapshot(self) -> dict:
        with self._lock: lats = list(self._latencies)
        return {
            "requests_total": self.total,
            "mean_latency_ms": round(sum(lats)/len(lats), 1) if lats else 0,
            "p95_latency_ms": round(sorted(lats)[int(len(lats)*0.95)], 1) if lats else 0,
        }
```
