# Backrest, restic, and rest-server README

**Primary host:** `M920`  
**Service root:** `/srv`  
**Backrest service path on each host:** `/srv/backrest`  
**Backup storage root on M920:** `/srv/storage/backups/restic`  
**Backup storage path inside M920 Backrest:** `/mnt/backups`  
**M920 Backrest UI:** `https://backup.alex-ashworth.com`  
**M920 direct Backrest sync URL:** `http://100.87.48.104:9898`  
**Access model:** private/Tailscale-only  
**Current backup model:** Backrest multihost, Option B / shared repos from M920  
**Last updated:** 2026-06-08

This README documents the current backup layout for the homelab after moving from hand-written restic backup/prune systemd timers to Backrest-managed restic plans.

No real passwords, repo passwords, `.htpasswd` secrets, tokens, or private URLs with credentials should be committed into this README.

---

## 1. Mental model

```text
restic      = the actual backup engine
Backrest    = web UI, scheduler, plan manager, snapshot browser, restore helper
restic repo = where the encrypted backup data actually lives
rest-server = HTTP REST endpoint that remote machines use to write/read repos on M920
```

Backrest does **not** replace restic. Backrest runs and manages restic.

The important recovery rule is:

```text
If Backrest dies, the backups are still usable with plain restic
as long as the repo and the repo password still exist.
```

Critical recovery items:

```text
1. The restic repository data
2. The repository password
3. Backrest config, useful but not strictly required for CLI restore
```

---

## 2. Current architecture

The current setup uses **Backrest multihost sync with shared repos**.

```text
M920 Backrest:
  - central Backrest server/dashboard
  - owns repo configuration for all host repos
  - shares repo configs to clients
  - runs repo-level maintenance: forget/prune/check
  - backs up M920-local paths

M710 Backrest:
  - containerized Backrest instance on M710
  - runs M710-local backup plans
  - uses the M710 repo shared from M920

omarchy Backrest:
  - containerized Backrest instance on omarchy
  - runs omarchy-local backup plans
  - uses the omarchy repo shared from M920

omarchy-x Backrest:
  - containerized Backrest instance on omarchy-x
  - runs omarchy-x-local backup plans
  - uses the omarchy-x repo shared from M920

rest-server on M920:
  - exposes repos under /srv/storage/backups/restic over HTTP REST
  - used by remote Backrest/restic clients to write to their host repos
```

Important distinction:

```text
Backups run where the data lives.
Repo maintenance runs where the repo is owned.
```

For this setup:

```text
Client hosts run backup plans.
M920 runs forget/prune/check for shared repos.
```

---

## 3. Current confirmed storage layout

### Backup disk

The backup storage is mounted from the 3.7T `homelab` disk:

```text
/dev/sdc1 -> /srv/storage/backups
```

The Backrest/restic repository root is currently:

```text
/srv/storage/backups/restic
```

Inside the M920 Backrest container, this is mounted as:

```text
/mnt/backups
```

Existing repo-style directories observed under `/mnt/backups`:

```text
/mnt/backups/M920
/mnt/backups/M710
/mnt/backups/omarchy
/mnt/backups/omarchy-x
```

There is also an `.htpasswd` file at the repo root:

```text
/srv/storage/backups/restic/.htpasswd
```

Inside the M920 Backrest container:

```text
/mnt/backups/.htpasswd
```

That file is for rest-server HTTP basic authentication. It stores password hashes, not the plain passwords.

### Nextcloud data disk

The real Nextcloud data is on a separate disk:

```text
/dev/sdb1 -> /srv/storage/services/nextcloud
```

Inside M920 Backrest, that path is visible as:

```text
/mnt/srv/storage/services/nextcloud
```

The observed real data directory is:

```text
/mnt/srv/storage/services/nextcloud/data
```

This confirms Backrest can see the real mounted Nextcloud data disk, not only the normal `/srv/nextcloud` app/config directory.

---

## 4. Backrest compose model

### 4.1 M920 Backrest compose

M920 is special because it physically owns the backup disk and repo root.

