# Batch 11 — command validation matrix and documentation QA

**November 15, 2026 · Disposable Work Linux workspace · Historical pilots**

## Environment

Debian GNU/Linux 13.6 (trixie), kernel 6.18.57. Effective UID/GID 1000/1000, unprivileged, with no sudo binary. PID 1 was the workspace process. No Docker CLI, Engine, Compose, socket, or smartctl was found. No usable block-device sysfs or loop-control path was exposed. No readable journal files were present. A private user/mount/network namespace could be created, with UID 0 scoped to the namespace. A 4 MiB tmpfs fixture mounted and unmounted successfully there. A separate network namespace could not enable loopback because the operation was denied. The listener check used a temporary loopback socket in the already disposable workspace. Fixtures comprised a temporary fstab, XML, text log, PCM WAV, and a zero-filled synthetic MKV. No actual disks, external endpoints or live Docker services were queried.

Versions: util-linux 2.41.5 (lsblk/findmnt), GNU coreutils 9.7 (df), iproute2 6.15.0 (ss), systemd 257.13 (journalctl), FFprobe 7.1.5, GNU grep 3.11. Docker/Compose and smartmontools versions unavailable.

## Executed command matrix

`<fixture>` denotes the generated directory. Commands below use test arguments and abbreviated, sanitized output. **Pass** confirms the scoped expectation. **Blocked** denotes missing capability or a partial result. Expected negative tests can pass even when the shell exit status is nonzero.

| Command | Permissions | Expected behavior and actual result | Status and documentation decision |
| --- | --- | --- | --- |
| `lsblk -o NAME,TYPE,SIZE,FSTYPE,MODEL,MOUNTPOINTS /dev/nonexistent-b11` | Regular user | No successful disk inventory expected with a synthetic path. Exit 1, failed to access /sys/dev/block. | Blocked for inventory. Test on a VM with a synthetic virtual disk. |
| `findmnt --target <fixture> -o TARGET,SOURCE,FSTYPE,OPTIONS` | Regular user | Exit 0, underlying workspace overlay returned for ordinary directory. Missing child path returned exit 1. | Pass. Clarify containing filesystem versus exact mount. |
| `findmnt --mountpoint <fixture> -o TARGET,SOURCE,FSTYPE,OPTIONS` | Regular user and namespace-scoped test setup | Ordinary directory exit 1. Exact mounted fixture returned tmpfs, rw, size 4096k. | Pass. Added exact-match check. |
| `findmnt --fstab --tab-file <fixture>/fstab -o TARGET,SOURCE,FSTYPE,OPTIONS` | Regular user | Exit 0, exact fixture target with tmpfs and defaults. | Pass on fixture. Replace --tab-file with normal host table only when authorized. |
| `findmnt --verify --verbose --tab-file <fixture>/fstab` | Regular user | Exit 0, target exists, pseudo source/type not checked, no warnings. | Pass on fixture. Verification cannot predict a successful reboot. |
| `df -hT <fixture>` | Regular user | Exit 0, shows type and human units. Private mount run showed tmpfs 4.0M. | Pass. Verify target first. |
| `df -B1 <fixture>` | Regular user | Exit 0, byte columns on workspace overlay. Missing child exited 1 with No such file or directory. | Pass. Compare same filesystem and time window. |
| `ss -lntu` | Regular user | Exit 0 and synthetic TCP loopback listener visible. Stderr included netlink Operation not permitted. Private netns loopback setup also denied. | Pass for observed TCP socket, blocked for full enumeration. Review stderr. |
| `journalctl -k -b --since '1 hour ago' --no-pager` | Regular user in test, no sudo available | Exit 0 with No entries and No journal files were found. | Blocked for actual kernel log retrieval and elevated variant. Empty journal is not a health test. |
| `journalctl -u docker --since '1 hour ago' --no-pager` | Regular user in test | Same output and exit 0. Docker unit absent from this test setup. | Blocked for service journal. |
| `grep -nE 'Bind|PublishedServerUri|KnownProxies|EnableRemoteAccess' <fixture>/network.xml` | Regular user with file access | Exit 0 returns two expected fields. Mode 000 fixture returned exit 2 and Permission denied. | Pass for matching and permission negative case. Does not validate XML. |
| `ffprobe -v error -show_streams -show_format <fixture>/sample.wav` | Regular user, readable fixture | Exit 0, PCM signed 16-bit audio stream. | Pass. |
| `ffprobe -v error -show_streams -show_format <fixture>/sample.mkv` | Regular user | Synthetic zero-filled MKV returned exit 1, EBML header parsing failed and Invalid data found. | Pass for expected rejection. Historical file remains unresolved. |
| `grep -n ERROR <fixture>/service.log` | Regular user | Exit 0 found synthetic timeout. The fixture also had a later successful retry. | Pass for locating an error. A log entry alone does not establish present failure. |
| `PATH=/definitely-absent-b11 findmnt --version` | Regular user | Exit 127, command not found under simulated missing PATH. | Pass for expected failure. Check installation/PATH before diagnosing service health. |

