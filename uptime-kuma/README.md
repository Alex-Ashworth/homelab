# Uptime Kuma

## Purpose

Uptime Kuma is used as the homelab status and availability monitor. It tracks whether important hosts, internal services, and web endpoints are reachable and responding as expected.

This service is intended to be a private administrative dashboard. It is exposed through nginx using a clean HTTPS hostname, but access is restricted to Tailscale and trusted internal Docker networks.

## Service Summary

| Item | Value |
|---|---|
| Service | Uptime Kuma |
| Host | M920 |
| Access URL | `https://uptime.alex-ashworth.com` |
| Access Model | Tailscale-only |
| Reverse Proxy | Dockerized nginx |
| Application Container | `uptime-kuma` |
| Application Port | `3001` |
| Database | SQLite |
| Persistent Data Path | `/srv/uptime-kuma/data` |
| Docker Network | `proxy` |
| Backup Scope | Include `/srv/uptime-kuma/data` in restic backups |

## Current Access Pattern

Uptime Kuma is accessed through the following path:

```text
Tailscale client
    -> uptime.alex-ashworth.com
    -> M920 Tailscale IP
    -> nginx container
    -> uptime-kuma:3001
```

The public internet should not have direct access to the Uptime Kuma dashboard.

## DNS Configuration

The hostname is configured as a DNS-only record pointing to the M920 Tailscale IP.

| Record Type | Name | Target | Proxy Mode |
|---|---|---|---|
| A | `uptime` | M920 Tailscale IPv4 address | DNS only |

The record should not be proxied through Cloudflare because the target is a private Tailscale address.

## Docker Configuration

Uptime Kuma runs as a Docker container with persistent storage mounted from the host.

Expected persistent mount:

```yaml
volumes:
  - /srv/uptime-kuma/data:/app/data
```

The service uses SQLite, which is stored inside the mounted data directory. No external database container is required for this deployment.

## Reverse Proxy Configuration

nginx proxies the private HTTPS hostname to the Uptime Kuma container.

Uptime Kuma uses WebSockets, so the nginx vhost must include the WebSocket proxy snippet.

Example location block:

```nginx
location / {
    proxy_pass http://uptime-kuma:3001;
    include /etc/nginx/snippets/proxy-common.conf;
    include /etc/nginx/snippets/proxy-websocket.conf;
}
```

The HTTPS server block should restrict access to Tailscale and trusted internal Docker networks.

Example access control pattern:

```nginx
allow 100.64.0.0/10;
allow fd7a:115c:a1e0::/48;
deny all;
```

If Uptime Kuma needs to monitor another private service through nginx, that service's nginx vhost may also need to allow the local Docker proxy network.

Example:

```nginx
allow 172.18.0.0/16;
```

Use the actual subnet from:

```bash
docker network inspect proxy | jq -r '.[0].IPAM.Config[0].Subnet'
```

## Data Storage

Uptime Kuma stores configuration, monitor definitions, user settings, and SQLite data under:

```text
/srv/uptime-kuma/data
```

This directory is the most important part of the deployment. If the container is recreated but this directory remains intact, the Uptime Kuma configuration and monitor history should persist.

## Backup Notes

The following path should be included in restic backups:

```text
/srv/uptime-kuma/data
```

Recommended backup priority:

| Path | Purpose | Required |
|---|---|---|
| `/srv/uptime-kuma/data` | Uptime Kuma database, settings, monitors, and history | Yes |
| `/srv/uptime-kuma/compose.yml` | Container deployment definition | Yes |
| `/srv/nginx/conf.d/uptime.alex-ashworth.com.conf` | nginx vhost for the dashboard | Yes |

## Current Monitors

| Monitor Name | Monitor Type | Target | Purpose | Notes |
|---|---|---|---|---|
| M920 LAN | Ping | `192.168.x.x` | Confirms M920 is reachable on the LAN | Replace with actual LAN IP |
| M920 Tailnet | Ping | `100.x.x.x` or MagicDNS name | Confirms M920 is reachable over Tailscale | Replace with actual tailnet address |
| Omarchy LAN | Ping | `192.168.x.x` | Confirms Omarchy machine is reachable on the LAN | Replace with actual LAN IP |
| Omarchy Tailnet | Ping | `100.x.x.x` or MagicDNS name | Confirms Omarchy machine is reachable over Tailscale | Replace with actual tailnet address |
| Nextcloud | HTTPS | `https://cloud.alex-ashworth.com/status.php` | Confirms Nextcloud responds through the private HTTPS path | Tailscale-only service |
| Gitea | HTTPS | `https://git.alex-ashworth.com` | Confirms Gitea responds through the public HTTPS path | Public service |
| Pi-hole | HTTPS | `https://pihole.alex-ashworth.com` | Confirms Pi-hole admin hostname responds | Private service |

## Monitor Inventory Template

Use this table to add future monitored services.

| Monitor Name | Monitor Type | Target | Expected Result | Alert Enabled | Notes |
|---|---|---|---|---|---|
| Example Web Service | HTTPS | `https://service.alex-ashworth.com` | HTTP 200/redirect/login page | Yes | Replace with actual service |
| Example Host | Ping | `100.x.x.x` | Host replies to ICMP | Yes | Tailnet reachability check |
| Example TCP Service | TCP Port | `host:port` | Port is open | Yes | Use when HTTP is not available |
| Example DNS Check | DNS | `example.com` | Valid DNS response | Yes | Useful for Pi-hole/Unbound |
| Example Scheduled Job | Push | Kuma push URL | Job checks in on schedule | Yes | Useful for backups and renewals |

