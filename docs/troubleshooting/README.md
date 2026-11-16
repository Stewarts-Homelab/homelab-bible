# Troubleshooting Knowledge Base — SMART, SATA and Jellyfin Pilots

**Pilot draft · Batch 10 · November 15, 2026**

Historical observations are cited below. Proposed commands are labeled and were introduced as general guidance. Batch 11 exercised selected checks with synthetic fixtures. No historical commands or tests were rerun on the homelab. Replace synthetic paths and device names with authorized local values. Keep raw output private and redact identifiers, endpoints and tokens before sharing.

## Pilot A · H-008 — HGST SMART and SATA link diagnostics

### Quick Reference

| Item | Finding |
| --- | --- |
| Symptoms | Historical SATA link-event terms included `PHYRDYChg`, `CommWake` and `LinkSeq`. The HGST also recorded offline uncorrectable sectors. |
| Affected components | Primary Ubuntu host, 8 TB HGST HUH728080ALE600, ATA disk and link path. The March link events were attributed to `ata1` in indexed material. |
| Immediate safe checks | Identify the physical drive, read SMART and match timestamped kernel messages to the host's boot and disk attachment. |
| Verified outcome | Matching private device identifiers and same counters in the saved March and August captures. No verified SATA fix or disk-to-port attribution. |
| Important warnings | SMART PASS is a device health assessment. Review raw attributes and logs too. Before considering a stress test or replacement, secure and verify important data. |

### Detailed Walkthrough

**Historical evidence.** The saved outputs include `smartctl -a` for the historical whole-disk path. The printed timestamps are used below, with UTC dates shown for cross-reference.

| Observation | Mar 21, 19:55 CDT / Mar 22 UTC | Aug 2, 20:47 CDT / Aug 3 UTC |
| --- | --- | --- |
| Overall assessment | PASSED | PASSED |
| 5 Reallocated Sector Count | 0 | 0 |
| 197 Current Pending Sector | 0 | 0 |
| 198 Offline Uncorrectable | 4 | 4 |
| 199 UDMA CRC Error Count | 0 | 0 |
| Cumulative ATA Error Count | 1,511 | 1,511 |

March capture, lines 178–194, 235 and 246–251 (private research record) · August capture, lines 7–23 and 64–80 (private research record)

