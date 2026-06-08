# Alloy

## Purpose

Grafana Alloy is the telemetry collector for logs in this stack.

It currently collects:

| Source | Destination | Label |
|---|---|---|
| `/srv/nginx/logs/*.log` | Loki | `job="nginx"` |
| Docker container logs | Loki | `job="docker"` |
| `/var/log/*.log` | Loki | `job="host"` |

Host journald logs can be added later with `loki.source.journal`.

## Host and path

- Host: `M920`
- Path: `/srv/alloy`
- Compose file: `/srv/alloy/compose.yml`
- Config file: `/srv/alloy/config/config.alloy`

## Exposure

- Public access: no
- Browser access: no
- Host port: none required
- Destination: `http://loki:3100/loki/api/v1/push`

Alloy is an internal collector. It should not have a public vhost.

## Container

| Container | Image | Role |
|---|---|---|
| `alloy` | `grafana/alloy:latest` | Collects logs and sends them to Loki |

## Docker networks

| Network | Purpose |
|---|---|
| `observability` | Allows Alloy to push logs to Loki |

## Required mounts

| Mount | Purpose |
|---|---|
| `/srv/alloy/config/config.alloy:/etc/alloy/config.alloy:ro` | Alloy configuration |
| `/var/log:/var/log:ro` | Plain host log files |
| `/srv/nginx/logs:/srv/nginx/logs:ro` | nginx logs from nginx container bind mount |
| `/var/run/docker.sock:/var/run/docker.sock:ro` | Docker log discovery and collection |

The Docker socket is sensitive. Only trusted infrastructure containers should have access to it.

## Current recommended command

```yaml
command: run --disable-reporting /etc/alloy/config.alloy
```

`--disable-reporting` disables Alloy anonymous usage reporting only. It does not disable log collection or Loki forwarding.

## Current config pattern

`/srv/alloy/config/config.alloy`

```hcl
logging {
  level = "info"
}

loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

loki.source.file "nginx_logs" {
  targets = [
    {
      __path__ = "/srv/nginx/logs/*.log",
      job      = "nginx",
      host     = "m920",
    },
  ]

  forward_to = [loki.write.default.receiver]

  file_match {
    enabled     = true
    sync_period = "10s"
  }
}

loki.source.file "host_logs" {
  targets = [
    {
      __path__ = "/var/log/*.log",
      job      = "host",
      host     = "m920",
    },
  ]

  forward_to = [loki.write.default.receiver]

  file_match {
    enabled     = true
    sync_period = "10s"
  }
}

discovery.docker "linux" {
  host = "unix:///var/run/docker.sock"
}

loki.source.docker "docker_logs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.linux.targets
  labels     = {
    job  = "docker",
    host = "m920",
  }
  forward_to = [loki.write.default.receiver]
}
```

## Important commands

Start or update:

```bash
cd /srv/alloy
docker compose up -d
```

Force recreate after config changes:

```bash
cd /srv/alloy
docker compose up -d --force-recreate
```

Check logs:

```bash
docker logs alloy --tail 100
```

Check mounted log paths from inside container:

```bash
docker exec alloy ls -lah /srv/nginx/logs
docker exec alloy ls -lah /var/log
```

Test Loki from the host:

```bash
curl -s http://127.0.0.1:3100/ready
```

Test Loki reachability from the Docker network:

```bash
docker run --rm --network observability curlimages/curl:latest \
  -s http://loki:3100/ready
```

## Generate test logs

Generate nginx access logs:

```bash
curl -Ik https://cloud.alex-ashworth.com
curl -Ik https://grafana.alex-ashworth.com
```

Generate Docker logs by checking a container:

```bash
docker logs nginx --tail 5
```

Then query in Grafana:

```logql
{job="nginx"}
```

```logql
{job="docker"}
```

## Optional journald collection later

Add these mounts to `/srv/alloy/compose.yml`:

```yaml
- /var/log/journal:/var/log/journal:ro
- /run/log/journal:/run/log/journal:ro
- /etc/machine-id:/etc/machine-id:ro
```

Add this to `config.alloy`:

```hcl
loki.source.journal "host_journal" {
  labels = {
    job  = "journal",
    host = "m920",
  }

  forward_to = [loki.write.default.receiver]
}
```

Then restart Alloy and query:

```logql
{job="journal"}
```

## Backup notes

Back up:

- `/srv/alloy/compose.yml`
- `/srv/alloy/config/config.alloy`

No large persistent data is expected for Alloy itself.

## Restore notes

1. Restore `/srv/alloy`.
2. Start the service:

```bash
cd /srv/alloy
docker compose up -d
```

3. Verify logs:

```bash
docker logs alloy --tail 100
```

4. Query Loki in Grafana.

## Known caveats

- `/var/log/*.log` may be empty on CachyOS/Arch because many host logs live in journald.
- `job="host"` may show no data until journald collection is added.
- Docker log collection requires Docker socket access.
- Failed usage-report messages are harmless if reporting is not disabled.
