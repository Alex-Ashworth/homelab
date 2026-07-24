# Homepage

Homepage provides the homelab service dashboard.

**Runtime state:** Running on 2026-07-23.

## Connectivity

Homepage joins the shared `proxy` network. It binds its web interface to loopback port 3003, while the `hub` vhost provides access restricted to Tailscale and the proxy subnet.

## Configuration

Checked-in configuration is mounted from `config`. Docker socket discovery is intentionally disabled in the Compose definition; no persistent application-data mount is declared.
