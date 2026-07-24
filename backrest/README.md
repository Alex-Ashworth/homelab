# Backrest

Backrest provides backup management UI and restore staging for local Restic storage.

**Runtime state:** Running on 2026-07-23.

## Connectivity and access

Backrest joins the shared `proxy` and `backup` networks. It binds directly to the M920 Tailscale address on port 9898, and the `backup` vhost is restricted to Tailscale and the proxy subnet.

## Storage and mounts

Configuration, data, cache, and restore directories are persisted. Backrest accesses local Restic storage and mounts `/srv`, `/etc`, and `/home` read-only for backup management. Protected storage contents and configuration data are not documented here.
