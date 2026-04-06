---
name: openai-audio-api
description: >
  Build OpenAI-compatible audio/speech APIs with FastAPI, dynamic batching,
  and streaming synthesis. Use when building TTS servers, audio inference
  APIs, or wrapping audio ML models behind HTTP.
---

# OpenAI-Compatible Audio API

Portable best practices for building OpenAI-compatible `/v1/audio/speech` APIs
with FastAPI, extracted from production omnivoice-server.

## Scope

This skill handles:
- OpenAI-compatible `/v1/audio/speech` API design
- Concurrency control (Semaphore + ThreadPoolExecutor)
- Dynamic batching for high-throughput GPU inference
- Sentence-level streaming with PCM output
- Adapter pattern to isolate upstream model changes
- Configuration via pydantic-settings
- Testing patterns (mock at service boundary)
- Production concerns (auth, health, metrics, memory cleanup)

Does NOT handle:
- Model training (→ hf-transformers-trainer)
- Model serving at scale for LLMs (→ vllm-tgi-inference)
- Docker/GPU setup (→ docker-gpu-setup)
- General FastAPI patterns (DB, auth, CRUD) (→ fastapi-at-scale)
- Speech-to-speech pipeline architecture (→ hf-speech-to-speech-pipeline)
- Python project bootstrapping (→ python-project-setup)

## When to Use

- Building a TTS/audio inference server with OpenAI-compatible API
- Wrapping any audio ML model (CosyVoice, Bark, XTTS, etc.) behind HTTP
- Need streaming audio synthesis (sentence-level PCM streaming)
- Need concurrency control for single-GPU audio inference
- Implementing dynamic batching for high-throughput audio workloads
- Adding OpenAI SDK drop-in compatibility (`tts-1`, `tts-1-hd` aliases)

## Architecture Decision Table

| Scenario | Approach | Key Pattern |
|----------|----------|-------------|
| Single GPU, low traffic | Semaphore + ThreadPool | `asyncio.Semaphore(N)` + `run_in_executor` |
| Single GPU, high traffic | Dynamic batching | Collect requests in time window, batch inference |
| Short text (<400 chars) | Non-streaming | Return complete WAV |
| Long text, real-time | Streaming | Split sentences → stream PCM chunks |
| Multiple model versions | Adapter pattern | Single seam isolates upstream changes |
| OpenAI SDK compatibility | Model aliases | Map `tts-1` → your model in `/v1/models` |

## Core Architecture

```
HTTP (routers/) → Auth Middleware → Service Layer (services/) → Utils (utils/) → Config
```

### Concurrency Invariant

```python
# workers=1 + ThreadPoolExecutor(N) + asyncio.Semaphore(N)
# Why: One model in VRAM. Multi-process = N copies of weights.
# Semaphore prevents > N concurrent inferences. ThreadPool unblocks event loop.
```

### Minimum Endpoints

```
POST /v1/audio/speech  — Main synthesis (OpenAI drop-in)
GET  /v1/models        — Model listing (OpenAI SDK needs this at init)
GET  /health           — Liveness check
GET  /metrics          — Request metrics
```

## Quick Start

To build an OpenAI-compatible audio API:

1. Create project structure per scaffold template
2. Implement `Settings` with pydantic-settings (env prefix, device auto-detect)
3. Implement `ModelService` with async loading + dtype fallback
4. Implement `InferenceService` with Semaphore + ThreadPool + Adapter
5. Implement routers: speech (streaming + non-streaming), models, health
6. Add auth middleware (Bearer token, skip for /health and /v1/models)
7. Wire everything in app factory with lifespan

**Validate:** `curl http://localhost:8880/v1/models` returns model list JSON.
**Validate:** `curl -X POST http://localhost:8880/v1/audio/speech -d '{"input":"Hello"}' --output test.wav` produces valid WAV.

## Troubleshooting

```
Request hangs / slow?
├─ All semaphore slots busy?
│   ├─ Check: max_concurrent setting vs actual GPU throughput
│   └─ Fix: increase max_concurrent or enable dynamic batching
├─ Event loop blocked?
│   ├─ Check: sync inference NOT in run_in_executor
│   └─ Fix: always use loop.run_in_executor for blocking inference
└─ Timeout (504)?
    └─ Fix: increase request_timeout_s or reduce text length

Audio quality issues?
├─ NaN in output tensors?
│   ├─ Check: dtype mismatch (float16 on CPU)
│   └─ Fix: use dtype fallback chain in ModelService
├─ Clicks between streaming chunks?
│   └─ Fix: split at sentence boundaries, not arbitrary char count
└─ Silent output?
    └─ Check: tensor_to_pcm16_bytes scaling (must clamp to int16 range)

Memory growing over time?
├─ Missing gc.collect() + empty_cache() after inference
└─ Fix: always cleanup in finally block of _run_sync
```

## Anti-Patterns

| Agent nghĩ | Thực tế |
|---|---|
| "Multiple uvicorn workers for throughput" | workers=1 is mandatory. Multiple workers = multiple model copies in VRAM. Use Semaphore for concurrency. |
| "Just split text every 400 chars" | Arbitrary splits break words/sentences → audio artifacts. Always split at sentence boundaries. |
| "No need for Adapter pattern" | Upstream ML libs change APIs frequently. Without adapter, every update breaks your server. |
| "Streaming is always better" | Short texts (<400 chars) are faster non-streaming. Only stream for long texts or real-time use cases. |
| "Mock the model in tests" | Mock at InferenceService.synthesize() boundary — tests the full HTTP layer without model weights. |

## Related Skills

| Situation | Activate Skill | Why |
|---|---|---|
| Need general FastAPI patterns (DB, auth, CRUD) | fastapi-at-scale | Covers non-audio FastAPI concerns |
| Need to download TTS model from Hub | hf-hub-datasets | Hub API patterns |
| Need Docker container with GPU | docker-gpu-setup | NVIDIA Container Toolkit |
| Building speech-to-speech pipeline | hf-speech-to-speech-pipeline | Queue-chained pipeline architecture |
| Need Python project setup (uv, ruff) | python-project-setup | Bootstrapping |
| Installing PyTorch/torchaudio with CUDA | python-ml-deps | CUDA index URLs, version conflicts |

## References

- [Architecture Guide](references/architecture.md) — Full layer architecture, concurrency model, adapter pattern, streaming, app factory
  **Load when:** implementing the server from scratch or understanding design decisions
- [Dynamic Batching](references/dynamic-batching.md) — Batcher implementation, config, metrics
  **Load when:** high-traffic scenario needs batching instead of simple semaphore
- [Project Scaffold](references/project-scaffold.md) — Directory structure, pyproject.toml, Dockerfile, docker-compose
  **Load when:** starting a new audio API project
- [Testing Patterns](references/testing-patterns.md) — conftest fixtures, mock strategies, test categories
  **Load when:** writing tests for audio API endpoints
- [Text Splitting](references/text-splitting.md) — Sentence splitting for streaming with false-boundary handling
  **Load when:** implementing streaming synthesis or debugging audio quality issues
