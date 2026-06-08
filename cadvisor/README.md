# cAdvisor

## Purpose

cAdvisor exposes Docker/container-level metrics for the `M920`.

It shows resource usage for containers, including:

| Category | Examples |
|---|---|
| CPU | container CPU usage |
| Memory | container memory usage |
| Disk I/O | container filesystem and block I/O |
| Network | container network activity |
| Container metadata | container labels and names |

Use node-exporter for host-level metrics.

## Host and path

- Host: `M920`
- Path: `/srv/cadvisor`
- Compose file: `/srv/cadvisor/compose.yml`

## Exposure

- Public access: no
- Browser access: no
- Host binding: `127.0.0.1:8085`
- Container port: `8080`
- Prometheus target: `cadvisor:8080`

cAdvisor should stay internal and only be scraped by Prometheus.

## Container

| Container | Image | Role |
|---|---|---|
| `cadvisor` | `gcr.io/cadvisor/cadvisor:latest` | Exposes Docker/container metrics |

## Docker networks

| Network | Purpose |
|---|---|
| `observability` | Allows Prometheus to scrape cAdvisor |

## Required mounts and privileges

Expected Compose characteristics:

```yaml
privileged: true
devices:
  - /dev/kmsg
volumes:
  - /:/rootfs:ro
  - /var/run:/var/run:ro
  - /sys:/sys:ro
  - /var/lib/docker:/var/lib/docker:ro
  - /dev/disk:/dev/disk:ro
```

cAdvisor needs broader host visibility than normal app containers because it reports container and host cgroup information.

## Important commands

Start or update:

```bash
cd /srv/cadvisor
docker compose up -d
```

Check logs:

```bash
docker logs cadvisor --tail 100
```

Local metrics check:

```bash
curl -s http://127.0.0.1:8085/metrics | head
```

Prometheus network check:

```bash
docker exec prometheus wget -qO- http://cadvisor:8080/metrics | head
```

If `wget` is unavailable:

```bash
docker run --rm --network observability curlimages/curl:latest \
  -s http://cadvisor:8080/metrics | head
```

Prometheus query:

```promql
up{job="cadvisor"}
```

Useful metrics:

```promql
container_memory_usage_bytes
```

```promql
container_cpu_usage_seconds_total
```

```promql
container_blkio_device_usage_total
```

## Grafana

Recommended dashboard type:

```text
Docker / cAdvisor container metrics dashboard
```

If a dashboard shows no data, check variables:

```text
job = cadvisor
instance = cadvisor:8080
```

## Backup notes

Back up:

- `/srv/cadvisor/compose.yml`

No persistent data is expected.

## Restore notes

1. Restore `/srv/cadvisor/compose.yml`.
2. Start:

```bash
cd /srv/cadvisor
docker compose up -d
```

3. Verify metrics locally and in Prometheus.

## Known caveats

- cAdvisor is intentionally more privileged than normal app containers.
- Some metrics can have very large label sets.
- Community dashboards may need variable adjustments.
- cAdvisor shows container metrics; it is not a full security/audit tool.