The M920 Backrest container should have:

```yaml
services:
  backrest:
    image: garethgeorge/backrest:latest
    container_name: backrest
    restart: unless-stopped
    volumes:
      - /srv/backrest/data:/data
      - /srv/backrest/config:/config
      - /srv/backrest/cache:/cache

      # Backup source paths
      - /srv:/mnt/srv:ro
      - /home:/mnt/home:ro
      - /etc:/mnt/etc:ro

      # Writable repository storage
      - /srv/storage/backups/restic:/mnt/backups

      # Optional safe restore target
      # - /srv/backrest/restore:/restore

    environment:
      BACKREST_DATA: /data
      BACKREST_CONFIG: /config/config.json
      XDG_CACHE_HOME: /cache
      TZ: America/Chicago
    ports:
      - "100.87.48.104:9898:9898"
    networks:
      - proxy
      - backup

networks:
  proxy:
    external: true
  backup:
    external: true
```

Mount rule:

```text
Backup source paths       = read-only
Backup repo destination   = read/write
Backrest data/config/cache = read/write
Restore target            = read/write
```

### 4.2 Client Backrest compose pattern

Remote Backrest instances should **not** mount M920's `/srv/storage/backups/restic` unless that storage is intentionally mounted on the remote host.

Client hosts use rest-server URLs for repo access.

Use this shape on `M710`, `omarchy`, and `omarchy-x`:

```yaml
services:
  backrest:
    image: garethgeorge/backrest:latest
    container_name: backrest
    restart: unless-stopped
    volumes:
      - /srv/backrest/data:/data
      - /srv/backrest/config:/config
      - /srv/backrest/cache:/cache

      # Backup source paths from this local machine
      - /srv:/mnt/srv:ro
      - /home:/mnt/home:ro
      - /etc:/mnt/etc:ro

      # Optional safe restore target
      - /srv/backrest/restore:/restore

    environment:
      BACKREST_DATA: /data
      BACKREST_CONFIG: /config/config.json
      XDG_CACHE_HOME: /cache
      TZ: America/Chicago
    ports:
      - "127.0.0.1:9898:9898"
```

Access client UIs through an SSH tunnel when needed:

```bash
ssh -L 9899:127.0.0.1:9898 alex@M710
```

Then open:

```text
http://127.0.0.1:9899
```

---

## 5. Multihost sync model

This setup uses **Option B: shared repos from M920**.

### Server

```text
M920-backrest
```

M920 owns the repo configs, marks remote repos as shared, receives operation history, and manages repo-level maintenance.

### Clients

```text
M710-backrest
omarchy-backrest
omarchy-x-backrest
```

Each client has its own Backrest instance and local backup plans.

### Pairing URL

Use M920's direct Tailscale URL for multihost sync:

```text
http://100.87.48.104:9898
```

Use the domain for browser UI access:

```text
https://backup.alex-ashworth.com
```

Do not use the nginx/domain path for initial multihost pairing unless specifically testing proxy compatibility.

### Shared repo behavior

Repos marked **Shared** on M920 are pushed to clients that have `Receive Shared Repos` permission.

This may cause remote instances to display multiple shared repos, for example:

```text
M710-backrest may show repo M710 and other shared repos.
omarchy-backrest may show repo omarchy and other shared repos.
```

That is not automatically a failure. The operational rule is:

```text
Each host's backup plans must use only that host's matching repo.
```

Examples:

```text
M710-core      -> repo M710
M710-srv       -> repo M710
omarchy-core   -> repo omarchy
omarchy-srv    -> repo omarchy
omarchy-x-core -> repo omarchy-x
omarchy-x-srv  -> repo omarchy-x
```

Do not let one host's plans write to another host's repo.

---

## 6. Repository locations and URI model

### M920 local repo

M920 can use the local mounted repo path:

```text
/mnt/backups/M920
```

Host path:

```text
/srv/storage/backups/restic/M920
```

### Remote host repos

Remote host repos are stored on M920's backup disk:

