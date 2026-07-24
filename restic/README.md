# Restic REST server

The Restic REST server provides access to local Restic repository storage.

**Runtime state:** Running on 2026-07-23.

## Connectivity and access

The server joins the shared `backup` network and binds directly to the M920 Tailscale address on port 8000. It has no declared public or loopback binding.

## Storage and authentication

The service mounts the local Restic repository area and external authentication material. Authentication content and protected storage contents are not documented here. This server is distinct from the host backup, check, and prune scripts documented in [../scripts/README.md](../scripts/README.md).
