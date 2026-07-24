# Grafana

Grafana provides metrics and log visualization.

**Runtime state:** Running as of 2026-07-23.

## Connectivity

Grafana joins the shared `telemetry` and `proxy` networks. Its HTTP service binds to loopback at `127.0.0.1:3002`; the `grafana.alex-ashworth.com` vhost provides tailnet-restricted access.

## Persistence

Grafana data is mounted at `data` to preserve application state. Runtime environment settings are supplied through a local environment file, whose values are not documented here.
