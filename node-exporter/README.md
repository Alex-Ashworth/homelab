# node-exporter

## Purpose

node-exporter exposes host-level metrics for the `M920`.

It shows metrics for the host itself, not individual Docker containers.

Examples:

| Category | Examples |
|---|---|
| CPU | CPU usage, idle time, load |
| RAM | available memory, total memory, swap |
| Disk/filesystem | filesystem usage, free space, mounts |
| Disk I/O | reads/writes, device activity |
| Network | interface traffic and errors |
| System | uptime, kernel/system stats |

Use cAdvisor for per-container metrics.

## Host and path

- Host: `M920`
- Path: `/srv/node-exporter`
- Compose file: `/srv/node-exporter/compose.yml`

## Exposure

- Public access: no
- Browser access: no
- Host binding: `127.0.0.1:9100`
- Prometheus target: `node-exporter:9100`

node-exporter should stay internal and only be scraped by Prometheus.

## Container

| Container | Image | Role |
|---|---|---|
| `node-exporter` | `quay.io/prometheus/node-exporter:latest` | Exposes host metrics |

## Docker networks

| Network | Purpose |
|---|---|
| `observability` | Allows Prometheus to scrape node-exporter |

## Required mounts and settings

Expected Compose characteristics:

```yaml
pid: host
command:
  - --path.rootfs=/host
volumes:
  - /:/host:ro,rslave
```

These allow node-exporter to report host metrics rather than only container metrics.

## Important commands

Start or update:

```bash
cd /srv/node-exporter
docker compose up -d
```

Check logs:

```bash
docker logs node-exporter --tail 100
```

Local metrics check:

```bash
curl -s http://127.0.0.1:9100/metrics | head
```

Prometheus network check:

```bash
docker exec prometheus wget -qO- http://node-exporter:9100/metrics | head
```

If `wget` is unavailable, use a temporary curl container:

```bash
docker run --rm --network observability curlimages/curl:latest \
  -s http://node-exporter:9100/metrics | head
```

Prometheus query:

```promql
up{job="node-exporter"}
```

Useful metrics:

```promql
node_memory_MemAvailable_bytes
```

```promql
node_cpu_seconds_total
```

```promql
node_filesystem_avail_bytes
```

## Grafana

Recommended dashboard:

```text
Node Exporter Full
```

If the dashboard shows no data, set the dashboard variable:

```text
job = node-exporter
instance = node-exporter:9100
```

Some community dashboards expect `job="node"`. This setup uses `job="node-exporter"` unless Prometheus config is changed.

## Backup notes

Back up:

- `/srv/node-exporter/compose.yml`

No persistent data is expected.

## Restore notes

1. Restore `/srv/node-exporter/compose.yml`.
2. Start:

```bash
cd /srv/node-exporter
docker compose up -d
```

3. Verify Prometheus target is `up`.

## Known caveats

- node-exporter is for host metrics, not Docker container metrics.
- It needs host filesystem visibility to show accurate host-level data.
- Dashboard variable mismatch is the most common Grafana issue.
