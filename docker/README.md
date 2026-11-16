# Docker templates

Both templates are reconstructed drafts with runtime validation pending. The historical records show Jellyfin media paths and a shared Gluetun/qBittorrent namespace at a specific point in time. These examples use a single configurable media source and bind web interfaces to loopback. They deliberately leave GPU acceleration, reverse proxy, automated forwarding and Arr integration for separate tested procedures.

1. Review the [deployment gates](../docs/deployment/README.md). Verify the media mount with the [read-only helper](../scripts/check-storage-mount.sh) and check access and ownership on the proposed appdata paths.
2. Copy the root [example environment](../.env.example) to an ignored local file and restrict access to its contents. Select pinned, compatible images and fill only the variables for the chosen template. Do not commit a populated environment file or share rendered config. Docker administrators may be able to read environment values.
3. From the repository root, validate one file at a time. Compose v2 is required.

```bash
docker compose --project-name homelab-jellyfin-lab --env-file ./.env -f docker/jellyfin.compose.yaml config --quiet
docker compose --project-name homelab-vpn-lab --env-file ./.env -f docker/gluetun-qbittorrent.compose.yaml config --quiet
```

A quiet exit 0 validates the model, while missing variables or invalid syntax must be addressed before lab startup. Model validation cannot prove actual mount identity, app readiness or security. The templates do not create missing host directories. A directory can still exist on the wrong filesystem, so check exact mount identity separately.

**Jellyfin:** The template exposes media read-only at `/media` and keeps config and cache writable at separate paths. Select the matching library tree during a future isolated test. Check actual playback on a licensed or synthetic sample before promotion. Host loopback publication is local to that host under ordinary routing. Review daemon version and firewall policy before any use on a shared network.

**Gluetun and qBittorrent:** Use an empty dedicated Gluetun configuration path to avoid inheriting old persisted VPN settings. This example expects manual custom WireGuard settings supplied by the user's authorized provider and a compatible LinuxServer qBittorrent image. Provider forwarding is disabled. Review current image settings, architecture, and required permissions before running. qBittorrent shares Gluetun's network namespace and does not declare its own ports. A lab test must check tunnel health, intended egress and tunnel-loss behavior before any real download activity. No environment override can make a historical forwarding lease current.

**Recovery:** Preserve the previous Compose, application data and a verified backup before a separately authorized change. In a disposable test, stop only the named test project and clean up its dedicated test resources after capturing logs. Keep bind paths and data, and do not prune volumes. For a real rollback use the prior approved config and restore plan. Neither example specifies a verified production recovery procedure.
