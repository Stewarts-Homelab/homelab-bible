# Homelab Bible

A practical manual for building, operating, and troubleshooting an Ubuntu-based homelab and media server. Start with the deployment gates. Use the operations guides to diagnose the host and services before making changes.

| Start here | Purpose |
| --- | --- |
| [Deployment roadmap](docs/deployment/README.md) | Follow installation, storage, Docker, services, recovery and handoff in dependency order. |
| [Ubuntu Server foundation](docs/deployment/01-ubuntu-server-foundation.md) | Prepare an expendable OS disk, install Ubuntu Server 24.04 LTS amd64, and verify first boot. The isolated install rehearsal is pending. |
| [Operations by symptom](docs/operations/README.md) | Find the right guide for storage, Docker, DNS, reachability or logs. |
| [Troubleshooting cases](docs/troubleshooting/README.md) | Interpret verified observations and identify the evidence still missing. |
| [Architecture](diagrams/architecture.md) | See the proposed host, storage, listener and VPN boundaries. |
| [Docker templates](docker/README.md) | Review reconstructed Jellyfin and Gluetun/qBittorrent examples. |
| [Validation matrix](docs/operations/validation-matrix.md) | Check which diagnostics ran in fixtures and which still need a lab. |

## Prerequisites

Use an authorized dedicated host or isolated lab, verified installation media, a known OS disk, console access and known-good backups. Confirm persistent mounts before starting services. The Docker examples require a supported Docker Engine and Compose v2, local state directories, and explicitly selected image versions. Read the roadmap before applying the examples.

**Status:** This is a review-stage repository package. The architecture and Compose templates describe example deployments. The historical baseline and case studies label their own dates and confidence. The Ubuntu installation, Docker runtime and backup restore still need validation. Direct links to internal research attachments are intentionally omitted from this package. Their descriptions remain in the guides; the original project checkpoint preserves the references.
