# Logs, Timestamps, and Incident Correlation: A Beginner's Guide

**Deployment & Operations Playbook · Standalone draft · Batch 17 · November 15, 2026**

Use this guide to turn scattered log entries into a short, evidence-backed incident timeline. Start with the affected client or service and one time window. Keep original entries intact and record inferences separately. Use authorized, read-only access and share only sanitized extracts.

## 1. Read a log as a record of an event

A **symptom** is what someone experienced, such as a failed video load. An **event** is something one component recorded, such as a socket error or startup. A log tells you what that component emitted within its logging scope.

| Source | What it can help answer |
| --- | --- |
| Application log | Did the application start, serve a request, report a dependency problem, or finish the operation? |
| System log and systemd journal | What did the service manager and system record? The journal can include structured fields for units, boots, priorities and process context. |
| Kernel log | Did the OS report driver, link, device or I/O events? Kernel messages may also be visible through the journal. |
| Docker container logs | What stdout/stderr records did the container's logging setup expose? An app may write additional files. |
| Router and firewall logs | Did the device record link, DHCP, policy or forwarding events? Logging of accepted or dropped traffic depends on policy. |
| Reverse-proxy and VPN logs | Did a request reach the frontend, and did the proxy reach its upstream? Did the tunnel report handshake, health or reconnect events? |

Severity expresses what the producer considers debug, informational, warning, error or critical. It varies by application. For example, a request logged at INFO can still carry HTTP status 502. Plain text is useful for reading lines. Structured logs, such as JSON, have named fields and may distinguish HTTP status from severity.

**Rotation** moves or replaces old log files. **Retention** determines how much history remains. A missing error can reflect disabled logging, log level, rotation, wrong source, restart, access limits, buffering or delayed forwarding. Check the source and the window before drawing a conclusion. No error found does not establish successful service behavior.

## 2. Make timestamps comparable

- **UTC** provides a shared reference. A timestamp ending in `Z` uses UTC. An **offset** such as `-05:00` tells you the difference from UTC at that instant. `America/Chicago` is a region whose offsets change with daylight saving time. A line like `Nov 12 21:37:17` may lack the year and zone. Preserve it and leave its UTC value unknown until you can support the conversion.
- **Timestamp formats** vary. ISO-style strings can carry date, time, fractional seconds and offset. Unix **epoch** values count from 1970-01-01 00:00:00 UTC. Confirm whether a number is seconds, milliseconds or another unit before converting.
- **Wall-clock time** is calendar time. It can jump after a clock change or synchronization. **Monotonic time** measures elapsed time against a local reference, often within one boot. It helps order local events without relying on wall-clock adjustments. Comparing it across hosts or boots requires an explicit mapping.
- Clocks can drift or be incorrectly set. **NTP** synchronizes clocks over a network. Record the clock and synchronization status if available. Present synchronization does not establish earlier accuracy. Many printed digits indicate precision, while actual clock accuracy may be lower.
- **Event time** is when the source says something happened. **Ingestion time** is when a collector received or stored it. Delay can reverse apparent order. Record which timestamp you used. Preserve ties and uncertainty rather than inventing an exact sequence.

## 3. Synthetic exercise · One incident crosses local midnight

All rows below are made up for training. UTC date remains July 10, 2026. Chicago uses **CDT (UTC−05:00)** on that date.

| UTC | America/Chicago | Synthetic event | Classification |
| --- | --- | --- | --- |
| Jul 10 04:58:45Z | Jul 9 23:58:45 CDT | Router connectivity warning | Potential contributing event |
| Jul 10 04:59:10Z | Jul 9 23:59:10 CDT | VPN tunnel interrupted | Recorded tunnel interruption, relationship to router unknown |
| Jul 10 04:59:35Z | Jul 9 23:59:35 CDT | Container connection refused | Confirmed failure for that attempt |
| Jul 10 05:00:05Z | Jul 10 00:00:05 CDT | Client receives proxy HTTP 502 | First observed client symptom |
| Jul 10 05:02:10Z | Jul 10 00:02:10 CDT | Later proxy request returns HTTP 200 | Observed recovery for one request |

July 10 04:58:45 UTC becomes the previous calendar day in Chicago. In January, 05:00 UTC can be 23:00 on the previous date under CST (UTC−06:00). On November 1, 2026, 06:30 UTC and 07:30 UTC both map to local 01:30, with CDT and CST offsets respectively. Sort by the normalized instant, not the repeated local clock time. To link the synthetic events causally, obtain matched routing, socket, proxy and backend evidence. The root cause is unverified.

## 4. Read-only commands and interpretation