**Interpretation.** Attribute 5 records sectors remapped to spares on this model. 197 tracks sectors awaiting re-evaluation after a read problem. 198 records uncorrectable sectors reported by the drive's offline activity. 199 counts interface CRC errors. Interpret raw values by model and attribute. These counters describe different events and should not be added together. The ATA summary error count is cumulative and its displayed error log is limited. PASS can coexist with raw error counts because the drive's overall assessment does not report every error as a health-threshold failure. The two samples show unchanged values at their respective capture times. [smartctl manual](https://github.com/smartmontools/smartmontools/blob/main/src/smartctl.8.in)

**Diagnostic reasoning.** Link signaling and media read errors are separate observations. The March port-to-disk association is unresolved, and the January indexed CRC reading differs from both direct captures. No verified cable or drive replacement is recorded. Link events could occur without a change in the CRC field. Do not attribute the historical link events or a corrupted media file to this drive solely from these counters. Research and case ledger (private research record)

**Proposed read-only diagnostics**

| Check | Command and interpretation |
| --- | --- |
| Identify the disk and controller path | `lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN,HCTL` (normally unprivileged). Match serial locally. HCTL helps trace the device through the kernel's SCSI view. It is not the literal ATA port number. `ls -l /dev/disk/by-path` shows persistent topology symlinks when present. Compare them with enumeration logs for the same boot. |
| Read device data | `sudo smartctl -a /dev/sdb` (smartmontools, authorized device access). Use the confirmed whole disk. Record local time, boot, model, serial, power-on hours, 5/197/198/199 and ATA history. Compare raw fields only for the same drive across captures. A sleeping disk may wake. |
| Correlate kernel events | `sudo journalctl -k -b --no-pager` (systemd, journal permissions). Find controller enumeration, ATA link events, disk assignment and block I/O errors in the same boot. Select the correct retained boot for historical analysis. Missing history cannot establish that no event occurred. |

**Validation, recovery and prevention.** To link the two symptoms, recover same-boot enumeration mapping `ata1` to the specific drive and timestamped link and block I/O events. Then look for a compatible change in error data. Repeated or worsening errors, failed self-tests, or read failures justify evaluating a replacement based on the value of the data and verified backups. Stable historical counts establish a baseline for comparison. Verify a separate backup and a representative restore before relying on recovery. A replacement or full test is outside this read-only pilot.

## Pilot B · H-007 and related H-006 — Jellyfin logs and networking

### Quick Reference

| Item | Finding |
| --- | --- |
| Symptoms | Jellyfin logged `Unable to parse bind override` with a URL as the rejected value. A separate file triggered a probe failure. |
| Affected components | Jellyfin 12.4.0 as logged, its network configuration, and the client/proxy path where applicable. |
| Immediate safe checks | Align app and proxy timestamps. Check the app listener, container-to-container path, and actual client playback as separate stages. |
| Verified outcome | The later saved log records all-interface startup and application activity. The effective configuration change and end-to-end playback outcome remain unverified. |
| Important warnings | Do not publish a full XML file or proxy logs. They can expose internal addresses, domains or credentials. Use scoped inspection rather than changing bindings during diagnosis. |

### Detailed Walkthrough

**Historical evidence and chronology.** November 13 at 00:16:35 CST rejected a URL as a bind override and logged bind addresses in nearby output. The Nov 13 media probe also logged that streams and format were both null for an MKV. User-reported samples later contained zeros and the indexed FFprobe result included an EBML header failure. On November 14, Jellyfin logged all-interface listeners (12:10:35 and 12:10:41 CST), `Bind Addresses ["::"]`, and later activity for the affected title. A listener or refresh shows a particular stage of operation. The saved logs lack paired `network.xml`, matched reverse-proxy routing, file replacement proof and a successful client playback record. Earlier indexed local and cellular access did not include confirmed playback. November 13 log, lines 3, 47 and 143 (private research record) · November 14 log, lines 39–40, 88, 114 and 351 (private research record) · Case register (private research record)

**Attempted fixes and root cause.** The log directly supports rejection of the supplied bind value. The before/after XML and exact edit remain missing. No directly inspected Jellyfin/proxy network relationship is available in these captures. Keep this configuration warning separate from proxy path failures and the media file failure. The file probe alone does not identify a storage or network cause.

**Proposed read-only checks** (Linux Docker host, authorized daemon access and local file access)

| Check | Command and interpretation |
| --- | --- |
| App and proxy logs | `docker logs --since 30m --tail 100 --timestamps jellyfin`. Use the confirmed proxy container name for its own logs. Compare the same time window for application startup, proxy origin errors and playback requests. |
| Networks and ports | `docker inspect --type container --format 'mode={{.HostConfig.NetworkMode}} networks={{json .NetworkSettings.Networks}} ports={{json .NetworkSettings.Ports}}' jellyfin`. Run the same scoped inspection for the authorized proxy. Compare shared networks or the configured routed path. Avoid dumping the full environment. |
| Host listener | `ss -lntu` (normally unprivileged). Look for the expected ports at the proper address. This sees the current namespace. Combine it with Docker port publication evidence and application startup logs. |
| Read network settings | `docker inspect --type container --format '{{range .Mounts}}{{println .Source .Destination}}{{end}}' jellyfin` to locate the config mount. For a locally identified file, `grep -nE 'Bind|PublishedServerUri|KnownProxies|EnableRemoteAccess' /path/to/network.xml` reads selected lines. Use authorized file permissions. Grep is a local inspection aid. It does not parse XML or establish effective settings. A permission error means the file was unreadable, while no matching lines has a different exit status. Inspect only an authorized copy. |
| Isolate a suspected file | `ffprobe -v error -show_streams -show_format '/path/to/sample.mkv'` on an authorized known path (FFmpeg tools, file read access). Compare a known-good file. A header/probe error on one file while others work points toward the file or its access path. Protect media titles in shared logs. Batch 11 returned a valid audio stream for a synthetic WAV and an EBML header error for a synthetic zero-filled MKV. These fixture results demonstrate probe behavior without establishing any historical file's repair or root cause. |

**Validation and prevention.** Verify startup and socket binding, then authorized local reachability, then the intended proxy path. Test a known-good authorized title from the affected client and record session time, Direct Play/transcoding mode and whether playback starts and continues. If only one title fails, correlate file probe and library path. Record the sanitized config diff and tests before closing the incident. H-007's historical network resolution and H-006's replacement/playback remain open. [Docker inspect](https://docs.docker.com/reference/cli/docker/inspect/) · [Docker logs](https://docs.docker.com/reference/cli/docker/container/logs/)

## Reusable troubleshooting case template

Copy the headings into a new case. Use observation dates, application versions, source line references and a scope label for each finding. If a step or outcome is missing, record it explicitly.

### Quick Reference

- Symptoms and exact sanitized error
- Affected components and scope
- Immediate safe checks
- Known verified outcome
- Important warnings

### Detailed Walkthrough

1. Background and system context
2. Original evidence and chronology
3. Diagnostic reasoning
4. Historical commands and observed results
5. Attempted fixes and outcome, where verified
6. Root cause and confidence
7. Validation and recovery evidence
8. Prevention and proposed diagnostics with prerequisites and expected results
9. Unresolved questions and evidence needed
10. Source references

For each check, label **historical observation**, **reported finding**, or **general diagnostic guidance**. Keep proposed actions separate from executed changes. Record the reviewer, environment, version and test result before promoting a pilot to a released reusable procedure.
