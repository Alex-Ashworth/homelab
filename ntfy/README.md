# ntfy

ntfy provides authenticated notifications with default-deny access.

**Runtime state:** Running on 2026-07-23.

## Connectivity

ntfy joins the shared `proxy` and `telemetry` networks. Its HTTP service binds to loopback port 8088; the `ntfy` vhost provides access restricted to Tailscale and the proxy subnet.

## Persistence and configuration

Cache and configuration directories are mounted for persistent state. The checked-in configuration declares proxy operation and an authentication database, but no authentication data is documented here.
