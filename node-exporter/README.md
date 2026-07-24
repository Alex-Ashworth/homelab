# Node Exporter

Node Exporter exposes host metrics for Prometheus.

**Runtime state:** Running as of 2026-07-23.

## Connectivity

The exporter joins the shared `telemetry` network and binds its metrics endpoint to loopback at `127.0.0.1:9100`.

## Host view

It runs with the host PID namespace and mounts the host root filesystem read-only at `/host` for metric collection. No persistent application-data mount is declared.