```text
/srv/storage/backups/restic/M710
/srv/storage/backups/restic/omarchy
/srv/storage/backups/restic/omarchy-x
```

When configuring shared repo definitions that clients must use, use a rest-server URL that is reachable from the client containers.

Use this shape:

```text
rest:http://USERNAME:URL_ENCODED_REST_SERVER_PASSWORD@100.87.48.104:REST_SERVER_PORT/REPO_NAME
```

Examples without real secrets:

```text
rest:http://M710:REDACTED@100.87.48.104:8000/M710
rest:http://omarchy:REDACTED@100.87.48.104:8000/omarchy
rest:http://omarchy-x:REDACTED@100.87.48.104:8000/omarchy-x
```

Do **not** use this from remote clients:

```text
rest:http://USER:PASS@rest-server:8000/REPO
```

`rest-server` is a Docker DNS/container name on M920 and usually will not resolve from a remote host's Backrest container.

Important password distinction:

```text
rest-server username/password = HTTP basic auth from .htpasswd
restic repository password    = encryption password for the repo
Backrest UI password          = login to Backrest itself
```

If the rest-server password contains URL-special characters, URL-encode it before embedding it in the URI.

Special characters that commonly break raw URLs include:

```text
@ : / ? # & %
```

---

## 7. Current plan inventory

### 7.1 Remote instances

Each remote instance runs two plans.

| Instance | Repo | Plan | Source paths |
|---|---|---|---|
| `M710-backrest` | `M710` | `M710-core` | `/mnt/home`, `/mnt/etc` |
| `M710-backrest` | `M710` | `M710-srv` | `/mnt/srv` |
| `omarchy-backrest` | `omarchy` | `omarchy-core` | `/mnt/home`, `/mnt/etc` |
| `omarchy-backrest` | `omarchy` | `omarchy-srv` | `/mnt/srv` |
| `omarchy-x-backrest` | `omarchy-x` | `omarchy-x-core` | `/mnt/home`, `/mnt/etc` |
| `omarchy-x-backrest` | `omarchy-x` | `omarchy-x-srv` | `/mnt/srv` |

These plans run on the remote host because those paths are local to that host's Backrest container.

### 7.2 M920 instance

M920 has a custom plan split because `/srv/storage` contains large mounted storage and backup/share paths.

| Plan | Repo | Source paths | Required excludes / notes |
|---|---|---|---|
| `M920-core` | `M920` | `/mnt/home`, `/mnt/etc` | Source paths are read-only mounts |
| `M920-srv` | `M920` | `/mnt/srv` | Exclude `/mnt/srv/storage/**` |
| `M920-srv-storage` | `M920` | `/mnt/srv/storage/services` | Captures large service data, including Nextcloud data disk |
| `samba` | `M920` | `/mnt/srv/storage/share` | Captures Samba/shared storage data |

Required global excludes for M920 plans:

```text
/mnt/backups/**
/mnt/srv/storage/backups/**
/mnt/srv/storage/backups/restic/**
```

Specific exclude for `M920-srv`:

```text
/mnt/srv/storage/**
```

Reason:

```text
M920-srv backs up normal /srv service config/app data.
M920-srv-storage separately backs up /srv/storage/services.
samba separately backs up /srv/storage/share.
The backup repo under /srv/storage/backups must never be backed up.
```

Avoid this flag for the M920 storage plans unless you are deliberately testing it:

```text
--one-file-system
```

Reason: `/srv/storage/services` can contain mounted filesystems such as the real Nextcloud data disk. `--one-file-system` can cause mounted data to be skipped depending on how the source path is selected.

---

## 8. Maintenance model

Maintenance should be **repo-level**, not duplicated per plan.

Ideal order:

```text
1. Backup
2. Forget / prune
3. Check
```

Recommended cadence:

```text
Backup: daily
Forget/prune: daily or weekly
Check: weekly
Full/read-data check: monthly or occasional
```

Current ownership model:

```text
M920 manages forget/prune/check for shared repos.
Clients run backup plans only.
```

Do not schedule prune/check on both M920 and a client for the same repo.

