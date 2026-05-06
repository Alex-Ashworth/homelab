#!/bin/bash
set -euo pipefail

docker run --rm \
  -v /srv/nginx/certbot/conf:/etc/letsencrypt \
  -v /srv/nginx/secrets/cloudflare.ini:/cloudflare.ini:ro \
  certbot/dns-cloudflare renew

docker exec nginx nginx -s reload
