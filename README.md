# M920 Homelab

This repository is the public showcase for the M920 homelab. The private, live source of truth is `/srv` on M920; only non-secret documentation and declarative configuration are mirrored here.

**Runtime snapshot:** 2026-07-23. Sanitized status reported 19 running Compose projects; CrowdSec is configured but inactive.

## Architecture

```text
Internet ──> Nginx (80/443) ──> public portfolio / Gitea HTTPS
Tailscale ──> Nginx ─────────> restricted application vhosts
LAN ───────> Pi-hole DNS ────> Unbound
                         |
                 proxy / telemetry / security / backup
                         |
                 application and telemetry stacks
```

`proxy` connects Nginx-facing applications, `telemetry` connects monitoring and log collection, `security` is reserved for CrowdSec, and `backup` connects backup services. Authentik, Gitea, Nextcloud, and Pi-hole also define stack-private bridge networks.

## Access and certificates

- The portfolio at `alex-ashworth.com` remains public; `gitea.alex-ashworth.com` HTTPS is also currently public.
- `auth`, `backup`, `cloud`, `grafana`, `hub`, `ntfy`, `pihole`, and `uptime` vhosts are restricted to Tailscale and the proxy network.
- Gitea SSH binds to the M920 Tailscale address. Pi-hole DNS binds to the LAN address.
- Backrest and the Restic REST server bind directly to the M920 Tailscale address.
- Exporters and internal HTTP services use loopback bindings where declared; services without host ports remain internal to their Compose networks.
- Let's Encrypt certificates are issued by Certbot through the Cloudflare DNS-01 plugin.

## Stacks

| Project | Role | Access | State |
| --- | --- | --- | --- |
| [alloy](alloy/README.md) | Host, Nginx, and Docker log collector | telemetry | Running |
| [authentik](authentik/README.md) | Identity service with PostgreSQL and Redis | Tailnet vhost | Running |
| [backrest](backrest/README.md) | Backup management UI and restore staging | Tailscale and tailnet vhost | Running |
| [cadvisor](cadvisor/README.md) | Container metrics exporter | Loopback and telemetry | Running |
| [crowdsec](crowdsec/README.md) | Planned host and Nginx security analysis | security and telemetry when enabled | Configured, inactive |
| [diun](diun/README.md) | Image update notifier | telemetry | Running |
| [gitea](gitea/README.md) | Git service with PostgreSQL | Public HTTPS; Tailscale SSH | Running |
| [github-mirror-controller](github-mirror-controller/README.md) | GitHub-to-GitLab/Gitea mirror controller | Outbound service | Running |
| [grafana](grafana/README.md) | Metrics and log visualization | Loopback, telemetry, tailnet vhost | Running |
| [homepage](homepage/README.md) | Service dashboard | Loopback and tailnet vhost | Running |
| [loki](loki/README.md) | Local log store | Loopback, proxy, telemetry | Running |
| [nextcloud](nextcloud/README.md) | Files service with MariaDB, Redis, and ClamAV | Tailnet vhost | Running |
| [nginx](nginx/README.md) | TLS reverse proxy and Certbot client | Public 80/443 | Running |
| [node-exporter](node-exporter/README.md) | Host metrics exporter | Loopback and telemetry | Running |
| [ntfy](ntfy/README.md) | Authenticated notifications | Loopback, telemetry, tailnet vhost | Running |
| [pihole](pihole/README.md) | LAN DNS with Unbound | LAN DNS; loopback and tailnet UI | Running |
| [prometheus](prometheus/README.md) | Metrics collection | Loopback, proxy, telemetry | Running |
| [restic](restic/README.md) | REST backup repository server | Tailscale and backup | Running |
| [smartctl-exporter](smartctl-exporter/README.md) | Disk SMART metrics exporter | Loopback and telemetry | Running |
| [uptime-kuma](uptime-kuma/README.md) | Availability monitoring | Loopback, telemetry, tailnet vhost | Running |

## Storage and backups

Persistent service data is declared under project directories and mounted storage. `/srv/storage/services` is a protected namespace; its immediate service entries are Gitea, Loki, Nextcloud, and Prometheus, and their contents are intentionally not documented here. The storage layout also includes backup and shared paths. Backrest mounts `/srv`, `/etc`, and `/home` read-only for backup management, while the Restic server uses the local backup area.

The `restic-backup@M920.timer` nightly backup is the only active managed timer in the 2026-07-23 snapshot. Certbot renewal and Restic repository check/prune units are defined but inactive. See [scripts](scripts/README.md) and [services](services/README.md).

## Change records

Operational change records remain in the private `/srv/.homelab/changes` directory and are not mirrored here.
