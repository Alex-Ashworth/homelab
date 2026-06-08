# Backrest, restic, and rest-server Homelab Backup Setup

**Primary backup server:** `M920`  
**Primary service root:** `/srv`  
**Backrest service path:** `/srv/backrest`  
**Backup storage root on host:** `/srv/storage/backups/restic`  
**Backup storage path inside M920 Backrest:** `/mnt/backups`  
**Access model:** private/Tailscale-only  
**Last updated:** 2026-06-08

This README documents the current backup model after moving away from the older hand-written restic backup/prune/check systemd timers.

No real passwords, repo passwords, `.htpasswd` secrets, tokens, or private URLs should be committed into this README.

---

## 1. Current mental model

```text
restic      = the actual encrypted backup engine
Backrest    = web UI, scheduler, plan manager, snapshot browser, restore helper
restic repo = where encrypted backup data lives
rest-server = HTTP REST backend that remote Backrest/restic clients use to reach repos on M920
```

Backrest does **not** replace restic. Backrest runs and manages restic.

rest-server does **not** schedule backups. It only exposes the repository storage over HTTP so remote machines can write to/read from their own restic repos on the M920 backup disk.

Important recovery rule:

```text
If Backrest dies, the backups are still usable with plain restic
as long as the repo and the repo encryption password still exist.
```

Critical recovery items:

```text
1. The restic repository data
2. The restic repository encryption password
3. Backrest config, useful but not strictly required for CLI restore
```

---

## 2. Current architecture

The current setup uses Backrest multihost management with M920 as the central Backrest instance.

```text
M920 Backrest
  - central dashboard
  - owns shared repo configuration
  - manages repo-level forget/prune/check
  - runs M920 local backup plans

M710 Backrest
  - runs local M710 backup plans
  - uses shared repo config from M920
  - pushes backup data to M920 through rest-server

omarchy Backrest
  - runs local omarchy backup plans
  - uses shared repo config from M920
  - pushes backup data to M920 through rest-server

omarchy-x Backrest
  - runs local omarchy-x backup plans
  - uses shared repo config from M920
  - pushes backup data to M920 through rest-server
```

This is the chosen **Option B** model:

```text
Backups run where the files live.
Repo maintenance runs where the repos are centrally owned: M920.
rest-server provides the network path to the repos.
```

---

## 3. Repository layout

The backup disk is mounted at:

```text
/dev/sdc1 -> /srv/storage/backups
```

The restic repository root is:

```text
/srv/storage/backups/restic
```

Inside the M920 Backrest container, that path is:

```text
/mnt/backups
```

Current repo directories:

```text
/srv/storage/backups/restic/M920
/srv/storage/backups/restic/M710
/srv/storage/backups/restic/omarchy
/srv/storage/backups/restic/omarchy-x
```

Container-side equivalent on M920:

```text
/mnt/backups/M920
/mnt/backups/M710
/mnt/backups/omarchy
/mnt/backups/omarchy-x
```

---

## 4. rest-server role

rest-server serves the repository root:

```text
/srv/storage/backups/restic
```

Conceptual flow:

```text
Remote Backrest plan
  -> restic REST backend
  -> rest-server on M920
  -> /srv/storage/backups/restic/<repo>
```

Example remote repository URL shape:

```text
rest:http://USERNAME:PLAIN_HTTP_AUTH_PASSWORD@100.87.48.104:8000/M710
rest:http://USERNAME:PLAIN_HTTP_AUTH_PASSWORD@100.87.48.104:8000/omarchy
rest:http://USERNAME:PLAIN_HTTP_AUTH_PASSWORD@100.87.48.104:8000/omarchy-x
```

Use the actual M920 Tailscale IP, MagicDNS name, or verified private hostname.

Do **not** use a Docker-only service name such as this from a remote host:

```text
rest:http://USER:PASS@rest-server:8000/M710
```

`rest-server` may resolve inside M920 Docker networks, but remote Backrest containers on M710/omarchy/omarchy-x generally will not know that name.

### Authentication distinction

```text
.htpasswd password       = HTTP basic auth for rest-server access
restic repo password     = encryption password for the repository
Backrest web password    = login to the Backrest UI
```

The `.htpasswd` file contains hashes, not the plain password.

The restic repo password must be stored somewhere safe outside the server. Without it, the repo cannot be restored.

---

## 5. Backrest shared repo behavior

Repos for `M710`, `omarchy`, and `omarchy-x` are owned on M920 and shared to remote Backrest instances.

This means remote Backrest UIs may show repo entries received from M920.

That is expected.

The important rule is:

```text
M710 plans use the M710 repo.
omarchy plans use the omarchy repo.
omarchy-x plans use the omarchy-x repo.
```

Do not let a host plan write to another host's repo.

Shared repo maintenance should be configured on M920 only.

---

## 6. Backup plans

### Remote hosts

Each remote Backrest instance runs two plans.

