# Gitea

Gitea provides Git hosting with a PostgreSQL 16 database.

**Runtime state:** Gitea and PostgreSQL were running on 2026-07-23.

## Components and networks

Both containers use the private `gitea-internal` network; Gitea also joins the shared `proxy` network for Nginx access.

## Access and persistence

The web service binds to loopback port 3000 and is exposed by the currently public Gitea HTTPS vhost. SSH binds to the M920 Tailscale address on port 52599. Declared data and database mounts target protected Gitea service-storage paths; their contents are intentionally not documented here.
