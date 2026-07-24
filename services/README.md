# Managed service and timer definitions

These unit files define certificate and Restic maintenance. Live state below is the sanitized M920 snapshot from 2026-07-23; definitions do not themselves enable a timer. Supporting scripts are documented in [../scripts/README.md](../scripts/README.md).

| Service / timer | Schedule | Live state |
| --- | --- | --- |
| `restic-backup@.service` | Started by `restic-backup@.timer` | Definition present |
| `restic-backup@.timer` | Daily at 03:00 with up to 5-minute randomized delay | `restic-backup@M920.timer` active |
| `certbot-renew-docker.service` | Started by `certbot-renew-docker.timer` | Definition present; inactive |
| `certbot-renew-docker.timer` | Sunday 01:00 | Defined; inactive |
| `restic-prune.service` | Started by `restic-prune.timer` | Definition present; inactive |
| `restic-prune.timer` | Sunday 03:30 with up to 5-minute randomized delay | Defined; inactive |
| `restic-check.service` | Started by `restic-check.timer` | Definition present; inactive |
| `restic-check.timer` | Sunday 03:45 with up to 5-minute randomized delay | Defined; inactive |

All four timers are persistent. The active nightly M920 backup runs the tracked Restic backup script. Weekly Certbot renewal, repository check, and prune remain defined but were not active in the snapshot.
