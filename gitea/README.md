# Gitea Service README

## Overview

Gitea is the self-hosted Git service for this homelab. It provides a web interface for repositories, users, issues, and project management, while PostgreSQL stores the application database.

The deployment follows the standard homelab service pattern:

- Gitea runs in Docker.
- PostgreSQL runs as a separate Docker container.
- nginx handles public HTTPS access to the web UI.
- Git-over-SSH is available privately through Tailscale only.
- Persistent data is stored on the large storage mount under `/srv/storage/docker/...`.

---

## Service URLs

| Purpose | URL |
|---|---|
| Public Gitea Web UI | `https://gitea.alex-ashworth.com` |
| Git-over-SSH hostname | `git.alex-ashworth.com` |

The web UI is public through nginx and Let’s Encrypt.

Git-over-SSH is private and bound to the host’s Tailscale IP only.

---

## Directory Layout

```text
/srv/gitea/
  compose.yml
  gitea.env
  README.md

/srv/storage/docker/gitea/data/
  Gitea application data, repositories, config, SSH keys, packages, LFS data

/srv/storage/docker/postgres/gitea/data/
  PostgreSQL database files
```

Important data paths:

```text
Gitea data:
  /srv/storage/docker/gitea/data

Gitea repositories:
  /srv/storage/docker/gitea/data/git/repositories

Gitea config:
  /srv/storage/docker/gitea/data/gitea/conf/app.ini

PostgreSQL data:
  /srv/storage/docker/postgres/gitea/data
```

---

## Docker Compose Layout

The stack contains two containers:

| Container | Purpose |
|---|---|
| `gitea` | Gitea application server |
| `postgres-gitea` | PostgreSQL database for Gitea |

The Gitea container is attached to two Docker networks:

| Network | Purpose |
|---|---|
| `gitea_gitea-internal` | Private communication between Gitea and PostgreSQL |
| `proxy` | Shared network used by nginx to reach Gitea |

PostgreSQL is only attached to the internal Gitea network.

---

## Port Layout

| Host Binding | Container Port | Purpose |
|---|---:|---|
| `127.0.0.1:3000` | `3000` | Local Gitea web port, used for host-side testing |
| `<tailscale-ip>:<custom-ssh-port>` | `22` | Git-over-SSH through Tailscale only |

The Gitea web UI is not published directly to the public internet by Docker. Public web traffic goes through nginx.

Git-over-SSH is not exposed publicly and should not be forwarded on the router.

---

## nginx Reverse Proxy

nginx serves:

```text
https://gitea.alex-ashworth.com
```

The nginx vhost proxies to the Gitea container over the shared Docker `proxy` network:

```nginx
proxy_pass http://gitea:3000;
```

This works because both `nginx` and `gitea` are attached to the external Docker network named `proxy`.

Basic nginx checks:

```bash
docker exec nginx nginx -t
docker exec nginx nginx -s reload
curl -I https://gitea.alex-ashworth.com
```

---

## TLS / Let’s Encrypt

The Gitea web UI uses a Let’s Encrypt certificate managed by the Dockerized Certbot setup under the nginx stack.

Certificate files are stored under:

```text
/srv/nginx/certbot/conf
```

The nginx vhost uses:

```text
/etc/letsencrypt/live/gitea.alex-ashworth.com/fullchain.pem
/etc/letsencrypt/live/gitea.alex-ashworth.com/privkey.pem
```

Renewal is handled by the existing nginx/certbot renewal process. Since Certbot uses `renew`, any valid certificate stored in the nginx Certbot volume should be renewed automatically.

---

## Environment File

The service uses:

```text
/srv/gitea/gitea.env
```

This file stores database settings, Gitea server settings, and other runtime configuration.

The PostgreSQL password and Gitea database password must match:

```env
POSTGRES_PASSWORD=<database-password>
GITEA__database__PASSWD=<database-password>
```

A hex password is preferred to avoid shell or Docker Compose parsing issues with special characters.

Example password generation:

```bash
openssl rand -hex 32
```

---

## Git-over-SSH Design

Git-over-SSH is enabled privately through Tailscale.

The Docker container’s internal SSH port remains:

```text
22
```

The host exposes that port only on the Tailscale IP using a custom high port:

```yaml
ports:
  - "<tailscale-ip>:<custom-ssh-port>:22"
```

The Gitea SSH settings should look like this conceptually:

```ini
START_SSH_SERVER = false
SSH_DOMAIN = git.alex-ashworth.com
SSH_PORT = <custom-ssh-port>
SSH_LISTEN_PORT = 22
```

Important:

- `START_SSH_SERVER = false` is intentional.
- The Docker image already runs an SSH daemon inside the container.
- Enabling Gitea’s internal SSH server as well can cause a port conflict on container port `22`.

Test SSH from a Tailscale-connected client:

```bash
ssh -p <custom-ssh-port> git@git.alex-ashworth.com
```

