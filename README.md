# Homelab

This repository is the source of truth for my homelab.

It tracks important files, service notes, configs, scripts, firewall rules, backup plans.

- Keep important homelab configuration version-controlled
- Document how each service is deployed
- Track what runs where
- Make rebuilds and migrations easier
- Avoid losing setup details
- Keep backups, networking, firewall rules, and service dependencies organized

This repo should not contain real secrets, passwords, private keys, tokens, or live credentials.

---

## Current Repository Layout

```text
.
├── docker/
├── docs/
├── gitea/
├── grafana/
├── loki/
├── nextcloud/
├── nginx/
├── ntfy/
├── pihole/
├── postgres/
├── prometheus/
├── proxmox/
├── restic/
├── samba/
├── tailscale/
├── templates/
├── ufw/
├── unbound/
├── uptime-kuma/
├── .gitignore
└── README.md
```

---

## Service Overview

| Directory | Purpose |
|---|---|
| `docker/` | Shared Docker notes, compose conventions, networks, and general container setup |
| `git/` | Git repo notes, workflow, repo management, or general version-control documentation |
| `gitea/` | Self-hosted Git service configuration and notes |
| `grafana/` | Dashboards and visualization for monitoring |
| `loki/` | Log aggregation backend for Grafana |
| `nextcloud/` | File sync, cloud storage, and personal cloud service |
| `nginx/` | Reverse proxy, TLS, routing, and web entrypoint configuration |
| `ntfy/` | Self-hosted push notification service |
| `pihole/` | DNS filtering and ad-blocking service |
| `postgres/` | PostgreSQL database notes, shared database config, or service-specific DB documentation |
| `prometheus/` | Metrics collection and monitoring backend |
| `restic/` | Backup scripts, prune/check timers, repo notes, and restore documentation |
| `samba/` | SMB file sharing configuration and storage share notes |
| `tailscale/` | Private network access for SSH, internal service connections, and secure access to NGINX-routed web services |
| `ufw/` | Firewall rules, policies, and host access documentation |
| `unbound/` | Recursive DNS resolver configuration, likely paired with Pi-hole |
| `uptime-kuma/` | Service uptime monitoring and alerting |

---

## Homelab Philosophy

This homelab is intended to be:

- Private-first
- Easy to rebuild
- Well-documented
- Backed up
- Mostly self-hosted
- Accessible remotely through secure methods
- Minimal in public exposure
- Clear enough that future me can understand it

The preferred access model is:

```text
User device
    ↓
Tailscale / LAN / HTTPS
    ↓
NGINX reverse proxy
    ↓
Docker services
    ↓
Persistent service data
```

Public exposure should be intentional, not accidental.

---

## Secrets Policy

Do **not** commit real secrets.

Never commit:

- `.env` files with real values
- Password files
- Restic passwords
- SSH private keys
- API tokens
- Cloudflare tokens
- Tailscale auth keys
- Database passwords
- TLS private keys
- Real `htpasswd` files
- Any file containing live credentials

Use example files instead:

```text
.env.example
compose.example.yml
restic.env.example
config.example.yml
```

Real secrets should live only on the host that needs them.

---

## Expected Per-Service Layout

Not every service needs every file, but each important service should at least document:

- What it does
- Where it runs
- How it starts
- What ports it uses
- What volumes/data matter
- Whether it is backed up
- How to restore it
- What other services it depends on

---

## Docker Notes

Docker Compose is the preferred deployment method for most services.

Preferred compose filename:

```text
compose.yml
```

Common commands:

```bash
docker compose up -d
docker compose down
docker compose pull
docker compose logs -f
docker compose ps
docker compose restart
```

Useful checks:

```bash
docker ps
docker network ls
docker volume ls
docker system df
```

---

## Docker Networks

Planned/common Docker networks:

```bash
docker network create proxy
docker network create telemetry
```

### `proxy`

Used for services that need to be reached by NGINX.

Example:

```text
nginx -> nextcloud
nginx -> gitea
nginx -> uptime-kuma
```

### `telemetry`

Used for monitoring/logging services.

