# Homelab Build Sequence and Validation Roadmap

**Deployment & Operations Playbook · Batch 19 · Draft · November 15, 2026**

Start with one verified host. Each gate is a stop point. Complete only the components required by the intended deployment. A client may choose a different storage architecture, skip a VPN, or keep services on the LAN.

| Stage | Prerequisites and dependencies | Expected result | Validation gate before proceeding |
| --- | --- | --- | --- |
| 1. Hardware and media | Workload and hardware inventory, console, backups, known expendable USB or virtual media | Compatible system, selected dedicated OS disk and verified installer media | Confirm architecture, boot support, exact disk identity, backups, and installation scope. |
| 2. Fresh Ubuntu and first boot | Stage 1, network plan and local console | Supported Ubuntu Server LTS boots from intended disk and admin can log in | Compare release, boot mode, root disk and account to the preflight inventory. See the companion foundation guide. |
| 3. Network identity and remote administration | Stage 2 and known DHCP/static plan | Stable host identity, working DNS and time, authorized management access where needed | From an approved client, verify intended management path and access. Retain console recovery. |
| 4. Storage identity and persistence | Stage 2 and known disk/share inventory. Stage 3 for network storage | Intended filesystems or shares mounted at documented targets | Verify exact live mount, source identity, permissions and persistence in authorized lab checks. [Storage diagnostics](../operations/storage-diagnostics.md) |
| 5. Docker Engine and Compose | Stages 2–4 and selected supported install method | Versioned Engine and Compose with appropriate daemon access | Record versions and authorized service status. Check mount dependency and security assumptions. |
| 6. Docker directories and configuration | Stages 4–5 and backup/secret-handling plan | Predictable appdata, bind paths, named volumes and tracked sanitized configuration | Validate folder ownership, persistence, secret exclusions and rendered Compose model. |
| 7. First simple container | Stages 5–6 and isolated project | One disposable service starts and responds only on the intended path | Check status, logs, mount/port scope, then verify project cleanup or rollback. |
| 8. Media storage and app services | Stages 4, 6 and 7, plus library and client requirements | Confirmed media mounts and locally usable services | Verify read/write intent, import, test playback and hardlink behavior where relevant. |
| 9. VPN networking and downloads | Stages 6–7 and Stage 8 if integrated, approved service scope | Selected services use the intended namespace and tunnel | Check namespace, intended egress, failure behavior and inbound forwarding only when required. |
| 10. Reverse proxy and remote access | Stage 3 and a verified target service | Intended service works through approved access path | Validate DNS, certificate, origin routing and authorized external client access. |
| 11. Monitoring, backup, restore and maintenance | Baseline services and retention/recovery requirements | Health observations and recoverable copies support maintenance | Restore on an isolated target, verify contents and function, document upgrades and rollback. |
| 12. Final validation and handoff | All applicable earlier gates | Reproducible deployment record and client-specific settings | Walk through intended use, backup/restore ownership, known limits and maintenance handoff. |

## Repository placement proposal

| Material | Proposed path in the project repository |
| --- | --- |
| Roadmap | `docs/deployment/README.md` |
| Ubuntu foundation | `docs/deployment/01-ubuntu-server-foundation.md` |
| Future sanitized examples | `templates/` |
| Future reviewed helpers | `scripts/` |
| Future verification captures | `validation/` |

Use relative Markdown links in that repository after the files are placed there. Candidate future helpers are a read-only host inventory collector and a verification report formatter. Candidate templates are an installer decision sheet, sanitized network worksheet and versioned Compose example. Review and test any script separately before release. No installation automation or repository writes were performed.

**Batch 19 scope:** Stages 1–2 documentation only. The foundation includes a first-boot network baseline, while remote access and persistent storage configuration remain later procedures. [Deployment & Operations Playbook](../operations/README.md) · Project checkpoint (private research record)
