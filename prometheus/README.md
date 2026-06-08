# Prometheus

## Purpose

Prometheus is the metrics database for the telemetry stack. It scrapes metrics from exporters and stores time-series data that Grafana can query.

Prometheus currently scrapes:

| Target | Purpose |
|---|---|
| `prometheus:9090` | Prometheus self-monitoring |
| `node-exporter:9100` | M920 host metrics |
| `cadvisor:8080` | Docker/container metrics |
| `smartctl-exporter:9633` | Disk SMART metrics |

## Host and path

- Host: `M920`
- Path: `/srv/prometheus`
- Compose file: `/srv/prometheus/compose.yml`
- Config file: `/srv/prometheus/config/prometheus.yml`
- Data path: `/srv/prometheus/data`

## Exposure

- Direct public access: no
- Browser access needed: usually no
- Host binding: `127.0.0.1:9090`
- Recommended access: through Grafana, not directly
- Optional private hostname: `prometheus.alex-ashworth.com`, only if intentionally added later

Prometheus should generally remain internal. Grafana can reach it through the Docker network at:

```text
http://prometheus:9090
```

## Container

| Container | Image | Role |
|---|---|---|
| `prometheus` | `prom/prometheus:latest` | Metrics storage and query engine |

## Docker networks

| Network | Purpose |
|---|---|
| `observability` | Allows Prometheus to scrape exporters and be queried by Grafana |
| `proxy` | Optional nginx/private access path if a vhost is added |

## Persistent data

| Path | Purpose | Backed up |
|---|---|---|
| `/srv/prometheus/config` | Prometheus configuration | yes |
| `/srv/prometheus/data` | Prometheus time-series database | optional/yes |

The data directory can grow. Current recommended retention is:

```yaml
--storage.tsdb.retention.time=30d
--storage.tsdb.retention.size=10GB
```

## Important commands

Start or update:

```bash
cd /srv/prometheus
docker compose up -d
```

Check status:

```bash
cd /srv/prometheus
docker compose ps
docker logs prometheus --tail 100
```

Validate config:

```bash
docker run --rm \
  --entrypoint=promtool \
  -v /srv/prometheus/config:/etc/prometheus:ro \
  prom/prometheus:latest \
  check config /etc/prometheus/prometheus.yml
```

Reload config without restarting, if `--web.enable-lifecycle` is enabled:

```bash
curl -X POST http://127.0.0.1:9090/-/reload
```

Health check:

```bash
curl -s http://127.0.0.1:9090/-/healthy
```

List targets:

```bash
curl -s http://127.0.0.1:9090/api/v1/targets | jq '
  .data.activeTargets[] |
  {
    job: .labels.job,
    health: .health,
    lastError: .lastError,
    scrapeUrl: .scrapeUrl
  }'
```

Query `up` values:

```bash
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' | jq
```

## Current known job labels

| Job | Instance |
|---|---|
| `prometheus` | `prometheus:9090` |
| `node-exporter` | `node-exporter:9100` |
| `cadvisor` | `cadvisor:8080` |
| `smartctl` or `smartctl-exporter` | `smartctl-exporter:9633` |

Use whatever job name is currently defined in `/srv/prometheus/config/prometheus.yml`.

## Backup notes

Back up:

- `/srv/prometheus/config`
- `/srv/prometheus/compose.yml`

Prometheus data under `/srv/prometheus/data` can be backed up, but it is usually less critical than app data. If disk space is a concern, backup the config and allow Prometheus to rebuild metrics history over time.

## Restore notes

1. Restore `/srv/prometheus/compose.yml`.
2. Restore `/srv/prometheus/config/prometheus.yml`.
3. Restore `/srv/prometheus/data` if desired.
4. Fix ownership if needed:

```bash
sudo chown -R 65534:65534 /srv/prometheus/data
```

5. Start the service:

```bash
cd /srv/prometheus
docker compose up -d
```

## Known caveats

- Dashboards may show no data if their expected `job` label does not match the Prometheus config.
- Community dashboards often expect `job="node"` while this setup may use `job="node-exporter"`.
- Prometheus may briefly show targets as `unknown` until a successful scrape completes.
