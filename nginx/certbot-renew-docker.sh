#!/bin/bash
set -euo pipefail

cd /srv/nginx
docker compose run --rm certbot renew --webroot -w /var/www/certbot
docker exec nginx nginx -t
docker exec nginx nginx -s reload
