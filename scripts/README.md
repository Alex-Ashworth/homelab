# Homelab scripts

These tracked Bash scripts support certificate and Restic maintenance. Their systemd definitions are documented in [../services/README.md](../services/README.md).

| Script | Purpose |
| --- | --- |
| `certbot-create-docker.sh` | Requests a named certificate with the Dockerized Certbot Cloudflare DNS plugin, then reloads Nginx. |
| `certbot-renew-docker.sh` | Runs Dockerized Certbot renewal, then reloads Nginx. |
| `restic-backup.sh` | Creates a Restic backup for supported hosts. |
| `restic-check.sh` | Checks each local repository with a 5 percent data read subset. |
| `restic-prune.sh` | Applies Restic retention and prunes repository data. |

## Restic behavior

The backup script supports `M920`, `M710`, `omarchy`, and `omarchy-x`. It backs up `/srv`, `/home/alex`, and `/etc`, using the host-specific exclusion file under `/srv/restic/excludes/` and host plus `homelab` tags.

Check and prune scripts operate on the local repositories named for those hosts. Checks use `--read-data-subset=5%`. Retention keeps 7 last, 14 daily, 8 weekly, and 12 monthly snapshots before pruning.

## Schedules

Scripts are definitions, not proof of an active schedule. In the 2026-07-23 snapshot, only the nightly `restic-backup@M920.timer` is active. The weekly Certbot renewal, Restic check, and Restic prune timers are defined but inactive.
