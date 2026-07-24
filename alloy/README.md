# Alloy

Alloy collects host, Nginx, and discovered Docker container logs and sends them to Loki.

**Runtime state:** Running as of 2026-07-23.

## Data flow

Host logs from `/var/log`, Nginx logs from `/srv/nginx/logs`, and Docker-discovered logs are labeled with host `m920` and forwarded to `http://loki:3100/loki/api/v1/push`.

## Connectivity and configuration

The service uses the shared `telemetry` network and has no declared host port. Its configuration is mounted read-only from `config/config.alloy`; host, Nginx-log, and Docker socket mounts support collection.