Example:

```text
prometheus
grafana
loki
uptime-kuma
```

---

## Reverse Proxy

NGINX is the main reverse proxy.

NGINX should document:

- Public domains
- Private-only domains
- Tailscale-only routes
- TLS certificates
- Upstream container names
- Exposed ports
- ACME/Certbot behavior
- Any special service path requirements

Example proxy flow:

```text
https://service.example.com
    ↓
nginx
    ↓
http://service-container:port
```

---

## DNS Stack

DNS-related services:

```text
pihole/
unbound/
```

Expected relationship:

```text
Client devices
    ↓
Pi-hole
    ↓
Unbound
    ↓
Internet DNS root/recursive resolution
```

Pi-hole handles filtering.

Unbound handles recursive DNS resolution.

Document:

- Host IPs
- Listening ports
- Upstream DNS behavior
- Whether DNS is LAN-only or Tailscale-accessible
- Firewall requirements
- Client configuration

---

## Monitoring Stack

Monitoring/logging-related services:

```text
prometheus/
grafana/
loki/
uptime-kuma/
```

Expected roles:

| Service | Role |
|---|---|
| Prometheus | Metrics collection |
| Grafana | Dashboards and visualization |
| Loki | Log aggregation |
| Uptime Kuma | Uptime checks and alerting |

Document:

- What each service monitors
- What exporters are used
- Where dashboards live
- Alerting destinations
- Retention settings
- Storage requirements

---

## Notification Stack

Notification-related service:

```text
ntfy/
```

Use this for sending homelab alerts, backup status messages, service health notifications, and other automated messages.

Potential integrations:

- Restic backup success/failure
- Uptime Kuma alerts
- Prometheus/Grafana alerts
- System maintenance reminders
- Docker update notifications

---

## Storage and File Sharing

Storage/share-related service:

```text
samba/
```

Samba should document:

- Shared directories
- Permissions
- Ownership
- Valid users
- LAN access
- Tailscale access
- Firewall rules
- Mount examples for Linux
- Access examples for Windows

Example documentation target:

```text
samba/
├── README.md
├── smb.conf.example
├── shares.md
└── permissions.md
```

---

## Backups

Backup-related service:

```text
restic/
```

Restic is used for encrypted backups.

Restic documentation should include:

- Repository locations
- Per-host backup targets
- Backup scripts
- Prune policy
- Check policy
- Systemd timers
- Restore process
- Password file locations
- What is and is not backed up


Example retention policy:

```text
keep last 7
keep daily 14
keep weekly 8
keep monthly 12
```

A backup does not count unless it has been tested with a restore.

---

## Firewall

Firewall-related directory:

```text
ufw/
```

UFW documentation should include:

- Current firewall status
- Numbered rules
- Required open ports
- Tailscale rules
- LAN-only service rules
- Public service rules
- Removed/deprecated rules

Useful commands:

```bash
sudo ufw status verbose
sudo ufw status numbered
```

General policy:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

Common allowed services may include:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow in on tailscale0
```

Only open what is actually needed.

---

## Gitea

### `gitea/`

Use for the self-hosted Git service.

Gitea documentation should include:

- Compose file
- Data location
- SSH port
- HTTP port
- Reverse proxy config
- Backup process
- Restore process
- Admin user notes
- Database dependency

---

## PostgreSQL

Database-related directory:

```text
postgres/
```

Use this for shared PostgreSQL documentation or service-specific database notes.

Document:

- Which services use Postgres
- Database names
- Users
- Backup method
- Restore method
- Volume locations
- Port exposure policy

Do not commit real database passwords.

---

## Tailscale

Tailscale provides the private network layer for the homelab.

It is used for secure remote access, private host-to-host communication, SSH access, and controlled access to internal services. The goal is to keep administrative access and internal service traffic private while minimizing directly exposed ports on the LAN or public internet.

### Primary Uses

| Use Case | Purpose |
|---|---|
| SSH access | Provide secure administrative access to homelab hosts without exposing port `22` publicly |
| Internal service connectivity | Allow trusted devices and hosts to communicate over the private tailnet |
| Private service access | Access internal dashboards, admin panels, and management interfaces without public exposure |
| NGINX-backed web access | Support web services that are routed through NGINX, including services that may be exposed publicly when needed |
| Remote administration | Manage the homelab securely from approved devices outside the local network |

### Access Model

```text
Admin device
    ↓
