# Uptime Kuma

Uptime Kuma v2 provides availability monitoring.

**Runtime state:** Running as of 2026-07-23.

## Connectivity

The service joins the shared `proxy` and `telemetry` networks. Its UI binds to loopback at `127.0.0.1:3001`; the `uptime.alex-ashworth.com` vhost provides tailnet-restricted access.

## Persistence and discovery

Application data is persisted in the `data` mount. A read-only Docker socket mount enables Docker socket discovery.
