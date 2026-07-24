#!/bin/bash
set -euo pipefail

NGINX_DIR="/srv/nginx"

main() {
  local cert="${1:-}"
  local domain="${2:-}"
  local email="${3:-}"

  [[ -z "$cert" ]] && read -rp "Enter certificate name: " cert
  [[ -z "$domain" ]] && read -rp "Enter domain name: " domain
  [[ -z "$email" ]] && read -rp "Enter email address: " email

  cd "$NGINX_DIR"

  docker compose run --rm certbot certonly \
    --cert-name "$cert" \
    --dns-cloudflare \
    --dns-cloudflare-credentials /cloudflare.ini \
    --dns-cloudflare-propagation-seconds 60 \
    -d "$domain" \
    --email "$email" \
    --agree-tos \
    --no-eff-email

  docker exec nginx nginx -s reload
}

main "$@"
