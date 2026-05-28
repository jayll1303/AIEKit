# Dynamic Batching

Use this reference when many small requests should be coalesced into fewer executions.

## Contract

- Decorate the target function or class method with `@modal.batched(max_batch_size=..., wait_ms=...)`.
- Write the implementation to accept lists as inputs.
- Return a list.
- Keep every input list and the returned list the same length.

## Tuning

- Set `max_batch_size` to the largest batch the function can handle reliably.
- Set `wait_ms` to the latency budget that can be spent waiting for more inputs before execution.
- Expect a throughput and cost win at the expense of added queueing latency.
- Tune with representative payload sizes instead of synthetic tiny inputs only.

## Class Rules

- Batched methods work on `@app.cls` classes.
- If a class has a batched method, do not add other batched methods or `@modal.method` methods to the same class.
- Use `@app.cls` when batching benefits from expensive state kept warm in memory.

## Invocation Model

- Invoke batched functions or batched methods on individual logical inputs.
- `.map(...)` is often the clearest way to submit a stream of inputs and observe outputs.
- Keep the public interface simple so callers do not need to think in terms of internal batch shapes.

## Good Fits

- Speech, vision, embedding, or small inference requests that are too tiny to use the hardware efficiently one-by-one.
- Repeated CPU work with high per-call overhead but simple per-item inputs and outputs.
- GPU work where batching amortizes model startup or kernel launch overhead.

## Example Anchor

- Use the batched Whisper example as the reference pattern for `@modal.batched` on `@app.cls`, including `max_batch_size` selection and `wait_ms` tuning.
