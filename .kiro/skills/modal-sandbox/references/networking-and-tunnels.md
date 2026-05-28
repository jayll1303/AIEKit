# Networking And Tunnels

Use this reference when the sandbox must expose a service or run with explicit network restrictions.

## Expose Services

- Use `encrypted_ports=[...]` for HTTPS-style public endpoints.
- Use `unencrypted_ports=[...]` only when plaintext traffic is acceptable.
- Use `h2_ports=[...]` when the service needs HTTP/2 instead of HTTP/1.1.
- Retrieve public tunnel metadata with `sandbox.tunnels()`.
- Expect `sandbox.tunnels()` to return a mapping from container port to tunnel metadata.
- Use readiness probes (`modal.Probe.with_tcp(port)`) with `sb.wait_until_ready()` instead of manual polling (SDK 1.4.1+).

## Readiness Checks

- Wait for the service to boot before reporting success.
- Prefer `readiness_probe=modal.Probe.with_tcp(port)` + `sb.wait_until_ready()` for new code (SDK 1.4.1+).
- Fall back to polling the tunnel URL from outside the sandbox until the expected HTTP status or TCP readiness appears.
- Ignore service logs that mention `localhost`; use the returned tunnel URLs instead.

## Security Controls

- Use `block_network=True` to disable outbound network access entirely.
- Use `outbound_cidr_allowlist=[...]` when the sandbox should only reach specific outbound ranges (SDK 1.4.3+).
- Use `inbound_cidr_allowlist=[...]` to restrict inbound connections (SDK 1.4.3+).
- The old `cidr_allowlist=[...]` parameter is deprecated — use the explicit inbound/outbound variants.
- Expose only the ports the task requires.
- Use `create_connect_token()` only when the application needs authenticated HTTP connections forwarded through Modal's proxy.

## Custom Domains (SDK 1.3.1+)

- Use `Sandbox.create(..., custom_domain="sandboxes.mydomain.com")` for custom domain routing.
- Note: custom domains for sandboxes must currently be set up manually by Modal.

## CLI Interop

- Use `modal shell <sandbox_id>` for direct debugging access to a running sandbox.
- Use `modal container list`, `modal container logs`, or `modal container exec` only as generic inspection tools, not as the primary sandbox-creation API.
- Pass a Sandbox ID directly to `modal container logs` (SDK 1.3.2+).
