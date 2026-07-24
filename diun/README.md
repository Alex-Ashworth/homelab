# DIUN

DIUN monitors container images and notifies about available updates; it does not deploy updates.

**Runtime state:** Running on 2026-07-23.

## Monitoring flow

DIUN joins the shared `telemetry` network and has no declared host port. It uses read-only Docker socket discovery, includes stopped containers, checks every 12 hours, runs at startup, and uses a 30-second scheduling jitter.

## Persistence

Configuration and data directories are mounted for persistent settings and DIUN state. Their contents are not documented here.
