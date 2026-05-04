# nginx + Certbot Public Ingress Setup

## Purpose

This directory documents the nginx public ingress stack for the homelab.

The stack provides the public entry point for services that are intentionally exposed to the internet, such as Nextcloud or other approved public web services. nginx handles incoming HTTP/HTTPS traffic, while Certbot obtains and renews Let's Encrypt TLS certificates.

---

## High-Level Design

```text
Internet client
    ↓
Public DNS record
    ↓
Home public WAN IP
    ↓
Router port forward
    ↓
M920 host ports 80/443
    ↓
Docker-published nginx container
    ↓
Docker proxy network
    ↓
Application container, such as nextcloud-app
```

For certificate issuance, the path is:

```text
Let's Encrypt
    ↓
http://service.example.com/.well-known/acme-challenge/<token>
    ↓
Router forwards TCP 80 to M920
    ↓
nginx serves the challenge file from /var/www/certbot
    ↓
Certbot verifies domain ownership
```

---

## Directory Layout

```text
/srv/nginx/
  compose.yml
  conf.d/
  snippets/
  logs/
  certbot/
    conf/
    www/
```

Path purposes:

| Path | Purpose |
|---|---|
| `/srv/nginx/compose.yml` | Docker Compose definition for nginx and Certbot |
| `/srv/nginx/conf.d/` | nginx virtual host configuration files |
| `/srv/nginx/snippets/` | Reusable nginx include snippets |
| `/srv/nginx/logs/` | Host-visible nginx logs |
| `/srv/nginx/certbot/conf/` | Persistent Let's Encrypt certificate/account data |
| `/srv/nginx/certbot/www/` | ACME HTTP-01 challenge webroot |

---

## Docker Network

The shared Docker network is:

```text
proxy
```

Create it if it does not already exist:

```bash
docker network inspect proxy >/dev/null 2>&1 || docker network create proxy
```

nginx and any service it reverse-proxies must be attached to this network. This lets nginx reach application containers by Docker service/container name.

---

## Compose Stack

The nginx and Certbot stack is defined in:

```text
/srv/nginx/compose.yml
```

Reference Compose file:

```yaml
services:
  nginx:
    image: nginx:stable-alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./snippets:/etc/nginx/snippets:ro
      - ./certbot/www:/var/www/certbot:ro
      - ./certbot/conf:/etc/letsencrypt
      - ./logs:/var/log/nginx
    networks:
      - proxy

  certbot:
    image: certbot/certbot:latest
    container_name: certbot
    profiles: ["manual"]
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt

networks:
  proxy:
    external: true
```

### Important Notes

- nginx is the long-running web server.
- Certbot is not a long-running web server.
- Certbot is run as a one-shot container for issuing or renewing certificates.
- `profiles: ["manual"]` prevents Certbot from starting every time nginx starts.
- nginx and Certbot share:
  - `/var/www/certbot` for ACME challenge files
  - `/etc/letsencrypt` for certificate storage

---

## DNS Setup

The domain is registered through Spaceship, while DNS is routed through Cloudflare.

For public nginx + Certbot HTTP-01 validation, the relevant DNS record should be managed in Cloudflare.

Example record:

```text
Type: A
Name: cloud
Content: <home public WAN IPv4>
Proxy status: DNS only
TTL: Auto
```

For this setup:

```text
cloud.alex-ashworth.com -> home public WAN IP
```

During initial certificate issuance, Cloudflare proxying should remain disabled for the target hostname.

Use:

```text
DNS only / gray cloud
```

Do not use:

```text
Proxied / orange cloud
```

until the origin certificate and HTTPS configuration are working.

---

## Router Port Forwarding

The router must forward public web traffic to the M920 host.

Required forwards:

```text
WAN TCP 80  -> M920 LAN IP TCP 80
WAN TCP 443 -> M920 LAN IP TCP 443
```

The destination should be the M920's normal LAN IP, such as:

```text
192.168.1.x
```

It should not be:

```text
Docker container IP
Tailscale 100.x.x.x IP
Cloudflare IP
```

Find the M920 LAN IP with:

```bash
ip route get 1.1.1.1
```

Look for the `src` address.

A DHCP reservation should be configured on the router so the M920 keeps the same LAN IP.

---

## Current Bootstrap vhost

Before an application container exists, nginx should not proxy to that application yet.

For example, do not use this until Nextcloud exists and is attached to the `proxy` network:

```nginx
proxy_pass http://nextcloud-app:80;
```

A temporary bootstrap vhost can be used instead:

```nginx
server {
    listen 80;
    server_name cloud.alex-ashworth.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 "nginx bootstrap is working\n";
    }
}
```

This confirms that nginx can answer for the domain before any backend application exists.

---

## Local Validation

Validate the Compose file:

```bash
cd /srv/nginx
docker compose config
```

Start nginx:

```bash
docker compose up -d nginx
```

Check the container:

```bash
docker compose ps
docker logs nginx --tail 100
```

Validate nginx syntax:

```bash
docker exec nginx nginx -t
```

Test local nginx using the real hostname while bypassing public DNS and router forwarding:

```bash
curl -I --resolve cloud.alex-ashworth.com:80:127.0.0.1 http://cloud.alex-ashworth.com
```

Expected result:

```text
HTTP/1.1 200 OK
```

Test the ACME challenge webroot:

```bash
mkdir -p /srv/nginx/certbot/www/.well-known/acme-challenge
echo "acme test ok" > /srv/nginx/certbot/www/.well-known/acme-challenge/test

curl --resolve cloud.alex-ashworth.com:80:127.0.0.1 \
  http://cloud.alex-ashworth.com/.well-known/acme-challenge/test
```

Expected result:

```text
acme test ok
```

---

## Public Validation

After DNS and router forwarding are configured, test from outside the LAN if possible.

Recommended test:

```text
Open http://cloud.alex-ashworth.com from a phone on cellular data
```

Testing from inside the LAN may fail if the router does not support NAT loopback/hairpin NAT.

From the M920, this may or may not work depending on the router:

```bash
curl -I http://cloud.alex-ashworth.com
```

If local `--resolve` works but public access does not, check:

- Cloudflare DNS record points to the correct WAN IP
- Cloudflare record is set to DNS only
- Router forwards TCP 80 and 443 to the M920 LAN IP
- UFW allows TCP 80 and 443
- ISP is not blocking inbound ports

---

## Initial Certificate Issuance

Run Certbot once per new hostname or certificate lineage.

Example for Nextcloud's future hostname:

```bash
cd /srv/nginx

docker compose run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d cloud.alex-ashworth.com \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email
```

Flag summary:

| Flag | Purpose |
|---|---|
| `certonly` | Obtain a certificate but do not modify nginx automatically |
| `--webroot` | Use an existing web server and shared webroot for validation |
| `-w /var/www/certbot` | Path where challenge files are written inside the Certbot container |
| `-d cloud.alex-ashworth.com` | Domain name to include on the certificate |
| `--email` | Email for expiration and security notices |
| `--agree-tos` | Accept the Let's Encrypt subscriber agreement |
| `--no-eff-email` | Do not subscribe the email address to EFF communications |

Generated certificates are stored on the host under:

```text
/srv/nginx/certbot/conf
```

Inside the nginx container, the same data appears as:

```text
/etc/letsencrypt
```

---

## Converting a Service to HTTPS

After a certificate exists and the backend application exists, replace the bootstrap vhost with an HTTPS reverse proxy.

Example for future Nextcloud use:

```nginx
server {
    listen 80;
    server_name cloud.alex-ashworth.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name cloud.alex-ashworth.com;

    ssl_certificate /etc/letsencrypt/live/cloud.alex-ashworth.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloud.alex-ashworth.com/privkey.pem;

    include /etc/nginx/snippets/ssl-params.conf;

    location / {
        proxy_pass http://nextcloud-app:80;
        include /etc/nginx/snippets/proxy-common.conf;
    }
}
```

Reload nginx after changes:

```bash
docker exec nginx nginx -t
docker exec nginx nginx -s reload
```

