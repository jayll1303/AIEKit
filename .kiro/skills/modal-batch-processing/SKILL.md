---
name: modal-batch-processing
description: >-
  Modal job orchestration with .map, .starmap, .spawn, .spawn_map, @modal.batched.
  Use when fanning out work, polling job IDs, capping concurrency, or batching GPU calls.
license: MIT
---

# Modal Batch Processing

Fan out work across Modal containers, collect results, and batch requests into fewer GPU calls.

## Scope

This skill handles: Modal `.map`, `.starmap`, `.spawn`, `.spawn_map`, `@modal.batched`, concurrency caps, partial failure recovery, job polling, detached runs, and `Function.with_options()` / `Function.with_batching()` runtime overrides.

Does NOT handle:
- vLLM/SGLang/TGI model serving (→ vllm-tgi-inference, → sglang-serving)
- Model fine-tuning or training (→ hf-transformers-trainer, → unsloth-training)
- Sandbox lifecycle, tunnels, interactive exec (→ modal-sandbox)

## When to Use

- Caller waits for parallel results: `.map` / `.starmap` fan-out
- Caller returns immediately, polls later: `.spawn` with job ID
- Detached fire-and-forget writes to Volume/DB: `.spawn_map`
- Many small requests batched into fewer GPU calls: `@modal.batched`
- Need to cap concurrency with `max_containers=`

## Quick Start

1. Verify the actual local Modal environment before writing code.

```bash
modal --version
python -c "import modal,sys; print(modal.__version__); print(sys.executable)"
modal profile current
```

- Do not assume the default `python` interpreter matches the `modal` CLI environment.
- Minimum supported SDK: 1.4.0. `Function.with_options()`, `Function.with_batching()`, regional routing require 1.4.3+.

2. Classify the request before writing code.

| Scenario | API | Reference |
|----------|-----|-----------|
| Caller waits, needs results back | `.map` / `.starmap` | [map-and-gather.md](references/map-and-gather.md) |
| Caller returns immediately, polls later | `.spawn` | [job-queues-and-detached-runs.md](references/job-queues-and-detached-runs.md) |
| Detached fan-out, writes results externally | `.spawn_map` | [job-queues-and-detached-runs.md](references/job-queues-and-detached-runs.md) |
| Many small requests → fewer GPU calls | `@modal.batched` | [dynamic-batching.md](references/dynamic-batching.md) |

3. Read exactly one primary reference before drafting code.

## Default Rules

- Start with `@app.function` for stateless work. Use `@app.cls` only when container must reuse loaded state.
- Keep orchestration local with `@app.local_entrypoint` or `with app.run():` when workflow fits one session.
- Deploy with `modal deploy` + `modal.Function.from_name(...)` when another service submits jobs.
- Set `timeout=` intentionally. Add `retries=` only for idempotent work.
- Set `max_containers=` for GPU quotas or external API rate limits.
- Persist outputs externally for detached work or `.spawn_map`.
- Use Volumes/CloudBucketMounts for durable caches; do not rely on ephemeral container disk.
- Use `Function.with_options()` to override GPU/CPU/memory/timeout at call time (no redeploy).
- Use `routing_region=` for latency or data residency (SDK 1.4.3+, Public Beta).
- Exceptions from `.map()`/`.starmap()` are no longer wrapped in `UserCodeException` (SDK 1.4.0+).
- Use `modal app rollover` to trigger redeployment without code changes (SDK 1.4.2+).

## Anti-Patterns

| Agent thinks | Reality |
|---|---|
| "Use `.spawn_map` and collect results later" | `.spawn_map` is fire-and-forget — no programmatic result retrieval. Use `.spawn` for polling. |
| "Default timeout is fine" | No explicit timeout = stuck containers burning credits. Always set `timeout=`. |
| "Just use `@app.cls` for everything" | `@app.cls` adds cold-start overhead. Use plain `@app.function` for stateless work. |
| "Skip environment check, just write code" | Wrong interpreter = ImportError at runtime. Always verify `modal --version` first. |
| "Use `.map` for background jobs" | `.map` blocks the caller. Use `.spawn` when caller should return immediately. |

## Validate

- Run `npx skills add . --list` after editing package metadata.
- Keep `evals/evals.json` and `evals/trigger-evals.json` aligned with workflow boundary.
- Run [scripts/smoke_test.py](scripts/smoke_test.py) with a Python interpreter that can import `modal`.

## References

- [map-and-gather.md](references/map-and-gather.md) — Synchronous fan-out, in-process result collection
  **Load when:** Using `.map` or `.starmap`
- [job-queues-and-detached-runs.md](references/job-queues-and-detached-runs.md) — Job IDs, polling, detached runs, external sinks
  **Load when:** Using `.spawn` or `.spawn_map`
- [dynamic-batching.md](references/dynamic-batching.md) — `@modal.batched` contracts and tuning
  **Load when:** Coalescing many requests into fewer executions