Tailscale
    ↓
Homelab host
    ↓
NGINX / Docker / internal services
## Nextcloud

Nextcloud-related directory:

```text
nextcloud/
```

Document:

- Compose setup
- Data directory
- Database backend
- Redis/cache usage
- Reverse proxy config
- Trusted domains
- Upload limits
- Backup requirements
- Restore process
- Migration notes

Important things to track:

```text
Nextcloud app config
Nextcloud data directory
Database
Redis/cache config
NGINX config
Background jobs
```

---

## Service Access Matrix

| Service | Public | LAN | Tailscale | Notes |
|---|---:|---:|---:|---|
| NGINX | Maybe | Yes | Yes | Main reverse proxy |
| Nextcloud | Maybe | Yes | Yes | Depends on final exposure decision |
| Gitea | Maybe | Yes | Yes | Prefer private unless needed |
| Grafana | No | Maybe | Yes | Prefer private |
| Prometheus | No | Maybe | Yes | Internal only |
| Loki | No | Maybe | Yes | Internal only |
| Uptime Kuma | No | Maybe | Yes | Private dashboard preferred |
| Pi-hole | No | Yes | Maybe | DNS only where needed |
| Unbound | No | Internal | No | Usually only Pi-hole talks to it |
| ntfy | Maybe | Yes | Yes | Depends on notification needs |
| Samba | No | Yes | Yes | Never public |
| Restic | No | Yes | Yes | Never public |
| Postgres | No | Internal | No | Never public directly |

---

## Maintenance Checklist

General checks:

```bash
docker ps
docker compose ps
docker network ls
systemctl list-timers
sudo ufw status numbered
tailscale status
```

Storage checks:

```bash
df -h
lsblk
findmnt
```

Docker cleanup checks:

```bash
docker system df
docker image ls
docker volume ls
```

Backup checks:

```bash
restic snapshots
restic check
```

Logs:

```bash
journalctl -xe
docker compose logs -f
```

---

## Change Log

Major changes should be recorded here or in a dedicated changelog file.

Example:

```md
## 2026-05-02

### Added

- Created initial homelab repo structure
- Added directories for planned services
- Started tracking Restic backup configuration
- Started tracking UFW firewall rules

### Changed

- Standardized on service-specific directories
- Set this repo as the main homelab source of truth

### Notes

- Do not commit real `.env` files
- Add `.env.example` files instead
```

---

## Rebuild Priority

If the homelab needs to be rebuilt, restore in this general order:

1. Base OS
2. SSH or Tailscale access
3. Storage mounts
4. UFW/firewall baseline
5. Docker
6. Docker networks
7. NGINX reverse proxy
8. DNS stack: Pi-hole and Unbound
9. Backup access: Restic
10. Core services: Nextcloud, Gitea, Samba
11. Monitoring: Prometheus, Grafana, Loki, Uptime Kuma
12. Notifications: ntfy
13. Final dashboards, alerts, and cleanup

---

## Current Status

| Area | Status | Notes |
|---|---|---|
| Docker | Planned/In Progress | Shared service deployment method |
| NGINX | Planned/In Progress | Main reverse proxy |
| DNS | Planned/In Progress | Pi-hole + Unbound |
| Backups | In Progress | Restic setup being finalized |
| File Sharing | Planned/In Progress | Samba |
| Monitoring | Planned | Prometheus, Grafana, Loki, Uptime Kuma |
| Notifications | Planned | ntfy |
| Git Hosting | Planned | Gitea |
| Cloud Storage | Planned/In Progress | Nextcloud |
| Firewall | In Progress | UFW rules tracked here |

---

## Final Note

This repo exists so I do not have to reverse-engineer my own homelab six months from now.

When something important changes, document it.

Future me will appreciate it.
