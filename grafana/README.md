# Grafana

## Purpose

Grafana is the dashboard and visualization layer for the telemetry stack.

It is used to view:

| Data source | Purpose |
|---|---|
| Prometheus | Metrics from M920, containers, disks, and Prometheus itself |
| Loki | Logs from nginx, Docker containers, and optionally host/journald logs |

## Host and path

- Host: `M920`
- Path: `/srv/grafana`
- Compose file: `/srv/grafana/compose.yml`
- Environment file: `/srv/grafana/.env`
- Data path: `/srv/grafana/data`

## Exposure

- Public access: no
- Private access: yes
- Host binding: `127.0.0.1:3002`
- Private hostname: `grafana.alex-ashworth.com`
- nginx vhost: `/srv/nginx/conf.d/grafana.alex-ashworth.com.conf`
- Access model: Tailscale-only

Grafana should not be public. It contains operational dashboards and log visibility for the homelab.

## Container

| Container | Image | Role |
|---|---|---|
| `grafana` | `grafana/grafana:latest` | Dashboards and visualization UI |

## Docker networks

| Network | Purpose |
|---|---|
| `observability` | Allows Grafana to query Prometheus and Loki by container name |
| `proxy` | Allows nginx to reverse proxy Grafana privately |

## Persistent data

| Path | Purpose | Backed up |
|---|---|---|
| `/srv/grafana/data` | Grafana database, dashboards, plugins, data source config if configured through UI | yes |
| `/srv/grafana/.env` | Grafana environment variables and admin bootstrap values | yes, but never commit real secrets |

## Environment file

Example only. Do not commit the real `.env`.

```bash
GF_SERVER_ROOT_URL=https://grafana.alex-ashworth.com/
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=replace_me
```

Lock down the real file:

```bash
chmod 600 /srv/grafana/.env
```

## Data sources

Configured in Grafana UI:

```text
Connections -> Data sources
```

Expected data sources:

| Data source name | Type | URL |
|---|---|---|
| `prometheus` | Prometheus | `http://prometheus:9090` |
| `loki` | Loki | `http://loki:3100` |

Use lowercase names if that is how they were created.

## Dashboards

Current recommended dashboards:

| Dashboard | Source |
|---|---|
| Node Exporter Full | Prometheus |
| cAdvisor / Docker metrics | Prometheus |
| smartctl exporter dashboard | Prometheus |
| Custom Loki Logs dashboard | Loki |

The custom Loki dashboard currently contains raw Docker and nginx log panels.

## Important commands

Start or update:

```bash
cd /srv/grafana
docker compose up -d
```

Check logs:

```bash
docker logs grafana --tail 100
```

Local health/browser check:

```bash
curl -I http://127.0.0.1:3002
```

Test Grafana can reach Prometheus:

```bash
docker exec grafana sh -c 'wget -qO- http://prometheus:9090/-/healthy || true'
```

If `wget` is unavailable in the image, test through Grafana's data source UI instead:

```text
Connections -> Data sources -> prometheus -> Save & test
```

## nginx private vhost

Expected upstream:

```nginx
proxy_pass http://grafana:3000;
```

Required snippets:

```nginx
include /etc/nginx/snippets/proxy-common.conf;
include /etc/nginx/snippets/proxy-websocket.conf;
```

Recommended access restriction:

```nginx
include /etc/nginx/snippets/tailscale-only.conf;
```

Reload nginx after changes:

```bash
docker exec nginx nginx -t
docker exec nginx nginx -s reload
```

## Backup notes

Back up:

- `/srv/grafana/compose.yml`
- `/srv/grafana/.env.example`
- `/srv/grafana/data`
- exported dashboard JSON files, if available

Do not commit the real `.env`.

## Restore notes

1. Restore `/srv/grafana`.
2. Fix ownership:

```bash
sudo chown -R 472:472 /srv/grafana/data
```

3. Start Grafana:

```bash
cd /srv/grafana
docker compose up -d
```

4. Verify the UI and data sources.

## Known caveats

- Dashboard imports may not ask for a data source if Grafana auto-matches it.
- Imported dashboards often show no data until variables such as `job` and `instance` match this environment.
- For this setup, `node-exporter` data uses the `node-exporter` job label unless changed in Prometheus.
- Loki dashboards should be custom/simple unless the imported dashboard's labels match Alloy's labels.
