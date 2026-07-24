# Nginx

Nginx stable-alpine is the TLS reverse proxy and static portfolio server.

**Runtime state:** Running on 2026-07-23.

## Connectivity and exposure

Nginx joins the shared `proxy` network and publishes HTTP and HTTPS on ports 80 and 443. It serves the public portfolio and currently exposes Gitea HTTPS publicly. All other application vhosts are restricted to Tailscale plus the proxy subnet.

## Configuration and certificates

Nginx mounts checked-in virtual-host configuration, snippets, portfolio content, certificate paths, and logs. The manual-profile Certbot service obtains Let's Encrypt certificates through the Cloudflare DNS-01 plugin; Cloudflare credential material is not documented here.
