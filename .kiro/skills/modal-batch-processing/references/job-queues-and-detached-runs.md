# Job Queues and Detached Runs

Use this reference when work should keep running after the caller returns or disconnects.

## `.spawn` Job Queues

- Deploy the app with `modal deploy` when another service must submit jobs later.
- Look up a deployed function with `modal.Function.from_name(app_name, function_name)`.
- Submit work with `.spawn(...)` to get a `modal.FunctionCall`.
- Store the `FunctionCall.object_id` anywhere durable if the result will be polled later.
- Use `fc.get_dashboard_url()` to get a direct link to logs and status in the Modal dashboard (SDK 1.3.2+).

## Retrieving Results

- Rehydrate a call with `modal.FunctionCall.from_id(call_id)` when you only have the ID.
- Use `.get(timeout=...)` to wait for one result.
- Use `modal.FunctionCall.gather(*calls)` to wait for several spawned jobs.
- `.spawn()` results remain accessible through `FunctionCall.get()` for up to 7 days after completion.

## `.spawn_map` Detached Fan-Out

- Use `.spawn_map(...)` when you need to submit many inputs quickly and do not need programmatic result collection from the client.
- Pair `.spawn_map(...)` with `modal run --detach` so the app keeps running after the local process disconnects.
- Write outputs to a Volume, Cloud Bucket Mount, database, or another external store.
- Treat `.spawn_map(...)` as an external-side-effect path, not a result-gathering API.

## Choose Between `.spawn` and `.spawn_map`

- Use `.spawn` when each submitted job needs an addressable handle and later retrieval.
- Use `.spawn_map` when the caller only needs to enqueue many jobs and the outputs are already persisted elsewhere.
- Use `.map` instead of either one when the caller should stay attached and collect the outputs immediately.

## Reliability Defaults

- Set `retries=` only for idempotent tasks.
- Set `timeout=` deliberately so stuck jobs do not sit forever.
- Set `max_containers=` when downstream systems need a concurrency ceiling.
- Keep job payloads small and pass references to larger input data when practical.
- Use `modal app rollover` to trigger a fresh redeployment without code changes (SDK 1.4.2+).

## Deployment Strategies (SDK 1.4.0+)

- `modal deploy --strategy rolling` (default): smoothly migrates traffic from old to new containers.
- `modal deploy --strategy recreate`: terminates all running containers so subsequent inputs go to new containers. Useful when running at `max_containers` limit.

## Dynamic Configuration (SDK 1.4.3+)

- Use `Function.with_options()` to override GPU, timeout, CPU, or memory at call time.
- Use `Function.with_concurrency()` to adjust concurrency dynamically.
- Use `routing_region=` for regional input routing (Public Beta).

## Example Anchors

- Use the document OCR jobs example as the canonical `.spawn` pattern for remote submission and later polling.
- Use detached `.spawn_map` only when the result contract is already externalized.
