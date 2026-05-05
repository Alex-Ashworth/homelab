# Nextcloud Service README

## Purpose

This README documents the Nextcloud deployment on the M920 homelab host. Nextcloud provides private cloud file storage, mobile photo backup, and WebDAV access for the Obsidian vault.

The service follows the homelab pattern used elsewhere in this repo:

- Persistent service data lives under `/srv` and `/srv/storage`.
- Application workloads run in Docker Compose.
- Nextcloud HTTPS access is tailnet-only over Tailscale, using the shared Dockerized nginx + Certbot stack.
- nginx and Nextcloud communicate over the shared Docker network named `proxy`.
- Secrets are stored in `/srv/nextcloud/.env` and should not be committed to Git.

## Service location

```text
/srv/nextcloud/
  compose.yml
  .env
  db/
  redis/
  html/
```

External user file storage:

```text
/srv/storage/services/nextcloud/data
```

nginx virtual host:

```text
/srv/nginx/conf.d/cloud.alex-ashworth.com.conf
```

## Tailnet-only URL

```text
https://cloud.alex-ashworth.com
```

The hostname is intended to resolve to the M920 Tailscale IP and should only be reachable from devices connected to the tailnet. TLS is still terminated by the shared nginx container using a Let's Encrypt certificate for `cloud.alex-ashworth.com`.

## Container layout

| Container | Image | Purpose |
|---|---|---|
| `nextcloud-app` | `nextcloud:apache` | Nextcloud web application and Apache runtime |
| `nextcloud-db` | `mariadb:11` | MariaDB database for Nextcloud metadata, users, shares, app state, and file index |
| `nextcloud-redis` | `redis:7-alpine` | Redis cache and transactional file locking |
| `nginx` | `nginx:stable-alpine` | Shared reverse proxy; the Nextcloud vhost is restricted to Tailscale while other vhosts may remain public |
| `certbot` | `certbot/certbot` | Shared certificate issuance and renewal container |

Optional:

| Container | Image | Purpose |
|---|---|---|
| `nextcloud-clamav` | `clamav/clamav:stable` | ClamAV daemon for the Nextcloud Antivirus for Files app |

## Docker networks

Nextcloud uses two networks:

| Network | Purpose |
|---|---|
| `nextcloud-internal` | Private app/database/cache network for Nextcloud, MariaDB, Redis, and optional ClamAV |
| `proxy` | Shared external Docker network used by nginx to reach `nextcloud-app`; external here means external to the Compose project, not public internet exposure |

The nginx upstream points to:

```nginx
proxy_pass http://nextcloud-app:80;
```

This works because both `nginx` and `nextcloud-app` are attached to the external Docker network named `proxy`.

## Persistent volumes

Current storage layout:

```yaml
volumes:
  - /srv/nextcloud/db:/var/lib/mysql
  - /srv/nextcloud/redis:/data
  - /srv/nextcloud/html:/var/www/html
  - /srv/storage/services/nextcloud/data:/var/www/html/data
```

| Host path | Container path | Purpose | Storage choice |
|---|---|---|---|
| `/srv/nextcloud/db` | `/var/lib/mysql` | MariaDB database files | Internal/system drive |
| `/srv/nextcloud/redis` | `/data` | Redis persistence | Internal/system drive |
| `/srv/nextcloud/html` | `/var/www/html` | Nextcloud application files, apps, config, and `config.php` | Internal/system drive |
| `/srv/storage/services/nextcloud/data` | `/var/www/html/data` | User-uploaded files and synced content | External/data drive |

The database, Redis data, and application files stay on the internal drive for lower-latency service operations. The bulk user file storage is placed on the external data drive.

## Environment file

Secrets are stored in:

```text
/srv/nextcloud/.env
```

Expected variables:

