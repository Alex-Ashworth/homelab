# Pi-hole

Pi-hole provides LAN DNS with Unbound as its upstream resolver.

**Runtime state:** Pi-hole and Unbound were running on 2026-07-23.

## Components and networks

Pi-hole and Unbound use the private `dns` network; Pi-hole also joins the shared `proxy` network for Nginx access.

## Access and persistence

DNS is bound only to the LAN on port 53 for TCP and UDP. The UI binds to loopback port 8081 and the `pihole` vhost is restricted to Tailscale and the proxy subnet. Pi-hole, dnsmasq, and Unbound configuration paths are mounted for persistent state or configuration; secret values are not documented here.