For one-repo-per-host:

```text
Repo M920      -> maintenance from M920
Repo M710      -> maintenance from M920
Repo omarchy   -> maintenance from M920
Repo omarchy-x -> maintenance from M920
```

---

## 9. Database dump requirement

For databases, file-level backup is useful, but database dumps are cleaner for recovery.

Backrest should eventually run pre-backup scripts that create dumps before the snapshot runs.

### Nextcloud MariaDB dump

Create the backup folder:

```bash
mkdir -p /srv/nextcloud/backups
```

Manual dump example:

```bash
cd /srv/nextcloud
set -a
source .env
set +a
docker exec nextcloud-db mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" nextcloud > /srv/nextcloud/backups/nextcloud-$(date +%F_%H%M).sql
```

The relevant M920 plans should include:

```text
/mnt/srv/nextcloud
/mnt/srv/storage/services
```

That captures the app/config/db-side directories and the real service storage path.

### Gitea PostgreSQL dump

Create the backup folder:

```bash
mkdir -p /srv/gitea/backups
```

Manual dump example:

```bash
cd /srv/gitea
set -a
source .env
set +a
docker exec postgres-gitea pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > /srv/gitea/backups/gitea-$(date +%F_%H%M).sql
```

The M920 plan should include:

```text
/mnt/srv/gitea
```

### Authentik PostgreSQL dump

TODO once authentik exists or is finalized.

Expected dump location:

```text
/srv/authentik/backups
```

Expected Backrest source path:

```text
/mnt/srv/authentik
```

---

## 10. Legacy restic systemd timers

The older hand-written restic backup/prune scripts and timers are now considered legacy if they target the same repos as Backrest.

They should remain disabled unless intentionally reused for a separate purpose.

Check for old timers:

```bash
systemctl list-timers --all | grep -Ei 'restic|backup|prune'
systemctl list-units --all | grep -Ei 'restic|backup|prune'
systemctl --user list-timers --all | grep -Ei 'restic|backup|prune'
systemctl --user list-units --all | grep -Ei 'restic|backup|prune'
```

Disable old root timers if needed:

```bash
sudo systemctl disable --now restic-backup.timer
sudo systemctl disable --now restic-prune.timer
```

Disable old user timers if needed:

```bash
systemctl --user disable --now restic-backup.timer
systemctl --user disable --now restic-prune.timer
```

Do not run old prune jobs against a repo that Backrest is also managing unless you deliberately understand the retention behavior.

---

## 11. rest-server role

rest-server is separate from Backrest.

Backrest manages plans and can use local or REST repository paths. rest-server exposes restic repositories over HTTP/HTTPS so other devices can back up to the M920 backup disk.

Conceptual layout:

```text
Remote Backrest/restic client -> REST backend -> rest-server on M920 -> /srv/storage/backups/restic/<repo>
```

The observed repo root contains:

```text
.htpasswd
M920/
M710/
omarchy/
omarchy-x/
```

This suggests rest-server is serving the repo root:

```text
/srv/storage/backups/restic
```

Remote clients should each use their own repo path:

```text
M710      -> /srv/storage/backups/restic/M710
omarchy   -> /srv/storage/backups/restic/omarchy
omarchy-x -> /srv/storage/backups/restic/omarchy-x
```

Exact rest-server compose/service location is still a TODO if not already documented elsewhere.

---

## 12. rest-server authentication

The `.htpasswd` file is used by rest-server for HTTP basic auth.

Current observed file:

```text
/srv/storage/backups/restic/.htpasswd
```

Inside M920 Backrest:

```text
/mnt/backups/.htpasswd
```

Project-history notes:

```text
- There were multiple usernames in .htpasswd.
- One known username was M920.
- The value in .htpasswd is a password hash.
- The client uses the original plain password, not the hash, when authenticating.
```

Do not commit the plain password anywhere.

Client URL pattern:

```text
rest:http://USERNAME:PLAIN_OR_URL_ENCODED_PASSWORD@100.87.48.104:REST_SERVER_PORT/REPO_NAME
```

