# Prometheus

Prometheus collects metrics from itself, Node Exporter, cAdvisor, and Smartctl Exporter every 15 seconds.

**Runtime state:** Running as of 2026-07-23.

## Connectivity

Prometheus joins the shared `telemetry` and `proxy` networks and binds its web interface to loopback at `127.0.0.1:9090`.

## Configuration and storage

The scrape configuration is mounted read-only from `config/prometheus.yml`. Declared retention is 30 days and 100 GB. Its data mount targets the protected Prometheus service-storage path; its contents are intentionally not documented here.
