# Security

`win-gui-agent` controls the active Windows desktop. Treat it like local keyboard, mouse, screenshot, and process-control access.

## Supported Use

- Run it only on trusted local machines, trusted VMs, or isolated lab networks.
- Keep the default listener bound to `127.0.0.1`.
- Use SSH tunnels or VM-only networking when controlling it from another host.

## Do Not

- Do not expose the HTTP API directly to the public internet.
- Do not publish installers, license files, credentials, VM snapshots, or private screenshots.
- Do not run untrusted task files.

## Reporting Issues

For now, report security-sensitive issues privately to the repository owner. Include the affected endpoint, task file, operating system version, and a minimal reproduction when possible.
