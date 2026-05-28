# Map and Gather

Use this reference when the caller wants a bounded set of results back in the same process.

## Core Pattern

- Use `.map(...)` to fan one function argument over an iterable of inputs.
- Use `.starmap(...)` when each input item is already a tuple or sequence of positional arguments.
- Keep orchestration local with `with app.run():` or `@app.local_entrypoint()` when the whole batch can complete within one invocation.
- Prefer `.map` or `.starmap` when the local caller needs the actual outputs, not just job submission side effects.

## Result Handling

- Treat `.map(...)` and `.starmap(...)` as iterables of results, not detached jobs.
- Keep `order_outputs=True` unless the caller explicitly benefits from out-of-order handling.
- Use `return_exceptions=True` only when the workflow should keep partial progress instead of failing fast.
- As of SDK 1.4.0, exceptions from `.map()` and `.starmap()` are returned directly (no longer wrapped in `UserCodeException`).
- Return stable, serialization-friendly payloads so the local orchestrator can transform or store them without extra remote calls.

## Dynamic Configuration (SDK 1.4.3+)

- Use `Function.with_options(gpu=..., timeout=..., cpu=...)` to override function parameters at call time without redeploying.
- Use `Function.with_concurrency(max_inputs=...)` to adjust concurrency dynamically.
- Use `Function.with_batching(max_batch_size=..., wait_ms=...)` to adjust batching parameters dynamically.
- Chain `.with_options()` calls — later calls merge with earlier ones.

## When to Use This Path

- Batch CPU or GPU work where the caller can wait for the full result set.
- Run a transform step that feeds a later local step.
- Parallelize bursty work without building a queueing or polling system.
- Fan out one stage of a larger pipeline before rechunking or post-processing locally.

## When to Avoid It

- Avoid `.map` when the caller should return immediately and finish work later; use `.spawn`.
- Avoid `.map` when each item writes output externally and nothing needs to come back in-process; `.spawn_map` is often simpler.
- Avoid unbounded inputs in one local run when the result set or failure surface is too large to manage comfortably.

## Useful Patterns

- Rechunk remote outputs locally before the next stage if upstream fan-out shape differs from downstream batch shape.
- Pair `.map` with `@app.cls` only when worker state reuse materially reduces setup cost.
- Keep each mapped function focused on one unit of work so retries and failures are easier to reason about.
- Use `routing_region=` to route inputs through a specific region for latency or data residency (SDK 1.4.3+, Public Beta).
