# Lifecycle And Exec

Use this reference when the task is about creating, reattaching to, or driving a sandbox with commands.

## Creation Rules

- Create sandboxes from local code with `modal.App.lookup(..., create_if_missing=True)` and `modal.Sandbox.create(...)`.
- Treat the Python SDK as the source of truth for create and control flows.
- Avoid inventing a `modal sandbox` CLI workflow. Use `modal shell <sandbox_id>` to attach to a running sandbox instead.
- Use `include_oidc_identity_token=True` in `Sandbox.create()` when the sandbox needs OIDC-based authentication (e.g., AWS federation).

## Lifecycle Controls

- Treat the default maximum lifetime as 5 minutes.
- Set `timeout` when the sandbox must live longer, up to 24 hours.
- Set `idle_timeout` when the sandbox should terminate after inactivity.
- Use `Sandbox.from_id(...)` when a sandbox ID already exists.
- Use `Sandbox.from_name(app_name, name, ...)` only for a currently running named sandbox on a deployed app.
- Use `detach()` when the client should disconnect but the sandbox should keep running.
- Use `terminate()` when the sandbox should stop now. Pass `wait=True` to block until shutdown completes.

## Readiness Probes (SDK 1.4.1+)

- Use `modal.Probe.with_tcp(port)` for TCP-based readiness checks.
- Use `modal.Probe.with_exec(cmd)` for process-based readiness checks.
- Pass `readiness_probe=probe` to `Sandbox.create(...)`.
- Call `sb.wait_until_ready()` to block until the probe succeeds.
- Prefer readiness probes over manual polling loops for service startup.

## Exec Pattern

- Use `Sandbox.exec(...)` for most command execution.
- Expect a `ContainerProcess` back with `stdin`, `stdout`, `stderr`, `wait()`, and `returncode`.
- Use `stdout.read()` and `stderr.read()` after `wait()` when full buffered output is enough.
- Iterate over `stdout` or `stderr` when the user needs live streaming output.
- Set `bufsize=1` for line-oriented controller loops.
- Set `pty=True` only for commands that genuinely require a TTY.
- Set `timeout=` on `exec(...)` separately from sandbox lifetime when a single command should be bounded.

## Logging

- Wrap `Sandbox.create(...)` in `with modal.enable_output():` when you want build and provisioning output in the local terminal.
- Set `verbose=True` on `Sandbox.create(...)` when you want sandbox operation logs emitted by Modal.
- Expect empty or sparse app logs when the long-lived sandbox command is something quiet like `sleep`.
- Expect service logs to appear in `modal app logs <app-name>` when the long-lived process writes to `stdout` or `stderr`.
- Use `modal app logs --tail 1000` or `modal container logs --all` for historical log access (SDK 1.4.0+).
- Use `--search`, `--source`, `--function`, `--container` filters for targeted log retrieval.
- Treat `exec(...)` output as caller-managed stream data; read it from `ContainerProcess.stdout` and `ContainerProcess.stderr`, and tee it yourself if it also needs to live in your app logs.

## Stateful Controller Loop

- Start one long-lived process inside the sandbox when the task needs conversational state or a REPL.
- Exchange JSON or newline-delimited messages over `stdin` and `stdout`.
- Reuse the same sandbox and process instead of creating a new sandbox per turn.
- Prefer this pattern for code interpreters, agent drivers, and REPL-like tooling.
