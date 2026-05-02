```bash
mkdir -p /srv/restic/{auth,data,excludes} /srv/storage/backups/restic/$HOSTNAME
chown -R $USER:$USER /srv/storage/backups/restic/$HOSTNAME
chmod 700 /srv/restic
openssl rand -base64 48 > srv/restic/auth/passwd-$HOSTNAME
htpasswd -B -c /srv/restic/auth/htpasswd $HOSTNAME
vi /srv/restic/compose.yml
vi /srv/restic/$HOSTNAME.env
cd /srv/restic
docker compose up -d
curl -I -u $HOSTNAME http://IP.ADDRESS:8000/
```
