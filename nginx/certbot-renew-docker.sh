#!/bin/bash
set -euo pipefail

NGINX_DIR="/srv/nginx"

cd "$NGINX_DIR"
docker compose run --rm certbot renew
docker exec nginx nginx -s reload
