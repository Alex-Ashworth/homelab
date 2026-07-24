# Authentik

Authentik provides identity services through a PostgreSQL 16 database, Redis 7, server, and worker.

**Runtime state:** All four containers were running on 2026-07-23; server and worker were healthy.

## Components and networks

All components use the private `authentik-internal` network. The server also joins the shared `proxy` network for Nginx access. The worker has Docker socket access and mounts media, certificates, and custom templates; the server mounts media and templates.

## Access and persistence

The `auth` vhost is restricted to Tailscale and the proxy subnet. PostgreSQL, Redis, media, certificates, and custom-template paths are mounted for persistent state or configuration; secret values are not documented here.