For `M710`:

```text
M710-core
  /home
  /etc

M710-srv
  /srv
```

For `omarchy`:

```text
omarchy-core
  /home
  /etc

omarchy-srv
  /srv
```

For `omarchy-x`:

```text
omarchy-x-core
  /home
  /etc

omarchy-x-srv
  /srv
```

Because these Backrest instances are containerized, the actual plan paths should use the container mount paths configured in that host's compose file.

Example client container mappings:

```text
Host path      Container path
/home       -> /mnt/home
/etc        -> /mnt/etc
/srv        -> /mnt/srv
```

So the plans may appear as:

```text
hostname-core:
  /mnt/home
  /mnt/etc

hostname-srv:
  /mnt/srv
```

### M920 plans

M920 is split into multiple plans because `/srv/storage` contains large storage areas that should be handled separately.

```text
M920-core
  /home
  /etc

M920-srv
  /srv
  exclude /srv/storage

M920-srv-storage
  /srv/storage/services

samba
  /srv/storage/share
```

Inside the M920 Backrest container, these are expected to appear as:

```text
M920-core:
  /mnt/home
  /mnt/etc

M920-srv:
  /mnt/srv
  exclude /mnt/srv/storage/**

M920-srv-storage:
  /mnt/srv/storage/services

samba:
  /mnt/srv/storage/share
```

Always exclude the repository location:

```text
/mnt/backups/**
/mnt/srv/storage/backups/**
/mnt/srv/storage/backups/restic/**
```

Do not back up the backup repository into itself.

---

## 7. Mount rules

Use this rule everywhere:

```text
Backup source paths       = read-only
Backup repo destination   = read/write
Backrest config/data      = read/write
Restore staging target    = read/write
```

M920 example:

```yaml
volumes:
  - /srv/backrest/data:/data
  - /srv/backrest/config:/config
  - /srv/backrest/cache:/cache

  # Backup sources
  - /srv:/mnt/srv:ro
  - /home:/mnt/home:ro
  - /etc:/mnt/etc:ro

  # Repo destination
  - /srv/storage/backups/restic:/mnt/backups
```

Remote client example:

```yaml
volumes:
  - /srv/backrest/data:/data
  - /srv/backrest/config:/config
  - /srv/backrest/cache:/cache

  # Backup sources
  - /srv:/mnt/srv:ro
  - /home:/mnt/home:ro
  - /etc:/mnt/etc:ro

  # Optional restore target
  - /srv/backrest/restore:/restore
```

Remote clients normally do **not** mount `/mnt/backups`. They reach their repos through rest-server.

---

## 8. Backup, prune, and check policy

Backrest now manages normal backup, forget/prune, and check operations.

The older manual/systemd workflow has been condensed to this policy:

```text
1. Backup
2. Forget/prune
3. Check
```

Recommended cadence:

```text
Backups:       daily, per plan, on the host that owns the files
Forget/prune:  repo-level, on M920
Check:         weekly repo-level check on M920
Read-data check: occasional/monthly, not every backup
```

Do not schedule prune/check in multiple places for the same repo.

For the shared-repo model:

```text
Remote Backrest instances:
  run backup plans only

M920 Backrest:
  runs repo-level forget/prune/check
```

Manual restic commands should now be treated as recovery/debug commands only, not the normal operating workflow.

---

## 9. Legacy systemd jobs

The older layout used scripts and systemd timers such as:

```text
restic-backup.sh
restic-prune.sh
restic-check.sh
restic-backup@.timer
restic-prune.timer
restic-check.timer
```

These are now legacy if they target the same repos as Backrest.

They should remain disabled unless intentionally repurposed.

Check for old timers:

```bash
systemctl list-timers --all | grep -Ei 'restic|backup|prune|check'
systemctl list-units --all | grep -Ei 'restic|backup|prune|check'
systemctl --user list-timers --all | grep -Ei 'restic|backup|prune|check'
systemctl --user list-units --all | grep -Ei 'restic|backup|prune|check'
```

Disable old root timers if needed:

```bash
sudo systemctl disable --now restic-backup.timer
sudo systemctl disable --now restic-prune.timer
sudo systemctl disable --now restic-check.timer
```

Disable old user timers if needed:

```bash
systemctl --user disable --now restic-backup.timer
systemctl --user disable --now restic-prune.timer
systemctl --user disable --now restic-check.timer
```

---

## 10. Database dump requirement

For databases, file-level backup is useful, but database dumps are cleaner for recovery.

Backrest should eventually run pre-backup scripts that create dumps before the relevant snapshot runs.

### Nextcloud MariaDB

Expected dump location:

```text
/srv/nextcloud/backups
```

This is captured by the M920 service backup paths.

Manual dump example:

```bash
cd /srv/nextcloud
set -a
source .env
set +a
docker exec nextcloud-db mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" nextcloud > /srv/nextcloud/backups/nextcloud-$(date +%F_%H%M).sql
```