```env
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud
MYSQL_PASSWORD=<db-user-password>
MYSQL_ROOT_PASSWORD=<db-root-password>
NEXTCLOUD_ADMIN_USER=alex
NEXTCLOUD_ADMIN_PASSWORD=<nextcloud-admin-password>
NEXTCLOUD_TRUSTED_DOMAINS=cloud.alex-ashworth.com
REDIS_HOST=nextcloud-redis
```

Password guidance:

- `MYSQL_PASSWORD` is the database password for the `nextcloud` database user.
- `MYSQL_ROOT_PASSWORD` is the MariaDB root/admin password.
- `NEXTCLOUD_ADMIN_PASSWORD` is the initial Nextcloud admin password.
- These should be separate strong passwords.
- Do not commit `.env` to Git.

## nginx reverse proxy

The nginx vhost for Nextcloud is:

```text
/srv/nginx/conf.d/cloud.alex-ashworth.com.conf
```

Expected HTTPS server block pattern:

```nginx
server {
    listen 443 ssl;
    http2 on;

    server_name cloud.alex-ashworth.com;

    client_max_body_size 50G;

    ssl_certificate /etc/letsencrypt/live/cloud.alex-ashworth.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloud.alex-ashworth.com/privkey.pem;

    include /etc/nginx/snippets/ssl-params.conf;

    location / {
        allow 100.64.0.0/10;
        deny all;

        proxy_pass http://nextcloud-app:80;
        include /etc/nginx/snippets/proxy-common.conf;
    }
}
```

The HTTP server block redirects normal traffic to HTTPS while still allowing ACME HTTP-01 challenges when certificate renewal uses HTTP-01:

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
```

## Nextcloud reverse proxy settings

Nextcloud must trust nginx as the reverse proxy and generate links using the Tailscale-only HTTPS hostname.

Check current values:

```bash
docker exec -u www-data nextcloud-app php occ config:system:get trusted_domains
docker exec -u www-data nextcloud-app php occ config:system:get overwritehost
docker exec -u www-data nextcloud-app php occ config:system:get overwriteprotocol
docker exec -u www-data nextcloud-app php occ config:system:get overwrite.cli.url
```

Set expected values:

```bash
docker exec -u www-data nextcloud-app php occ config:system:set trusted_domains 0 --value="cloud.alex-ashworth.com"
docker exec -u www-data nextcloud-app php occ config:system:set overwritehost --value="cloud.alex-ashworth.com"
docker exec -u www-data nextcloud-app php occ config:system:set overwriteprotocol --value="https"
docker exec -u www-data nextcloud-app php occ config:system:set overwrite.cli.url --value="https://cloud.alex-ashworth.com"
```

Also verify `trusted_proxies` in:

```text
/srv/nextcloud/html/config/config.php
```

It should include the nginx container name and/or the Docker `proxy` network subnet.

Inspect the proxy network subnet:

```bash
docker network inspect proxy | jq '.[0].IPAM.Config'
```

## Upload size limits

Large uploads require both Nextcloud/PHP and nginx to allow the desired file size.

Nextcloud app container settings are controlled in `/srv/nextcloud/compose.yml` under `nextcloud-app`:

```yaml
environment:
  MYSQL_HOST: nextcloud-db
  PHP_UPLOAD_LIMIT: 50G
  PHP_MEMORY_LIMIT: 1024M
  APACHE_BODY_LIMIT: 0
