# CrowdSec

CrowdSec is configured for planned host and Nginx security analysis.

**Runtime state:** Intentionally not running on 2026-07-23.

## Intended data flow

If enabled, CrowdSec would ingest Nginx access and error logs plus tailscaled journal data. It joins the shared `security` and `telemetry` networks.

## Exposure and persistence

Its API would bind to loopback port 8080. Configuration and data directories are declared as persistent mounts; their contents are not documented here.