## Blocked commands and scenarios

| Exact invocation attempted or specified | Required access and expected result | Actual limitation |
| --- | --- | --- |
| `smartctl -a <fixture>/fake-disk` | smartmontools and usually elevated access on a supported whole device. A non-device or unsupported backend cannot return telemetry. | Executable missing at launch. The documented sudo variant and actual unavailable SMART data from a backend remain untested. Use a simulated backend or sanitized capture in an isolated VM. |
| `docker --version` and `docker compose version` | Installed CLI and Compose plugin. | Executable missing at launch. |
| `docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'` | Authorized connection to a disposable Docker daemon. An exited test container should remain visible with -a. | Executable missing at launch. Stopped-container scenario untested. |
| `docker inspect --type container --format 'mode={{.HostConfig.NetworkMode}} networks={{json .NetworkSettings.Networks}} ports={{json .NetworkSettings.Ports}}' jellyfin` | Same daemon. Inspect scoped network and port state. | Executable missing at launch. Test an isolated app/proxy pair and absent network in Batch 12. |
| `docker inspect --type container --format '{{range .Mounts}}{{println .Source .Destination}}{{end}}' jellyfin` | Same daemon. Inspect a fixture bind and named volume. | Executable missing at launch. No runtime verification. |
| `docker logs --since 30m --tail 100 --timestamps jellyfin` | Same daemon with readable container logs. Expect timestamped output and an injected fixture error when present. | Executable missing at launch. Text fixture only confirmed error filtering. |

The private tmpfs, test files and loopback socket were session fixtures. The tmpfs was unmounted inside its namespace. A missing tool, denied permission, absent target or restricted log source limits the diagnosis. Confirm the observation path before deciding that an application, disk or network is unhealthy.

## Reusable documentation QA checklist

| Check | Acceptance test | Scope |
| --- | --- | --- |
| Source and provenance | Verify dates, versions and exact source lines. Label historical observations, reported claims, plans, test results and unknowns. | Desk review |
| Expected and failure results | Record exact command, versions, actual stdout/stderr and exit status. Run one normal and one relevant negative case where supported. | Isolated fixtures or disposable VM |
| Prerequisites and permissions | State utilities, daemon/namespace, path assumptions and effective privileges. Test a lower-privilege case when meaningful. | Isolated fixtures |
| Safety and rollback | Separate read-only observation from state changes. Test changes on synthetic or disposable state. For procedures that change state, document backups, rollback triggers and verification. | Isolated first. Real changes require separate authorization. |
| Beginner readability | Define terms before use. For every command explain the question it answers, expected result, concerning result and next safe step. | Desk review and novice walkthrough |
| Real-world scope | Keep successful fixture checks separate from real device health, production network reachability, and historical resolution. Verify device identity, live routes, playback and deployed bindings only with authorization. | Separately authorized infrastructure tests |
| Sensitive material | Remove credentials, keys, internal endpoints, IDs and unrelated personal data. Keep synthetic examples visibly labeled. | Desk review |
| Persistence | Reopen saved versions, compare to reviewed text and update recovery steps. | Save/readback |

**Batch 12:** Obtain an isolated Linux VM with synthetic block storage and local Docker/Compose. Validate stopped containers, denied daemon access, missing network, shared network and timestamped container/journal logs. Validate SMART unavailability with a mock backend or controlled test fixture. Reassess any procedure needing actual hardware or end-to-end service testing only with separate authorization.

## Batch 12 — additional disposable workspace results

Debian 13.6, kernel 6.18.57, UID/GID 1000, CapEff zero and NoNewPrivs=1. The private user/mount namespace mapped UID 0 inside the namespace only. iproute2 6.15.0 and journalctl 257.13. No VM launcher, guest disk, usable block sysfs, loop control, Docker Engine/Compose, local Docker socket, smartctl or system journal was available. This was a disposable workspace with socket fixtures and private tmpfs for the journald attempt, without a guest VM. Batch 11 successful mount, df and file tests were reused without rerunning them.