### Gitea PostgreSQL

Expected dump location:

```text
/srv/gitea/backups
```

Manual dump example:

```bash
cd /srv/gitea
set -a
source .env
set +a
docker exec postgres-gitea pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > /srv/gitea/backups/gitea-$(date +%F_%H%M).sql
```

### authentik PostgreSQL

Expected future dump location:

```text
/srv/authentik/backups
```

---

## 11. Verification commands

### Confirm M920 Backrest mounts

```bash
cd /srv/backrest
docker inspect backrest --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
```

Expected important M920 results:

```text
/srv -> /mnt/srv RW= false
/home -> /mnt/home RW= false
/etc -> /mnt/etc RW= false
/srv/storage/backups/restic -> /mnt/backups RW= true
```

### Confirm M920 can write to repo target

```bash
docker exec -it backrest sh -c 'touch /mnt/backups/backrest-write-test && rm /mnt/backups/backrest-write-test && echo OK'
```

Expected:

```text
OK
```

### Confirm remote client can reach rest-server

Run this inside the remote Backrest container:

```bash
docker exec -it backrest sh -c 'wget -S -O- --timeout=5 http://100.87.48.104:8000/M710/config 2>&1 | head -40'
```

Without auth, `401 Unauthorized` is a good sign. It means the rest-server endpoint is reachable.

A timeout, DNS failure, or `bad address` means the client cannot reach the rest-server URL.

### Confirm backup disk is mounted on M920

```bash
findmnt /srv/storage/backups/restic
df -h /srv/storage/backups/restic
lsblk -f
```

Expected: `/srv/storage/backups` should be on `/dev/sdc1`, not the root filesystem.

---

## 12. Restore testing

A backup is not proven until a restore has succeeded.

Minimum restore test:

```text
1. Pick one small file from each repo.
2. Restore it to a staging path, not directly over live data.
3. Verify the file contents.
4. Delete the test restore.
```

Recommended restore target for client containers:

```text
/restore/test-restore
```

Host-side equivalent if mounted as recommended:

```text
/srv/backrest/restore/test-restore
```

Do not restore directly over live service data unless doing a deliberate recovery.

---

## 13. CLI recovery examples

If Backrest is unavailable, use restic directly.

Local M920 repo example:

```bash
export RESTIC_REPOSITORY=/srv/storage/backups/restic/M920
export RESTIC_PASSWORD_FILE=/path/to/restic-repo-password-file
restic snapshots
```

Remote REST repo example:

```bash
export RESTIC_REPOSITORY='rest:http://USERNAME:PLAIN_HTTP_AUTH_PASSWORD@100.87.48.104:8000/M710'
export RESTIC_PASSWORD_FILE=/path/to/restic-repo-password-file
restic snapshots
```

Restore latest snapshot to a test directory:

```bash
mkdir -p /tmp/restic-restore-test
restic restore latest --target /tmp/restic-restore-test
```

Inspect:

```bash
tree -L 3 /tmp/restic-restore-test
```

---

## 14. Things not to do

Do not back up these paths as sources:

```text
/mnt/backups
/mnt/srv/storage/backups
/mnt/srv/storage/backups/restic
```

Do not expose Backrest publicly.

Do not commit repo passwords, `.htpasswd` source passwords, Cloudflare tokens, ntfy tokens, or app secrets.

Do not run legacy restic prune/check timers against the same repo that Backrest is managing.

Do not assume remote hosts can use Docker names from M920, such as `rest-server`, unless name resolution has been explicitly configured across hosts.

---

## 15. Open TODOs

- Confirm exact rest-server compose/service location.
- Confirm exact rest-server port and exposure model.
- Confirm whether rest-server is append-only.
- Confirm current `.htpasswd` usernames and intended repo ownership.
- Add Backrest pre-backup hook/script for Nextcloud MariaDB dumps.
- Add Backrest pre-backup hook/script for Gitea PostgreSQL dumps.
- Add Backrest pre-backup hook/script for authentik PostgreSQL dumps if authentik is deployed.
- Perform and document a restore test for each repo.
- Add ntfy notification for backup success/failure.

---

## 16. Quick reference

```text
Backrest UI:              https://backup.alex-ashworth.com
M920 Backrest path:       /srv/backrest
M920 repo root host:      /srv/storage/backups/restic
M920 repo root container: /mnt/backups
Remote repo transport:    rest-server
Rest-server repo root:    /srv/storage/backups/restic
M920 repo:                /mnt/backups/M920
M710 repo:                rest:http://...@100.87.48.104:8000/M710
omarchy repo:             rest:http://...@100.87.48.104:8000/omarchy
omarchy-x repo:           rest:http://...@100.87.48.104:8000/omarchy-x
Retention:                last 7, daily 14, weekly 8, monthly 12
Maintenance order:        backup -> forget/prune -> check
Legacy timers:            disabled
```