```

nginx must also allow the same or larger size:

```nginx
client_max_body_size 50G;
```

Verify PHP values:

```bash
docker exec -it nextcloud-app php -i | grep -E 'upload_max_filesize|post_max_size|max_execution_time|max_input_time|memory_limit'
```

Verify nginx values:

```bash
grep -R "client_max_body_size" /srv/nginx/snippets /srv/nginx/conf.d
```

## Obsidian WebDAV integration

Nextcloud exposes WebDAV automatically through the Files app. No separate WebDAV service is required.

Base WebDAV URL for the `alex` user:

```text
https://cloud.alex-ashworth.com/remote.php/dav/files/alex/
```

Recommended Remotely Save configuration:

```text
Service type: WebDAV
Server URL: https://cloud.alex-ashworth.com/remote.php/dav/files/alex/
Username: alex
Password: Nextcloud app password
Remote base directory: obsidian/
```

Important notes:

- Use a Nextcloud app password, not the main account password.
- Use the account root WebDAV URL as the server URL.
- Put the vault folder in the plugin's remote/base directory field.
- Do not duplicate the folder path in both the server URL and remote directory field.
- WebDAV folder names are case-sensitive.
- Use trailing slashes for folder paths.

Correct:

```text
Server URL: https://cloud.alex-ashworth.com/remote.php/dav/files/alex/
Remote base directory: obsidian/
```

Avoid:

```text
Server URL: https://cloud.alex-ashworth.com/remote.php/dav/files/alex/obsidian/
Remote base directory: obsidian/
```

That can cause the plugin to attempt syncing to:

```text
/alex/obsidian/obsidian/
```

## Creating a Nextcloud app password

In the Nextcloud web UI:

```text
Profile icon
→ Personal settings
→ Security
→ Devices & sessions
→ Create new app password
```

Recommended app password names:

```text
Obsidian WebDAV - Desktop
Obsidian WebDAV - iPhone
Nextcloud iOS Photos
```

If an app password is exposed or pasted somewhere, revoke it immediately and create a new one.

## WebDAV validation commands

Test the account root:

```bash
curl -i -u 'alex:APP_PASSWORD_HERE' \
  -X PROPFIND \
  -H 'Depth: 1' \
  'https://cloud.alex-ashworth.com/remote.php/dav/files/alex/'
```

Expected success:

```text
HTTP/2 207
```

Test the Obsidian folder:

```bash
curl -i -u 'alex:APP_PASSWORD_HERE' \
  -X PROPFIND \
  -H 'Depth: 1' \
  'https://cloud.alex-ashworth.com/remote.php/dav/files/alex/obsidian/'
```

Create the Obsidian folder if needed:

```bash
curl -i -u 'alex:APP_PASSWORD_HERE' \
  -X MKCOL \
  'https://cloud.alex-ashworth.com/remote.php/dav/files/alex/obsidian/'
```

Test a basic upload:

```bash
printf 'webdav test\n' > /tmp/webdav-test.txt

curl -i -u 'alex:APP_PASSWORD_HERE' \
  -T /tmp/webdav-test.txt \
  -H 'Content-Type: text/plain' \
  'https://cloud.alex-ashworth.com/remote.php/dav/files/alex/obsidian/webdav-test.txt'
```

Expected success:

```text
HTTP/2 201
```

or:

```text
HTTP/2 204
```

## Antivirus note

If the Nextcloud Antivirus for Files app is enabled but ClamAV is unreachable, uploads can fail with:

```text
No connection to anti virus. Upload cannot be completed.
```

To quickly disable the antivirus app:

```bash
docker exec -u www-data nextcloud-app php occ app:disable files_antivirus
```

To keep antivirus scanning enabled, run a ClamAV daemon container on the `nextcloud-internal` network and configure the Antivirus for Files app to use:

```text
Mode: ClamAV Daemon
Host: nextcloud-clamav
Port: 3310
```

The ClamAV signature database directory must be writable by the ClamAV container user:

```bash
sudo mkdir -p /srv/nextcloud/clamav
```

Check the image UID/GID:

```bash
docker run --rm --entrypoint sh clamav/clamav:stable -c 'id clamav'
```

Then chown the directory using the UID/GID reported by the image.

## iPhone photo backup notes

The Nextcloud iOS app can be used for camera roll backup.

Recommended iOS settings for reliable automatic uploads while the device is connected to Tailscale:

```text
Photos access: Full Access
Background App Refresh: On
Location: Always, if Nextcloud requests it for background uploads
Cellular uploads: Off, unless mobile-data backups are desired
Low Power Mode: Off when expecting background uploads
```

Background location is not required for manual uploads, but it can improve the reliability of automatic background photo uploads on iOS.

## Common commands

Start or update the stack:

```bash
cd /srv/nextcloud
docker compose up -d
```

View status:

```bash
cd /srv/nextcloud
docker compose ps
```

View logs:

```bash
docker logs nextcloud-app --tail 100
docker logs nextcloud-db --tail 100
docker logs nextcloud-redis --tail 100
```

Restart Nextcloud app only:

```bash
cd /srv/nextcloud
docker compose restart nextcloud-app
```

Check Nextcloud status:

```bash
docker exec -u www-data nextcloud-app php occ status
```

List users:

```bash
docker exec -u www-data nextcloud-app php occ user:list
```

Check nginx config and reload:

```bash
docker exec nginx nginx -t
docker exec nginx nginx -s reload
```

Verify the certificate:

```bash
openssl s_client \
  -connect cloud.alex-ashworth.com:443 \
  -servername cloud.alex-ashworth.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Expected certificate SAN:

```text
DNS:cloud.alex-ashworth.com
```

## Backup requirements

Backups must include both file storage and the database. File data alone is not enough for a clean restore.

Back up at minimum:

```text
/srv/nextcloud/html
/srv/nextcloud/db
/srv/nextcloud/redis
/srv/storage/services/nextcloud/data
/srv/nextcloud/.env
/srv/nginx/conf.d/cloud.alex-ashworth.com.conf
/srv/nginx/certbot/conf
```

A database dump is preferred in addition to raw database file backups.

Example dump command:

```bash
cd /srv/nextcloud
set -a
source .env
set +a

mkdir -p /srv/nextcloud/backups

docker exec nextcloud-db mariadb-dump \
  -u root \
  -p"$MYSQL_ROOT_PASSWORD" \
  nextcloud > /srv/nextcloud/backups/nextcloud-$(date +%F).sql
```

## Troubleshooting quick reference

### nginx returns 502

Check:

```bash
docker compose ps
docker logs nextcloud-app --tail 100
docker logs nextcloud-db --tail 100
docker exec nginx getent hosts nextcloud-app
docker exec nginx sh -lc 'wget -S -O /dev/null http://nextcloud-app:80 2>&1 | head -40'
```

Common causes:

- Nextcloud app is not running.
- MariaDB is restarting or unavailable.
- nginx and `nextcloud-app` are not both attached to the `proxy` network.

### WebDAV returns 401

This means the endpoint is reachable but authentication is missing or invalid.

Use:

```text
Username: alex
Password: valid Nextcloud app password
```

### WebDAV returns 409 Conflict

Common causes:

- The target folder does not exist.
- Folder path is duplicated in Remotely Save.
- Folder case does not match.
- The plugin is pointed at the vault folder and also configured with the same remote base directory.

### WebDAV returns 415 Unsupported Media Type

Check the XML error body. If it says:

```text
No connection to anti virus. Upload cannot be completed.
```

then the issue is the Antivirus for Files app, not WebDAV itself.

Disable `files_antivirus` or fix the ClamAV daemon connection.

### Certificate common name invalid

Verify the served certificate:

```bash
openssl s_client \
  -connect cloud.alex-ashworth.com:443 \
  -servername cloud.alex-ashworth.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

The SAN must include:

```text
DNS:cloud.alex-ashworth.com
```

If it does, the problem is usually client-side DNS/cache, an old redirect, or the client using a different hostname such as an IP address, Tailscale name, or `cloud.example.com`.

## Security notes

- Keep `/srv/nextcloud/.env` out of Git.
- Use app passwords for WebDAV clients.
- Revoke exposed app passwords immediately.
- Keep the Nextcloud admin password separate from database passwords.
- Keep nginx and Certbot configuration under `/srv/nginx` backed up.
- Do not expose database, Redis, or ClamAV ports publicly.
- Nextcloud should not be public-facing; this vhost should be reachable only over Tailscale. nginx may still be public-facing for other vhosts such as Gitea.
