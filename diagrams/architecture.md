# Conceptual deployment architecture

This is a proposed example. It does not describe a verified current topology.

```mermaid
flowchart TD
    C["Authorized client"] --> H["Ubuntu host"]
    H --> J["Jellyfin container"]
    H --> V["Gluetun network namespace"]
    V --> Q["qBittorrent shares namespace"]
    V --> N["Approved VPN peer"]
    S["Verified media mount"] --> J
    S --> Q
    A["Separate persistent appdata"] --> J
    A --> V
    A --> Q
```

The Jellyfin template reads media. The download service uses its own approved writable path under the common media root. Both WebUI mappings are loopback-scoped in the draft. A future proxy adds a separate client-to-origin path. Provider forwarding requires its own configuration and validation. See the [Docker examples](../docker/README.md).