Run one line at a time. `demo-proxy` and `incident.log` are synthetic analyst inputs. Use actual authorized inputs on a relevant host. UTC bounds in the examples avoid ambiguity. On older tool builds check the local manual before relying on option support.

```bash
journalctl --no-pager -n 30
journalctl -u demo-proxy.service --utc --since '2026-07-10 04:58:00 UTC' --until '2026-07-10 05:03:00 UTC' -o short-iso --no-pager
journalctl -k -b --utc --since '2026-07-10 04:58:00 UTC' --until '2026-07-10 05:03:00 UTC' -o short-iso --no-pager
docker logs --since 2026-07-10T04:58:00Z --until 2026-07-10T05:03:00Z --timestamps --tail 100 demo-proxy
grep -nE 'WARN|ERROR|HTTP 200' -- ./incident.log
tail -n 3 -- ./incident.log
env TZ=America/Chicago date -d '2026-07-10T04:58:45Z' '+%F %T %Z %z'
date -u -d '2026-07-10T04:58:45Z' '+%FT%TZ'
date -u -d '@1783659525' '+%FT%TZ'
timedatectl status
```

| Exact invocation above | Purpose, prerequisites and permissions | Expected and concerning results, limits and next step | QA |
| --- | --- | --- | --- |
| `journalctl --no-pager -n 30` | Read recent accessible journal entries. Needs systemd tooling and journal files. Regular users may see a subset. Use approved journal privileges where needed. | Expect timestamps and messages. Empty with successful exit can mean no readable records in scope. No files or permission denied calls for checking source, role and retention. | S; B11–12 showed empty/denied cases on other invocations. |
| `journalctl -u demo-proxy.service …` | Filter by system unit and bounded time window. Same permissions. `--utc` prints UTC and `short-iso` shows an ISO-style timestamp. | Expect matching unit entries. Wrong unit, timezone interpretation or retained window can yield no matches. Confirm unit identity, access and window. | S, populated journal pending. |
| `journalctl -k -b …` | Read kernel entries from the current boot within a window. Same journal prerequisites. Kernel visibility may require approved elevated access. | Expect device/link or other kernel messages. A historical window can fall outside the current boot. Find the appropriate retained boot and verify clock and device identity. | S, populated journal pending. |
| `docker logs … demo-proxy` | Read scoped stdout/stderr from an existing container with accessible logging. Needs Docker CLI and authorized daemon access. | Expect timestamped lines. Empty output can reflect the cap, rotation, log destination, window or driver. Check the app's own logs. Engine timestamps can differ from embedded application times. | S, Docker runtime pending. |
| `grep -nE 'WARN\|ERROR\|HTTP 200' -- ./incident.log` | Search a readable local text file and show line numbers. Needs GNU grep or compatible options, normally regular user. | 0 means matching lines, 1 means no match and 2 indicates a GNU grep error. A filter may miss alternate spellings or structured fields. Reopen context before citing. | F17 |
| `tail -n 3 -- ./incident.log` | Read the final three lines of a readable file. Needs tail, normally regular user. | Output follows file order, which can differ from event order. A missing file or stale tail makes the window uncertain. Check rotation and capture coverage. | F17 |
| `env TZ=America/Chicago date -d …` | Convert an offset-bearing timestamp using the named zone without changing the system zone. GNU date, env and zone data, regular user. | Example: `2026-07-09 23:58:45 CDT -0500`. Unexpected offsets warrant checking source format, date and installed zone data. | F17 |
| Both `date -u -d …` forms | Normalize ISO-style time and epoch seconds to UTC. GNU date, regular user. | Both shown inputs return `2026-07-10T04:58:45Z`. Invalid input or wrong epoch units produce error or misleading dates. Preserve original value and verify plausible calendar range. | F17 |
| `timedatectl status` | Inspect current clock and synchronization state. Needs systemd tooling and accessible system bus/time service. Normally regular user for status. | Example: local/UTC, zone and clock synchronization. Bus errors or unavailable sync detail limit the check. Record limitations and use dated cross-system evidence for historical drift. | S, runtime pending. |

