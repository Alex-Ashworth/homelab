# Loki

## Purpose

Loki is the log storage and query backend for the telemetry stack.

It receives logs from Alloy and makes them available to Grafana.

Current intended log sources:

| Source | Label |
|---|---|
| nginx log files | `job="nginx"` |
| Docker container logs | `job="docker"` |
| plain `/var/log/*.log` files | `job="host"` |
| optional journald logs later | `job="journal"` |

## Host and path

- Host: `M920`
- Path: `/srv/loki`
- Compose file: `/srv/loki/compose.yml`
- Config file: `/srv/loki/config/loki-config.yml`
- Data path: `/srv/loki/data`

## Exposure

- Public access: no
- Direct browser access: no
- Host binding: `127.0.0.1:3100`
- Grafana data source URL: `http://loki:3100`

Loki should stay internal. Grafana is the UI for querying Loki logs.

## Container

| Container | Image | Role |
|---|---|---|
| `loki` | `grafana/loki:latest` | Log storage and query backend |

## Docker networks

| Network | Purpose |
|---|---|
| `observability` | Allows Alloy to push logs and Grafana to query Loki |
| `proxy` | Optional/private access path if needed later |

## Persistent data

| Path | Purpose | Backed up |
|---|---|---|
| `/srv/loki/config/loki-config.yml` | Loki configuration | yes |
| `/srv/loki/data` | Loki log chunks/indexes | optional/yes |

Loki data can grow depending on log volume and retention.

## Important commands

Start or update:

```bash
cd /srv/loki
docker compose up -d
```

Check logs:

```bash
docker logs loki --tail 100
```

Readiness check:

```bash
curl -s http://127.0.0.1:3100/ready
```

Expected:

```text
ready
```

Query all recent log streams directly:

```bash
END=$(date +%s%N)
START=$((END - 3600*1000000000))

curl -sG http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job=~".+"}' \
  --data-urlencode "start=$START" \
  --data-urlencode "end=$END" \
  --data-urlencode "limit=20" \
  | jq '.data.result[] | {labels: .stream, lines: [.values[][1]][0:3]}'
```

## Grafana queries

Use Grafana:

```text
Explore -> loki
```

Useful LogQL selectors:

```logql
{job=~".+"}
```

```logql
{job="nginx"}
```

```logql
{job="docker"}
```

```logql
{job="host"}
```

If journald is added later:

```logql
{job="journal"}
```

Useful simple rate panels:

```logql
sum(rate({job="nginx"}[5m]))
```

```logql
sum(rate({job="docker"}[5m]))
```

## Backup notes

Back up:

- `/srv/loki/compose.yml`
- `/srv/loki/config/loki-config.yml`

Back up `/srv/loki/data` if log history is important. Otherwise, Loki can rebuild forward from new logs after restore.

## Restore notes

1. Restore `/srv/loki`.
2. Fix ownership if needed. Loki commonly uses UID `10001`:

```bash
sudo chown -R 10001:10001 /srv/loki/data
```

3. Start Loki:

```bash
cd /srv/loki
docker compose up -d
```

4. Verify:

```bash
curl -s http://127.0.0.1:3100/ready
```

## Known caveats

- Loki is not a replacement for backups or long-term archival unless retention/storage is designed for that.
- Imported Loki dashboards often fail because labels differ by environment.
- For this setup, custom dashboards using `{job="nginx"}` and `{job="docker"}` are preferred.