## Recommended Future Monitors

| Service or Job | Suggested Monitor Type | Suggested Target | Purpose |
|---|---|---|---|
| restic backup | Push | Uptime Kuma push URL | Confirms scheduled backups completed |
| restic prune | Push | Uptime Kuma push URL | Confirms retention cleanup completed |
| restic check | Push | Uptime Kuma push URL | Confirms repository health checks completed |
| Certbot renewal | Push | Uptime Kuma push URL | Confirms certificate renewal job completed |
| nginx | HTTPS or TCP Port | `https://uptime.alex-ashworth.com` or port `443` | Confirms reverse proxy availability |
| Prometheus | HTTPS or HTTP | `http://prometheus:9090/-/ready` | Confirms Prometheus is ready |
| Grafana | HTTPS or HTTP | `http://grafana:3000/login` | Confirms Grafana is reachable |
| ntfy | HTTPS or HTTP | `https://ntfy.alex-ashworth.com/v1/health` | Confirms notification service health |
| Loki | HTTP | `http://loki:3100/ready` | Confirms log backend readiness |
| Proxmox | HTTPS | `https://<proxmox-tailnet-name>:8006` | Confirms Proxmox UI is reachable over Tailscale |
| Pi-hole DNS | DNS or TCP Port | Pi-hole IP, port `53` | Confirms DNS service availability |

## Monitor Type Guidance

### Ping

Use Ping monitors for basic host reachability.

Good targets:

```text
192.168.x.x
100.x.x.x
hostname
hostname.tailnet-name.ts.net
```

Do not include `http://` or `https://` in Ping monitor targets.

### HTTPS

Use HTTPS monitors for web services. This validates more than a TCP port check because it confirms the web service responds through nginx and TLS.

Good targets:

```text
https://cloud.alex-ashworth.com/status.php
https://git.alex-ashworth.com
https://pihole.alex-ashworth.com
```

### TCP Port

Use TCP checks when the service does not expose a useful HTTP endpoint.

Examples:

```text
host:22
host:2222
host:53
host:443
```

### DNS

Use DNS checks for Pi-hole and Unbound once DNS monitoring is needed.

Examples:

```text
cloud.alex-ashworth.com A
git.alex-ashworth.com A
example.com A
```

### Push

Use Push monitors for scheduled jobs. This is the best monitor type for tasks that run periodically, such as backups or certificate renewal.

Recommended push-monitored jobs:

- restic backup
- restic prune
- restic check
- certbot renewal
- custom maintenance scripts

## Operational Commands

Check container status:

```bash
cd /srv/uptime-kuma
docker compose ps
```

View logs:

```bash
docker logs uptime-kuma --tail 100
```

Restart Uptime Kuma:

```bash
cd /srv/uptime-kuma
docker compose restart uptime-kuma
```

Verify nginx config:

```bash
docker exec nginx nginx -t
```

Reload nginx:

```bash
docker exec nginx nginx -s reload
```

Test the dashboard from the host:

```bash
curl -Ik --resolve uptime.alex-ashworth.com:443:127.0.0.1 https://uptime.alex-ashworth.com
```

Test from inside the Uptime Kuma container:

```bash
docker exec uptime-kuma curl -Ik https://cloud.alex-ashworth.com
```

Inspect the Docker proxy network subnet:

```bash
docker network inspect proxy | jq -r '.[0].IPAM.Config[0].Subnet'
```

## Troubleshooting

### Public services work, but private Tailscale-only services fail

Likely cause:

- The private service's nginx vhost allows Tailscale addresses but does not allow the Docker proxy network.

Fix:

1. Find the Docker proxy subnet.
2. Add that subnet to the service's nginx allow list.
3. Reload nginx.

### Uptime Kuma shows 403 for a private service

Likely cause:

- nginx is blocking the request with `deny all`.

Fix:

- Allow the Docker proxy network in the target service's nginx vhost.

### Uptime Kuma shows DNS or timeout errors

Likely causes:

- The container cannot resolve the hostname.
- The hostname points to the wrong IP.
- The target service is not reachable from inside Docker.
- The service is not connected to the expected Docker network.

Useful checks:

```bash
docker exec uptime-kuma getent hosts cloud.alex-ashworth.com
docker exec uptime-kuma curl -Ik https://cloud.alex-ashworth.com
docker network inspect proxy
```

### Uptime Kuma dashboard loads, but live updates behave incorrectly

Likely cause:

- WebSocket headers are missing in nginx.

Fix:

```nginx
include /etc/nginx/snippets/proxy-websocket.conf;
```

Then reload nginx.

## Security Notes

- Uptime Kuma is an administrative dashboard and should remain private.
- The dashboard should not be exposed directly to the public internet.
- The nginx vhost should only allow Tailscale and required trusted internal Docker networks.
- Avoid mounting the Docker socket into Uptime Kuma unless Docker container monitoring is specifically required.
- Prefer HTTP, HTTPS, ping, TCP, DNS, and push monitors before enabling Docker socket access.

## Maintenance

Update the container:

```bash
cd /srv/uptime-kuma
docker compose pull
docker compose up -d
docker logs uptime-kuma --tail 100
```

Before major changes:

1. Confirm a recent restic backup exists.
2. Confirm `/srv/uptime-kuma/data` is included in backup scope.
3. Export or document important monitor settings if needed.
4. Update the README monitor inventory table after adding or removing monitored services.
