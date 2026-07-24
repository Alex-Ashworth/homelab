# Smartctl Exporter

Smartctl Exporter exposes disk SMART metrics for Prometheus.

**Runtime state:** Running as of 2026-07-23.

## Connectivity

The exporter joins the shared `telemetry` network and binds its metrics endpoint to loopback at `127.0.0.1:9633`.

## Host access

It runs as root with privileged access and the `SYS_RAWIO` capability. Read-only mounts of `/dev` and `/run/udev` provide access to disk metadata. No persistent application-data mount is declared.
