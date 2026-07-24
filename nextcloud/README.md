# Nextcloud

Nextcloud provides file services through an Apache application with MariaDB 11, Redis 7, and ClamAV.

**Runtime state:** All four containers were running on 2026-07-23; ClamAV was healthy.

## Components and networks

MariaDB, Redis, the app, and ClamAV use the private `nextcloud-internal` network. The Apache app also joins the shared `proxy` network for Nginx access.

## Access and persistence

The `cloud` vhost is restricted to Tailscale and the proxy subnet. Database, Redis, application, and ClamAV paths are mounted for persistent state; the declared user-data mount targets protected Nextcloud service storage, whose contents are intentionally not documented here.
