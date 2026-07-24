# Loki

Loki is the single-node filesystem log store receiving Alloy log streams.

**Runtime state:** Running as of 2026-07-23.

## Connectivity

Loki joins the shared `telemetry` and `proxy` networks and binds its HTTP API to loopback at `127.0.0.1:3100`.

## Configuration and storage

The Loki configuration file is mounted read-only from `config/loki-config.yml`. Its declared filesystem storage mount targets the protected Loki service-storage path; its contents are intentionally not documented here.
