#!/bin/bash
set -euo pipefail

main() {
  local cert="${1:-}"
  local domain="${2:-}"
  local email="${3:-}"


  [[ -z "$cert" ]] && read -rp "Enter certificate name: " cert
  [[ -z "$domain" ]] && read -rp "Enter domain name: " domain
  [[ -z "$email" ]] && read -rp "Enter email address: " email

  docker run --rm \
    -v /srv/nginx/certbot/conf:/etc/letsencrypt \
    -v /srv/nginx/secrets/cloudflare.ini:/cloudflare.ini:ro \
    certbot/dns-cloudflare certonly \
    --force-renewal \
    --cert-name "$cert" \
    --dns-cloudflare \
    --dns-cloudflare-credentials /cloudflare.ini \
    --dns-cloudflare-propagation-seconds 60 \
    -d "$domain" \
    --email "$email" \
    --agree-tos \
    --no-eff-email
}

main "$@"