| Exact command or prerequisite | Access and expected outcome | Actual exit, stdout and stderr | Result and effect |
| --- | --- | --- | --- |
| `ss -lnt` | Regular user, two synthetic TCP listeners in the workspace. Expect LISTEN at loopback and wildcard. | 0. Filtered stdout showed LISTEN at 127.0.0.1:47219 and 0.0.0.0:34201. Stderr: Cannot open netlink socket: Operation not permitted. | Pass for fixture sockets, incomplete enumeration. A wildcard bind does not demonstrate client reachability. |
| `ss -lnu` | Regular user, two synthetic UDP sockets. Expect bound sockets, generally UNCONN. | 0. Filtered stdout showed UNCONN at 127.0.0.1:47016 and 0.0.0.0:35618. Same netlink warning. | Pass for fixture sockets, incomplete enumeration. UNCONN is normal for these UDP sockets. |
| `ss -lntu` after closing fixtures | Regular user. Expect all four fixture ports absent. | 0. Filtered stdout had only header. Two netlink warnings remained. | Pass for fixture cleanup. Socket close is the fixture for a stopped listener. No systemd service was stopped. |
| `journalctl --directory <fixture> --no-pager -o cat` on new empty directory | Directory owner, regular user. Expect no records. | 0. Empty stdout and stderr. | Pass. A successful empty query proves no records returned within this scope. |
| Same journalctl command, fixture mode 000 | Same user without directory access. Expect permission denial. | 1. Empty stdout. Stderr: Failed to open <fixture>: Permission denied. | Pass for negative case. Check access and source separately from service health. |
| `unshare --user --map-root-user --net ip link show` | Namespace-scoped UID 0. Verify available network introspection. | 1. Stderr: Cannot open netlink socket: Operation not permitted. | Blocked. Tests used short-lived sockets in the disposable workspace, with no connection, accept or application data. |
| `mount -t tmpfs -o size=16m tmpfs /var/log` inside initial private namespace | Namespace-scoped UID 0, private mount propagation. | 32. Stderr said mount point does not exist. | Failed fixture setup. Retried using private tmpfs on /var and created /var/log/journal there. |
| `/usr/lib/systemd/systemd-journald` inside private namespace with tmpfs on /run and /var | Namespace-scoped UID 0. Expect private socket and isolated test ingestion. | Runner exit 2 because socket never appeared. Daemon stderr: socket() failed: Operation not permitted. Child was reaped. | Blocked for populated journal and real kernel/service queries. No synthetic entry was represented as a real journal record. |
| Batch 11 `lsblk` inventory and `sudo smartctl -a /dev/sdb` | Disposable block device with accessible guest sysfs and SMART tooling/backend. | Prerequisite inspection found no supported guest/device/tool combination. No new device command executed. | Blocked. A regular file cannot supply hardware SMART telemetry. Supported/unsupported backend and device permission cases remain outstanding. |
| Batch 11 Docker commands and `docker compose config` | Isolated local daemon and Compose plugin, synthetic image and project. | Executables and local daemon unavailable. Not run. | Blocked. Stopped container, absent network/container, denied daemon access, port/bind/volume/logs, lifecycle, Compose validation and Docker cleanup tests remain pending. |

**Cleanup verified:** The four fixture ports disappeared after closure. The two journal setup fixture directories and the empty/denied journal fixture directory were removed. The private tmpfs views ended with their namespaces. The journald child was reaped. No Docker resources were created.

**QA additions:** Log stderr even when exit status is zero. Define success at the level of the demonstrated output (one known socket versus all interfaces). Treat administrative access inside a namespace separately from actual kernel capabilities. For cleanup, check the exact test resources and capture the result. A journal source must be readable and populated before using query results for a service or kernel claim.

**Readiness:** Use the pilots as templates for additional read-only chapters with per-command evidence labels. Filesystem and scoped listener/file diagnostics can advance. Keep Docker Engine/Compose and populated journal walkthroughs provisional until an isolated guest is supplied. Validate SMART values against a known capture or real supported device with separate permission. Actual production network paths and end-to-end Jellyfin playback require a matched authorized client test. An unresolved historical cause does not block unrelated diagnostic guidance.
