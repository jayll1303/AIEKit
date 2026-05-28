# Troubleshooting

Use this reference when the sandbox workflow is failing after the main create and control flow is already chosen.

## `modal` CLI not found or `import modal` fails

- Verify that the `modal` CLI and the Python package come from the same environment.
- Switch to the project virtualenv or the interpreter behind the installed CLI before retrying.

## Sandbox terminates unexpectedly

- Treat 5 minutes as the default maximum lifetime.
- Set `timeout=` explicitly on `Sandbox.create(...)` for longer workloads, up to 24 hours.
- Set `idle_timeout=` when the sandbox should stop only after inactivity.

## `Sandbox.from_name(...)` returns nothing

- `from_name(...)` only finds a currently running named sandbox on a deployed app.
- Recreate the sandbox when the named instance has already terminated.

## Tunnel URL not available

- Use readiness probes (`modal.Probe.with_tcp(port)`) with `sb.wait_until_ready()` instead of manual polling (SDK 1.4.1+).
- If not using probes, poll `sandbox.tunnels()` until the service has finished starting.
- Recheck that the service is bound to the same port exposed in `encrypted_ports`, `unencrypted_ports`, or `h2_ports`.

## File writes not persisted after sandbox termination

- Use Volumes or CloudBucketMounts for data that must outlive a single sandbox.
- Use the new filesystem API (`sb.filesystem.*`) for runtime file operations (SDK 1.4.0+).
- The deprecated `sandbox.open()`, `sandbox.ls()`, `sandbox.mkdir()`, `sandbox.rm()` methods are sandbox-scoped runtime IO and will be removed.

## `Sandbox.exec` hangs or returns no output

- Ensure the sandbox has not terminated immediately after creation (fixed in SDK 1.4.0).
- Set `timeout=` on `exec(...)` to bound individual commands.
- Use `bufsize=1` for line-oriented streaming to avoid buffering issues.
- Check `process.returncode` after `process.wait()` to detect failures.

## Deprecated API warnings

- Replace `sandbox.open()` with `sb.filesystem.write_text/read_text/write_bytes/read_bytes`.
- Replace `sandbox.ls()` with `sb.filesystem.list_files()`.
- Replace `sandbox.mkdir()` with `sb.filesystem.make_directory()`.
- Replace `sandbox.rm()` with `sb.filesystem.remove()`.
- Replace `cidr_allowlist` with `outbound_cidr_allowlist` and/or `inbound_cidr_allowlist`.