A safer pattern is to avoid storing secrets in shell history and keep credentials in Backrest or a protected password manager.

---

## 13. Verification commands

### 13.1 Confirm M920 Backrest mounts

Run on M920:

```bash
cd /srv/backrest
docker inspect backrest --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
```

Expected important results:

```text
/srv -> /mnt/srv RW= false
/home -> /mnt/home RW= false
/etc -> /mnt/etc RW= false
/srv/storage/backups/restic -> /mnt/backups RW= true
```

### 13.2 Confirm M920 can write to repo target

Run on M920:

```bash
docker exec -it backrest sh -c 'touch /mnt/backups/backrest-write-test && rm /mnt/backups/backrest-write-test && echo OK'
```

Expected:

```text
OK
```

### 13.3 Confirm source mounts are read-only

Run on M920:

```bash
docker exec -it backrest sh -c 'touch /mnt/home/backrest-ro-test'
docker exec -it backrest sh -c 'touch /mnt/etc/backrest-ro-test'
docker exec -it backrest sh -c 'touch /mnt/srv/backrest-ro-test'
```

Expected:

```text
Read-only file system
```

### 13.4 Confirm backup disk is mounted on host

Run on M920:

```bash
findmnt /srv/storage/backups/restic
df -h /srv/storage/backups/restic
lsblk -f
```

Expected: `/srv/storage/backups` should be on `/dev/sdc1`, not the root filesystem.

### 13.5 Confirm real Nextcloud data disk is visible inside M920 Backrest

Run on M920:

```bash
docker exec -it backrest sh -c 'df -h /mnt/srv/storage/services/nextcloud && ls -lah /mnt/srv/storage/services/nextcloud && ls -lah /mnt/srv/storage/services/nextcloud/data | head'
```

Expected: the filesystem should show `/dev/sdb1` and list the Nextcloud data directory.

### 13.6 Confirm client Backrest source paths

Run on each client host:

```bash
docker exec -it backrest sh -c '
for p in /mnt/home /mnt/etc /mnt/srv /restore; do
  echo "=== $p ==="
  ls -ld "$p" 2>&1
done
'
```

Expected: all paths should list successfully.

Confirm sources are read-only:

```bash
docker exec -it backrest sh -c 'touch /mnt/home/backrest-ro-test'
docker exec -it backrest sh -c 'touch /mnt/etc/backrest-ro-test'
docker exec -it backrest sh -c 'touch /mnt/srv/backrest-ro-test'
```

Expected:

```text
Read-only file system
```

Confirm restore target is writable:

```bash
docker exec -it backrest sh -c 'touch /restore/write-test && rm /restore/write-test && echo OK'
```

Expected:

```text
OK
```

### 13.7 Confirm client can reach M920 Backrest sync URL

Run on each client:

```bash
curl -I http://100.87.48.104:9898
```

Expected: an HTTP response from Backrest.

### 13.8 Confirm client can reach rest-server

Run on each client Backrest container, replacing the port if rest-server does not use `8000`:

```bash
docker exec -it backrest sh -c 'wget -S -O- --timeout=5 http://100.87.48.104:8000/ 2>&1 | head -40'
```

A `401 Unauthorized`, `405 Method Not Allowed`, or similar HTTP response is enough to prove the service is reachable. A timeout or DNS failure is not.

---

## 14. Test backup and restore flow

For every host/repo, run at least one manual backup and one restore test.

### Remote host test

On each remote Backrest instance:

```text
Run hostname-core manually.
Restore one small file to /restore/test-restore.
Verify it appears on the host under /srv/backrest/restore/test-restore.
```

### M920 test

On M920 Backrest:

```text
Run M920-core manually.
Restore one small file to a temporary restore target.
```

A backup is not considered proven until at least one restore test has succeeded.

---

## 15. CLI recovery examples

If Backrest is unavailable, install/use restic directly.

### M920 local repo example

Run on M920:

```bash
export RESTIC_REPOSITORY=/srv/storage/backups/restic/M920
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

### Remote repo over rest-server example

Run from a client or from M920 using the REST backend:

```bash
export RESTIC_REPOSITORY='rest:http://USERNAME:REDACTED@100.87.48.104:8000/M710'
export RESTIC_PASSWORD_FILE=/path/to/restic-repo-password-file
restic snapshots
```

Do not restore directly over live service data unless doing a deliberate recovery.

---

## 16. rest-server verification commands

Find the rest-server container or service on M920:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -Ei 'rest|backup'
```

If the container is named `rest-server`, inspect it:

```bash
docker inspect rest-server --format '{{range .Mounts}}{{println .Source "->" .Destination "RW=" .RW}}{{end}}'
docker logs rest-server --tail 100
```

Find compose/service files if the location is forgotten:

```bash
sudo find /srv /etc/systemd/system ~/.config/systemd/user -maxdepth 5 \
  \( -iname '*rest*server*' -o -iname '*restic*' -o -iname 'compose.yml' \) 2>/dev/null
```

Check whether port 8000 or another REST port is open:

```bash
sudo ss -tulpn | grep -Ei '8000|rest'
```

Replace the port after confirming the actual rest-server compose/service.

---

## 17. Things not to do

Do not back up these paths as sources:

```text
/mnt/backups
/mnt/srv/storage/backups
/mnt/srv/storage/backups/restic
```

Do not expose Backrest publicly.

Do not commit repo passwords, `.htpasswd` source passwords, Cloudflare tokens, ntfy tokens, app secrets, or REST URLs with real credentials.

Do not run legacy restic prune timers against the same repo unless Backrest retention is intentionally disabled or coordinated.

Do not schedule forget/prune/check on both M920 and a client for the same shared repo.

Do not assume `/mnt/srv/nextcloud` includes the real Nextcloud user data. The real data disk is currently:

```text
/mnt/srv/storage/services/nextcloud
```

Do not let one host's plans write to another host's repo.

---

## 18. Open TODOs

- Confirm exact rest-server compose/service location.
- Confirm exact rest-server hostname and port.
- Confirm whether rest-server is append-only.
- Confirm whether rest-server is private LAN-only, Tailscale-only, or reverse-proxied.
- Confirm current `.htpasswd` usernames and intended repo ownership.
- Add Backrest pre-backup hook/script for Nextcloud MariaDB dumps.
- Add Backrest pre-backup hook/script for Gitea PostgreSQL dumps.
- Add Backrest pre-backup hook/script for authentik PostgreSQL dumps once authentik is finalized.
- Perform and document restore tests for `M920`, `M710`, `omarchy`, and `omarchy-x`.
- Add ntfy notification for backup success/failure.

---

## 19. Quick reference

```text
Backrest UI:                  https://backup.alex-ashworth.com
M920 sync URL:                http://100.87.48.104:9898
Backrest path on each host:   /srv/backrest
Backrest config:              /srv/backrest/config
Backrest data:                /srv/backrest/data
Backrest cache:               /srv/backrest/cache
Host repo root on M920:       /srv/storage/backups/restic
M920 Backrest repo root:      /mnt/backups
M920 local repo path:         /mnt/backups/M920
Remote repo REST shape:       rest:http://USER:PASS@100.87.48.104:PORT/REPO
Real Nextcloud data:          /mnt/srv/storage/services/nextcloud
Do not back up:               /mnt/backups or /mnt/srv/storage/backups
Remote core plan pattern:     hostname-core -> /mnt/home, /mnt/etc
Remote srv plan pattern:      hostname-srv -> /mnt/srv
M920 core plan:               M920-core -> /mnt/home, /mnt/etc
M920 srv plan:                M920-srv -> /mnt/srv excluding /mnt/srv/storage/**
M920 storage plan:            M920-srv-storage -> /mnt/srv/storage/services
Samba plan:                   samba -> /mnt/srv/storage/share
Maintenance order:            backup -> forget/prune -> check
Retention:                    last 7, daily 14, weekly 8, monthly 12
Legacy timers:                disabled
```