Do not enable the `proxy_pass http://nextcloud-app:80;` line until the Nextcloud container exists and is connected to the `proxy` network.

---

## Certificate Renewal

Existing certificates are renewed automatically with a scheduled job.

```bash
/etc/systemd/system/certbot-renew-docker.service
/etc/systemd/system/certbot-renew-docker.timer
```


`certbot renew` checks every certificate lineage under:

```text
/srv/nginx/certbot/conf
```

---

## Adding Future Services

For each new public service:

1. Create the service container stack.
2. Attach the service to the `proxy` Docker network.
3. Create an nginx HTTP bootstrap vhost.
4. Create a Cloudflare DNS record pointing to the home WAN IP.
5. Keep the DNS record set to DNS only for initial validation.
6. Confirm router forwarding still works.
7. Issue a certificate with Certbot.
8. Replace the bootstrap vhost with an HTTPS reverse proxy.
9. Reload nginx.
10. Confirm HTTPS works.
11. Confirm Certbot renewal sees the certificate.

General flow:

```text
Bootstrap HTTP vhost
    ↓
Issue certificate
    ↓
Convert vhost to HTTPS
    ↓
Reverse proxy to application container
```

---

## Useful Commands

Check running containers:

```bash
cd /srv/nginx
docker compose ps
```

View nginx logs:

```bash
docker logs nginx --tail 100
```

Validate nginx config:

```bash
docker exec nginx nginx -t
```

Reload nginx:

```bash
docker exec nginx nginx -s reload
```

Show full loaded nginx config:

```bash
docker exec nginx nginx -T
```

Check host port bindings:

```bash
sudo ss -tulpn | grep -E ':80|:443'
```

Check Docker published ports:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

Check DNS:

```bash
dig +short cloud.alex-ashworth.com
```

Check certificate dates after issuance:

```bash
openssl s_client -connect cloud.alex-ashworth.com:443 \
  -servername cloud.alex-ashworth.com </dev/null 2>/dev/null \
  | openssl x509 -noout -dates -subject
```

---

## Troubleshooting Notes

### `curl http://127.0.0.1` resets

This can happen when nginx has no default server for `127.0.0.1`, or a catch-all server block intentionally resets unmatched requests.

Use the real hostname with `--resolve` instead:

```bash
curl -I --resolve cloud.alex-ashworth.com:80:127.0.0.1 http://cloud.alex-ashworth.com
```

### `host not found in upstream "nextcloud-app"`

nginx is trying to proxy to a container that does not exist or is not attached to the `proxy` network.

Fix:

- Use the temporary bootstrap vhost until the application exists.
- Confirm the app container is attached to the `proxy` network.
- Confirm the upstream name matches the actual container or service name.

### Public domain fails but local `--resolve` works

The local nginx configuration is likely working. Check:

- Cloudflare DNS record
- WAN IP
- Router port forwarding
- UFW
- ISP port blocking
- NAT loopback limitations when testing from inside the LAN

### Certificate renewal fails

Check:

- nginx is running
- port 80 is reachable from the public internet
- the vhost still includes the ACME challenge location
- DNS still points to the correct public IP
- router forwarding still points to the M920 LAN IP

---

## Backup Notes

The nginx stack should be included in the host backup plan.

Important paths:

```text
/srv/nginx/compose.yml
/srv/nginx/conf.d/
/srv/nginx/snippets/
/srv/nginx/certbot/conf/
/srv/nginx/certbot/www/
/srv/nginx/logs/
```

The most important directory is:

```text
/srv/nginx/certbot/conf
```

This contains Let's Encrypt account and certificate data used by Certbot.

---

## Current Operating Model

- nginx runs continuously as the public web entry point.
- Certbot runs only when issuing or renewing certificates.
- Cloudflare provides DNS, but the initial HTTP-01 validation path uses DNS-only records.
- The router forwards TCP 80 and 443 to the M920 host.
- Docker publishes host ports 80 and 443 to the nginx container.
- Public applications should be attached to the `proxy` Docker network.
- HTTPS vhosts should only proxy to backend containers that already exist and are reachable from nginx.