A successful test should authenticate but not provide a normal shell.

Example clone URL:

```bash
git clone ssh://git@git.alex-ashworth.com:<custom-ssh-port>/<user>/<repo>.git
```

---

## User Model

Recommended account model:

| Account Type | Purpose |
|---|---|
| Admin account | Site administration, user management, recovery |
| Regular user | Daily Git work, repositories, SSH keys, tokens |

Public registration should remain disabled.

Check in `app.ini`:

```ini
DISABLE_REGISTRATION = true
```

Or from the web UI:

```text
Site Administration → Configuration → Service
```

---

## Common Commands

Start or update the stack:

```bash
cd /srv/gitea
docker compose up -d
```

Stop the stack:

```bash
cd /srv/gitea
docker compose down
```

Restart Gitea only:

```bash
cd /srv/gitea
docker compose restart gitea
```

View status:

```bash
cd /srv/gitea
docker compose ps
```

View logs:

```bash
docker logs gitea --tail 100
docker logs postgres-gitea --tail 100
```

Follow logs live:

```bash
docker logs -f gitea
```

Check port mappings:

```bash
docker port gitea
```

Expected port mappings should include:

```text
3000/tcp -> 127.0.0.1:3000
22/tcp -> <tailscale-ip>:<custom-ssh-port>
```

---

## Health Checks

Local Gitea web test:

```bash
curl -I http://127.0.0.1:3000
```

Public web test:

```bash
curl -I https://gitea.alex-ashworth.com
```

nginx config test:

```bash
docker exec nginx nginx -t
```

Docker network check:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}'
```

Gitea should show both:

```text
gitea_gitea-internal
proxy
```

PostgreSQL should show:

```text
gitea_gitea-internal
```

nginx should show:

```text
proxy
```

---

## Backup Notes

Back up both Gitea and PostgreSQL data.

Required paths:

```text
/srv/gitea
/srv/storage/docker/gitea/data
/srv/storage/docker/postgres/gitea/data
```

The Gitea data path contains repositories, configuration, SSH keys, LFS data, packages, and other application files.

The PostgreSQL path contains database state such as users, permissions, issues, settings, and metadata.

For a stronger backup strategy, add PostgreSQL dumps in addition to file-level restic backups.

Example dump command:

```bash
mkdir -p /srv/storage/docker/gitea/data/gitea/backups

docker exec postgres-gitea pg_dump -U gitea gitea > /srv/storage/docker/gitea/data/gitea/backups/gitea-$(date +%F).sql
```

---

## Troubleshooting

### nginx returns 502

Likely causes:

- Gitea container is not running.
- Gitea is crash-looping.
- Gitea is not attached to the `proxy` Docker network.
- nginx cannot resolve `gitea`.

Check:

```bash
docker compose ps
docker logs gitea --tail 100
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}'
docker exec nginx nginx -t
```

---

### Gitea container keeps restarting

Check logs:

```bash
docker logs gitea --tail 150
```

A known issue from this setup was an SSH conflict:

```text
listen tcp :22: bind: address already in use
```

Fix:

```ini
START_SSH_SERVER = false
```

in:

```text
/srv/storage/docker/gitea/data/gitea/conf/app.ini
```

Then restart:

```bash
cd /srv/gitea
docker compose restart gitea
```

---

### Database password errors

If PostgreSQL was initialized with the wrong password, changing `gitea.env` afterward will not update the existing database user password.

For a fresh setup only, stop the stack and clear the bad initialized data directory:

```bash
cd /srv/gitea
docker compose down

sudo find /srv/storage/docker/postgres/gitea/data -mindepth 1 -delete
sudo find /srv/storage/docker/gitea/data -mindepth 1 -delete

docker compose up -d
```

Do not run this on an active install with data you care about.

---

## Update Procedure

Update images:

```bash
cd /srv/gitea
docker compose pull
docker compose up -d
```

Then verify:

```bash
docker compose ps
docker logs gitea --tail 100
curl -I https://gitea.alex-ashworth.com
```

Before major updates, confirm a recent backup exists.

---

## Security Notes

- Public access is limited to the web UI through nginx on ports `80` and `443`.
- Git-over-SSH is bound to the Tailscale IP only.
- Do not forward the custom Git SSH port on the router.
- Public registration should remain disabled.
- Keep the admin account separate from the daily-use account if possible.
- Use strong passwords and store secrets only in `gitea.env`, not in Git.

---

## Final Architecture Summary

```text
Internet
  ↓
Cloudflare DNS
  ↓
gitea.alex-ashworth.com
  ↓
Router forwards 80/443 only
  ↓
Dockerized nginx
  ↓
Docker proxy network
  ↓
Gitea container on port 3000
  ↓
PostgreSQL on private Docker network
```

Git-over-SSH path:

```text
Tailscale client
  ↓
git.alex-ashworth.com
  ↓
Tailscale IP on custom SSH port
  ↓
Gitea container port 22
```
