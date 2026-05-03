# Restic Homelab Backup Setup

This setup uses Restic for encrypted backups across homelab hosts, with automated backup, prune, and check jobs managed by systemd timers.

## Layout

```text
/srv/scripts/
├── restic-backup.sh
├── restic-prune.sh
└── restic-check.sh

/srv/restic/
├── restic.env
├── restic-password.txt
├── .htpasswd
└── excludes/
    ├── M920.txt
    ├── M710.txt
    ├── omarchy.txt
    └── omarchy-x.txt

/etc/systemd/system/
├── restic-backup@.service
├── restic-backup@.timer
├── restic-prune.service
├── restic-prune.timer
├── restic-check.service
└── restic-check.timer
```

## How It Works

### Backups

Backups are hostname-based.

Each host runs:

```bash
restic-backup@$HOSTNAME.timer
```

The backup script checks the current hostname and runs a backup for known hosts only.

Backups include:

```text
/srv
/home/alex
/etc
```

Each host uses its own exclude file:

```bash
/srv/restic/excludes/$HOSTNAME.txt
```

Each backup is tagged with:

```text
$HOSTNAME
homelab
```

### Prune

Prune runs only on the repo/rest-server host.

It is not hostname-based. It targets hardcoded local repo names under:

```bash
/srv/storage/backups/restic/
```

Example repos:

```text
/srv/storage/backups/restic/M920
/srv/storage/backups/restic/M710
/srv/storage/backups/restic/omarchy
/srv/storage/backups/restic/omarchy-x
```

Retention policy:

```bash
--keep-last 7
--keep-daily 14
--keep-weekly 8
--keep-monthly 12
--prune
```

### Check

Check also runs only on the repo/rest-server host.

It targets the same hardcoded repos as prune and runs:

```bash
restic check --read-data-subset=5%
```

This verifies repository structure and reads a random 5% data subset.

## Locking

Each job uses lock files under:

```bash
/run/restic/
```

Backup uses a hostname lock:

```bash
/run/restic/$HOSTNAME.lock
```

Prune/check use repo-specific locks:

```bash
/run/restic/M920.lock
/run/restic/M710.lock
/run/restic/omarchy.lock
/run/restic/omarchy-x.lock
```

Exit code convention:

```text
1 = generic failure
2 = repo/job already locked
3 = unknown hostname or invalid host
4 = missing config/path
```

## Restic Environment

For local prune/check jobs, the shared env file only needs the repo password:

```bash
# /srv/restic/restic.env
RESTIC_PASSWORD_FILE=/srv/restic/restic-password.txt
RESTIC_CACHE_DIR=/var/cache/restic
```

`RESTIC_PASSWORD_FILE` is the encryption password for the Restic repository.

It is separate from rest-server HTTP authentication.

## Rest-Server

The Docker rest-server exposes container port `8000`.

Recommended local-only port binding:

```yaml
ports:
  - "127.0.0.1:8000:8000"
```

Recommended `.htpasswd` mount:

```yaml
volumes:
  - /srv/storage/backups/restic:/data
  - /srv/restic/.htpasswd:/data/.htpasswd:ro
```

The host filename can be `.htpasswd` or `htpasswd`, but the container path should match what rest-server expects:

```text
/data/.htpasswd
```

## Permissions

Recommended ownership:

```bash
sudo chown root:root /srv/scripts/restic-{backup,prune,check}.sh
sudo chown root:root /srv/restic/restic.env
sudo chown root:root /srv/restic/restic-password.txt
sudo chown root:root /srv/restic/.htpasswd
```

Recommended permissions:

```bash
sudo chmod 755 /srv/scripts/restic-{backup,prune,check}.sh
sudo chmod 600 /srv/restic/restic.env
sudo chmod 600 /srv/restic/restic-password.txt
sudo chmod 644 /srv/restic/.htpasswd
```

Systemd unit permissions:

```bash
sudo chmod 644 /etc/systemd/system/restic-backup@.{service,timer}
sudo chmod 644 /etc/systemd/system/restic-prune.{service,timer}
sudo chmod 644 /etc/systemd/system/restic-check.{service,timer}
```

## Testing

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Run syntax checks:

```bash
bash -n /srv/scripts/restic-backup.sh
bash -n /srv/scripts/restic-prune.sh
bash -n /srv/scripts/restic-check.sh
```

Manually test services:

```bash
sudo systemctl start "restic-backup@$HOSTNAME.service"
sudo systemctl start restic-prune.service
sudo systemctl start restic-check.service
```

Check status:

```bash
systemctl status "restic-backup@$HOSTNAME.service" --no-pager
systemctl status restic-prune.service --no-pager
systemctl status restic-check.service --no-pager
```

View logs:

```bash
journalctl -u "restic-backup@$HOSTNAME.service" -n 100 --no-pager
journalctl -u restic-prune.service -n 100 --no-pager
journalctl -u restic-check.service -n 100 --no-pager
```

## Enabling Timers

On every backed-up host:

```bash
sudo systemctl enable --now "restic-backup@$HOSTNAME.timer"
```

On the repo/rest-server host only:

```bash
sudo systemctl enable --now restic-prune.timer
sudo systemctl enable --now restic-check.timer
```

Verify timers:

```bash
systemctl list-timers 'restic*'
```

## Important Notes

- Enable timers, not the oneshot services.
- Backup runs on each host.
- Prune and check run only on the repo/rest-server host.
- Do not back up the Restic repository into itself.
- Keep `restic-password.txt` private.
- `.htpasswd` is for rest-server login, not repo encryption.
