# Pi-hole + Unbound

## Overview

This directory documents the Pi-hole and Unbound DNS stack running on the M920 homelab host.

Pi-hole provides LAN DNS filtering and ad blocking. Unbound runs as the recursive DNS resolver behind Pi-hole. Pi-hole receives DNS queries from LAN clients, filters blocked domains, and forwards allowed queries to Unbound. Unbound then performs recursive DNS resolution instead of forwarding directly to a public DNS provider.

The Pi-hole admin interface is exposed through nginx using a clean HTTPS subdomain, but access is restricted to Tailscale clients only.

## Service Role

| Service | Purpose |
|---|---|
| Pi-hole | DNS sinkhole, ad blocking, query logging, local DNS management |
| Unbound | Recursive DNS resolver used as Pi-hole's upstream resolver |
| nginx | HTTPS reverse proxy for the Pi-hole admin web interface |
| Tailscale | Private access layer for the admin interface |

## Directory Layout

```text
/srv/pihole/
  compose.yml
  .env
  .gitignore
  etc-pihole/
  etc-dnsmasq.d/
  unbound/

/srv/pihole/unbound/
  unbound configuration and persistent data

/srv/nginx/conf.d/
  pihole.alex-ashworth.com.conf
