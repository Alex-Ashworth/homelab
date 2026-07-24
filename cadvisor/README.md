# cAdvisor

cAdvisor exports container metrics for Prometheus.

**Runtime state:** Running as of 2026-07-23.

## Connectivity

The service uses the shared `telemetry` network and binds its HTTP endpoint to loopback at `127.0.0.1:8085`.

## Host access

It runs privileged and mounts the host root filesystem, `/var/run`, `/sys`, Docker data, `/dev/disk`, and `/dev/kmsg` read-only where declared. No persistent application-data mount is declared.
