# ntfy Service

This directory documents the self-hosted `ntfy` deployment for the homelab.

The final setup runs ntfy as a Docker container, keeps the service private over Tailscale, uses nginx as the HTTPS reverse proxy, and uses ntfy authentication with default-deny access.

## Summary

| Item | Value |
|---|---|
| Service | ntfy |
| Purpose | Homelab notifications and alert delivery |
| Public exposure | No; Tailscale-only access |
| Public hostname | `ntfy.alex-ashworth.com` |
| Container name | `ntfy` |
| Image | `binwiederhier/ntfy:latest` |
| Host directory | `/srv/ntfy` |
| Config file | `/srv/ntfy/config/server.yml` |
| Auth database | `/srv/ntfy/config/user.db` |
| Cache database | `/srv/ntfy/cache/cache.db` |
| Local host port | `127.0.0.1:8088` |
| Container HTTP port | `80` |
| Docker networks | `proxy`, `telemetry` |
| Reverse proxy | Dockerized nginx |
| TLS certificate path | `/etc/letsencrypt/live/ntfy.alex-ashworth.com/` inside nginx |

## Architecture

```text
Tailscale client
      |
      |  https://ntfy.alex-ashworth.com
      v
Cloudflare DNS record
      |
      |  A record points to the M920 Tailscale IPv4 address
      v
M920 / main Docker host
      |
      |  nginx container, HTTPS vhost, Tailscale-only allowlist
      v
ntfy container
      |
      |  /srv/ntfy/config and /srv/ntfy/cache
      v
Persistent ntfy config, auth database, and cache database
```

The service is private in multiple ways:

1. The Cloudflare DNS record for `ntfy.alex-ashworth.com` points to the host's Tailscale IP, not the public WAN IP.
2. The ntfy container only publishes its HTTP port to host loopback: `127.0.0.1:8088:80`.
3. The nginx vhost only allows clients from the Tailscale CGNAT range: `100.64.0.0/10`.
4. ntfy authentication is enabled with `auth-default-access: "deny-all"`.

This means a random internet client should not be able to reach or use this ntfy instance.

## Directory layout

```text
/srv/ntfy/
├── compose.yml
├── cache/
│   └── cache.db
└── config/
    ├── server.yml
    └── user.db
```

The `cache/` directory stores ntfy's message cache database.

The `config/` directory stores the server configuration and authentication database.

## Docker Compose configuration

Final `/srv/ntfy/compose.yml`:

```yaml
services:
  ntfy:
    image: binwiederhier/ntfy:latest
    container_name: ntfy
    restart: unless-stopped
    command:
      - serve
    volumes:
      - /srv/ntfy/cache:/var/cache/ntfy
      - /srv/ntfy/config:/etc/ntfy
    ports:
      - "127.0.0.1:8088:80"
    networks:
      - proxy
      - telemetry

networks:
  proxy:
    external: true
  telemetry:
    external: true
```

### Notes

- `restart: unless-stopped` keeps ntfy running across reboots unless it is manually stopped.
- `/srv/ntfy/cache` is mounted to `/var/cache/ntfy` for persistent cache storage.
- `/srv/ntfy/config` is mounted to `/etc/ntfy` for persistent configuration and auth state.
- `127.0.0.1:8088:80` makes ntfy reachable from the host only, not directly from the LAN or internet.
- The `proxy` network lets nginx reach the container by the Docker DNS name `ntfy`.
- The `telemetry` network allows integration with monitoring/alerting services such as Uptime Kuma.

## ntfy server configuration

Final `/srv/ntfy/config/server.yml`:

```yaml
base-url: "https://ntfy.alex-ashworth.com"
cache-file: "/var/cache/ntfy/cache.db"
auth-file: "/etc/ntfy/user.db"
auth-default-access: "deny-all"
behind-proxy: true
listen-http: ":80"
```

### Setting explanations

| Setting | Purpose |
|---|---|
| `base-url` | Tells ntfy its external URL for links, apps, and integrations. |
| `cache-file` | Stores cached messages in the mounted cache directory. |
| `auth-file` | Enables authentication and stores users/tokens/access rules in `user.db`. |
| `auth-default-access` | Denies anonymous/default topic access unless explicitly allowed. |
| `behind-proxy` | Tells ntfy it is running behind a reverse proxy. |
| `listen-http` | Makes ntfy listen on HTTP port `80` inside the container. |

## Authentication model

Authentication is enabled with:

```yaml
auth-file: "/etc/ntfy/user.db"
auth-default-access: "deny-all"
```

Because `/srv/ntfy/config` is mounted to `/etc/ntfy`, the persistent auth database is stored on the host at:

```text
/srv/ntfy/config/user.db
```

The chosen model is token-based access:

```text
user account -> access rules -> token inherits that user's permissions
```

For service integrations, prefer a limited service user instead of using the admin token.

Example service-user permission model:

```bash
docker exec -it ntfy ntfy user add service
docker exec -it ntfy ntfy access service "alerts-*" wo
docker exec -it ntfy ntfy token add --label="service" service
```

In that example:

- `alerts-*` allows topics such as `alerts-homelab`, `alerts-critical`, and `alerts-uptime`.
- `wo` means write-only.
- Uptime Kuma can publish alerts but does not need read/admin access.

## nginx reverse proxy configuration

Final nginx vhost:

```nginx
server {
    listen 80;
    server_name ntfy.alex-ashworth.com;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    http2 on;
    server_name ntfy.alex-ashworth.com;

    ssl_certificate /etc/letsencrypt/live/ntfy.alex-ashworth.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ntfy.alex-ashworth.com/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    location / {
        allow 100.64.0.0/10;
        deny all;

        proxy_pass http://ntfy:80;
        include /etc/nginx/snippets/proxy-common.conf;
        include /etc/nginx/snippets/proxy-websocket.conf;
    }
}
```

### Important details

- Port `80` redirects to HTTPS.
- Port `443` serves the private HTTPS endpoint.
- `http2 on;` enables HTTP/2 using the modern nginx syntax.
- `allow 100.64.0.0/10; deny all;` restricts the endpoint to Tailscale clients.
- `proxy_pass http://ntfy:80;` uses Docker DNS over the `proxy` network.
- `proxy-websocket.conf` is included because ntfy uses long-lived connections/WebSockets.

## DNS and certificate model

`ntfy.alex-ashworth.com` is configured as a private hostname.

Cloudflare DNS should be:

```text
Type: A
Name: ntfy
Content: <M920 Tailscale IPv4 address>
Proxy status: DNS only
TTL: Auto
```

The certificate is handled with DNS validation rather than HTTP validation. This is necessary because Let's Encrypt cannot reach a Tailscale-only service over the public internet.

The certificate files are mounted into nginx at:

```text
/etc/letsencrypt/live/ntfy.alex-ashworth.com/fullchain.pem
/etc/letsencrypt/live/ntfy.alex-ashworth.com/privkey.pem
```

On the host, those files live under the nginx Certbot directory, typically:

```text
/srv/nginx/certbot/conf/live/ntfy.alex-ashworth.com/
```

## Starting and stopping

Start ntfy:

```bash
cd /srv/ntfy
docker compose up -d
```

Check status:

```bash
cd /srv/ntfy
docker compose ps
docker logs ntfy --tail 50
```

Restart after config changes:

```bash
cd /srv/ntfy
docker compose up -d
```

Stop ntfy:

```bash
cd /srv/ntfy
docker compose down
```

## nginx validation and reload

After editing the vhost:

```bash
docker exec nginx nginx -t
docker exec nginx nginx -s reload
```

Check that nginx can resolve and reach the ntfy container:

```bash
docker exec nginx getent hosts ntfy
docker exec nginx wget -S -O- http://ntfy:80 2>&1 | head
```

## Testing

Local host test:

```bash
curl -I http://127.0.0.1:8088
```

Private HTTPS test from a Tailscale-connected device:

```bash
curl -I https://ntfy.alex-ashworth.com
```

Token publish test:

```bash
curl \
  -H "Authorization: Bearer YOUR_NTFY_TOKEN" \
  -d "ntfy is live over Tailscale-only HTTPS" \
  https://ntfy.alex-ashworth.com/alerts-homelab
```

A successful publish test confirms:

- DNS resolves correctly from a Tailscale-connected client.
- nginx is accepting the request.
- the Tailscale-only allowlist is not blocking the client.
- nginx can proxy to the ntfy container.
- ntfy authentication and token publishing work.

## Uptime Kuma integration

If Uptime Kuma is on the same Docker host and attached to the same `telemetry` network, it can publish directly to ntfy over Docker networking.

Recommended internal URL:

```text
http://ntfy:80
```

Recommended topic pattern:

```text
alerts-homelab
```

Recommended auth:

```text
Authorization: Bearer <uptime-kuma-token>
```

This avoids unnecessary routing through Cloudflare DNS, Tailscale, and nginx for container-to-container alert delivery.

External tailnet clients, such as a laptop or phone, should use:

```text
https://ntfy.alex-ashworth.com
```

## Backup notes

Back up at least:

```text
/srv/ntfy/config/server.yml
/srv/ntfy/config/user.db
/srv/ntfy/cache/cache.db
```

The most important file is:

```text
/srv/ntfy/config/user.db
```

That file contains ntfy users, tokens, and access control rules.

## Update procedure

Update ntfy:

```bash
cd /srv/ntfy
docker compose pull
docker compose up -d
docker logs ntfy --tail 50
```

Validate after updating:

```bash
curl -I http://127.0.0.1:8088
curl -I https://ntfy.alex-ashworth.com
```

Then send a token-authenticated test notification.

## Troubleshooting

### `curl https://ntfy.alex-ashworth.com` fails to resolve

Check DNS:

```bash
dig +short ntfy.alex-ashworth.com
```

It should return the M920 Tailscale IPv4 address.

### nginx returns `403 Forbidden`

The client is probably not reaching nginx from a Tailscale IP.

Confirm the client is connected to Tailscale and that the source address falls inside:

```text
100.64.0.0/10
```

### nginx returns `502 Bad Gateway`

Check that nginx can reach the ntfy container:

```bash
docker exec nginx getent hosts ntfy
docker exec nginx wget -S -O- http://ntfy:80 2>&1 | head
```

Also confirm both containers are on the `proxy` network:

```bash
docker network inspect proxy | grep -E 'nginx|ntfy'
```

### Token publish fails

Check users and access rules:

```bash
docker exec -it ntfy ntfy user list
docker exec -it ntfy ntfy access
docker exec -it ntfy ntfy token list <username>
```

For Uptime Kuma, confirm the service user has write-only access to the intended topic pattern:

```bash
docker exec -it ntfy ntfy access uptime-kuma "alerts-*" wo
```

### Config changes do not apply

Restart the container:

```bash
cd /srv/ntfy
docker compose up -d
```

Then inspect logs:

```bash
docker logs ntfy --tail 100
```