One empty result can mean no match in an accessible source, an unpopulated source, or an unavailable history window. A missing file is a source error. Permission denial means the tool could not inspect the evidence. Capture stderr and exit status alongside stdout. [journalctl](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html) · [timedatectl](https://www.freedesktop.org/software/systemd/man/latest/timedatectl.html) · [Docker logs](https://docs.docker.com/reference/cli/docker/container/logs/) · [GNU date](https://www.gnu.org/software/coreutils/manual/html_node/date-invocation.html)

## 5. Build a timeline you can defend

1. Define the incident, affected client/service and observed symptom.
2. Set a time window with a little context before and after the symptom.
3. List the relevant router, kernel, container, proxy, VPN and application sources.
4. Record each source's zone, timestamp type, clock reliability and coverage.
5. Normalize explicit instants to UTC and preserve unknown offsets.
6. Preserve the original log entries and their source line or request reference.
7. Build the event table. Keep uncertain order and clock differences visible.
8. Mark direct observations and match requests with identifiers where available.
9. Put causal hypotheses in a separate note with competing explanations and a test.
10. Check recovery from the same client or operation and look for recurrence.
11. Record gaps, evidence still needed and the next safe investigation. Pause before changes.

| Source | Original timestamp | Normalized UTC | Event | Confidence and why | Evidence reference |
| --- | --- | --- | --- | --- | --- |
| Example: proxy | 2026-07-10T00:00:05-05:00 | 2026-07-10T05:00:05Z | HTTP 502 on example request | High for the logged status only | Synthetic row, request A |

**Correlation** means events align in time or pattern. **Causation** needs evidence of a mechanism linking them. A **root-cause hypothesis** is a candidate you can test. A **confirmed root cause** explains the observed failure with traceable evidence and rules out plausible alternatives to the extent required by the claim. For example, an error followed by a restart and then a success does not prove the restart fixed the cause. A **temporary recovery** is a successful observation after failure. A **durable resolution** needs repeated validation or suitable monitoring under the relevant conditions.

Use high confidence for a scoped direct observation, medium for a corroborated or dated reported observation, and low for an inference from a gap or timing alone. Give status and cause separate confidence labels. A 502 followed by 200 may cover different clients, origins or paths. An error-free later capture may start after recurrence stopped or may miss the time it returned. [Service-path diagnostics](reachability-diagnostics.md)

## 6. Historical homelab cases · Separate evidence windows

| Case | Direct observation and what it supports | Open questions and next evidence |
| --- | --- | --- |
| ASUS router, Nov 12–13, 2026 context | Earlier capture begins `Nov 12 21:37:17` with `MDIO Error: MDIO got failure status on phy 25`. Later capture has DHCP configuration/startup activity at `Nov 13 00:39:54` and no matching MDIO warning. Keep the emitted router timestamps as written. Earlier, lines 1–4 (private research record) · Later, lines 94–109 (private research record) | The lines themselves omit a year and offset. Capture context supports the date range, while exact UTC alignment needs clock evidence. The WAN fault, client connectivity and durability remain open. Seek synchronized WAN link, DHCP, gateway and client measurements. |
| Gluetun, Oct 3, 2026 | The startup health check triggered VPN restarts at 16:10:53, 16:10:58 and 16:11:02 with offset −05:00. DNS exchange failures appear nearby. Lines 13–26, 38 and 71 (private research record) | Shows tunnel health/retry observations. Does not establish a Docker container restart, DNS as the trigger, router causation or sustained VPN reachability. Seek effective namespace, tunnel and matched DNS/egress records. |
| Shelfarr, Sep 10, 2026 | Structured request entries show `/search/results/stream` returning 502 at 17:59:11.722 −05:00 and 200 at 17:59:19.879 −05:00. A nearby Google Books rate-limit error is also logged. Lines 15, 21 and 34 (private research record) | Shows later endpoint success in this capture. The rate limit may be unrelated. Seek request/upstream correlation and repeat validation for a causal or durable claim. |
| Jellyfin, Nov 13–14, 2026 | Nov 13 00:16:35.956 −06:00 shows an invalid bind override warning and 00:16:37.542 shows a listener message. Nov 14 includes all-interface startup at 12:10:35.126 and 12:10:41.997 −06:00 and bind addresses between those messages. Nov 13, lines 47 and 78 (private research record) · Nov 14, lines 39, 88 and 114 (private research record) | Startup is confirmed within the log scope. Exact XML change, proxy origin and sustained playback remain unverified. Seek paired sanitized settings, matched proxy/backend logs and a client playback record. |

## 7. Validation record

Disposable synthetic text only. GNU coreutils 9.7 and GNU grep 3.11. `grep` hit returned 0 with five numbered lines, no match returned 1 without output, and missing file returned 2 with `No such file or directory` on stderr. `tail` returned 0 with the three expected trailing events. Both UTC conversions returned 0 with the same timestamp. GNU date and Python zoneinfo agreed on all five exercise rows and three seasonal/fall-back checks, using local timezone data. This independent implementation comparison does not test an external clock. Fixture removal was confirmed. A redundant shell cleanup trap then tried to remove the already absent directory and reported a benign missing-directory error. Populated journal, Docker and timedatectl runtime tests remain pending. No production logs or endpoints were queried. [Validation matrix and QA checklist](validation-matrix.md)
