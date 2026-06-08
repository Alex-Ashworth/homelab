# smartctl-exporter

## Purpose

smartctl-exporter exposes disk SMART health metrics for Prometheus.

It is used to monitor drive health, temperature, SMART status, and supported disk attributes.

Current verified metrics include:

```text
smartctl_device_temperature
smartctl_device_smart_status
smartctl_devices
smartctl_exporter_build_info
```

## Host and path

- Host: `M920`
- Path: `/srv/smartctl-exporter`
- Compose file: `/srv/smartctl-exporter/compose.yml`

## Exposure

- Public access: no
- Browser access: no
- Host binding: `127.0.0.1:9633`
- Prometheus target: `smartctl-exporter:9633`

smartctl-exporter should stay internal and only be scraped by Prometheus.

## Container

| Container | Image | Role |
|---|---|---|
| `smartctl-exporter` | `prometheuscommunity/smartctl-exporter:latest` | Exposes SMART disk metrics |

## Docker networks

| Network | Purpose |
|---|---|
| `observability` | Allows Prometheus to scrape smartctl-exporter |

## Required permissions

The exporter needs low-level disk access. The working Compose should include:

```yaml
user: "0:0"
privileged: true
cap_add:
  - SYS_RAWIO
volumes:
  - /dev:/dev
  - /run/udev:/run/udev:ro
```

Earlier failures included `Permission denied` opening `/dev/sda`, `/dev/sdb`, and `/dev/sdc`. Running as root with appropriate device access fixed disk visibility.

## Important commands

Start or update:

```bash
cd /srv/smartctl-exporter
docker compose up -d
```

Force recreate after permission/mount changes:

```bash
cd /srv/smartctl-exporter
docker compose down
docker compose up -d
```

Check logs:

```bash
docker logs smartctl-exporter --tail 100
```

Local metrics check:

```bash
curl -s http://127.0.0.1:9633/metrics | head
```

List smartctl metrics:

```bash
curl -s http://127.0.0.1:9633/metrics | grep -E '^smartctl_' | head -100
```

Check temperature metrics:

```bash
curl -s http://127.0.0.1:9633/metrics | grep 'smartctl_device_temperature'
```

Check from Prometheus:

```bash
curl -sG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=smartctl_device_temperature' \
  | jq '.data.result'
```

Container disk scan:

```bash
docker exec -u 0 smartctl-exporter smartctl --scan-open
```

Host disk inventory:

```bash
lsblk -o NAME,TYPE,SIZE,MODEL,SERIAL
```

## Prometheus queries

Basic scrape health:

```promql
up{job="smartctl"}
```

or, if the job name was changed:

```promql
up{job="smartctl-exporter"}
```

Temperature:

```promql
smartctl_device_temperature
```

SMART status:

```promql
smartctl_device_smart_status
```

Device count:

```promql
smartctl_devices
```

## Grafana

Recommended dashboard:

```text
smartctl_exporter dashboard
```

If the dashboard shows no data:

1. Confirm Prometheus has data:

```bash
curl -sG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=smartctl_device_temperature' \
  | jq '.data.result'
```

2. Set time range to `Last 15 minutes` or `Last 1 hour`.

3. Use the query:

```promql
smartctl_device_temperature
```

4. Set legend/display name to:

```text
{{device}}
```

## Backup notes

Back up:

- `/srv/smartctl-exporter/compose.yml`

No persistent data is expected.

## Restore notes

1. Restore `/srv/smartctl-exporter/compose.yml`.
2. Start:

```bash
cd /srv/smartctl-exporter
docker compose up -d
```

3. Verify metrics:

```bash
curl -s http://127.0.0.1:9633/metrics | grep -E '^smartctl_'
```

## Known caveats

- USB/SATA/NVMe bridges may expose different SMART fields.
- Some dashboards expect metrics that a given disk does not emit.
- `smartctl_devices` only means devices were found; it does not guarantee all detailed SMART attributes are available.
- Missing media error panels may be normal if the drive/bridge does not expose that metric.
- Dashboard time range can cause no data if Grafana queries too broad a range with a huge step.
