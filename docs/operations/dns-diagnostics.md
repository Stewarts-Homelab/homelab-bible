# DNS and Name-Resolution Diagnostics: A Beginner's Guide

**Deployment & Operations Playbook · Standalone draft · Batch 15 · November 15, 2026**

Use this read-only workflow when a name will not resolve, one device bypasses filtering, or a container cannot find another service. Run checks from the affected client or equivalent authorized test context. Queries can reveal names and client addresses and can populate caches or query logs. Use a controlled test name and authorized resolvers. None of the network examples below were run against the homelab.

## 1. How a name becomes an address

A **DNS client** asks a resolver about a name and record type. An application may first consult local data, such as the hosts file, or use its own resolver. A **stub resolver** is a small local entry point that delegates DNS work. A **recursive resolver** obtains a complete answer, often from cache. On a cache miss it can follow referrals from the root to the domain's authoritative servers. An **authoritative server** publishes data for its zone. A **forwarder** hands a request to another resolver. For example, a filtering forwarder can answer a matching rule locally and send other queries to an **upstream resolver**.

| Record | Meaning |
| --- | --- |
| A | IPv4 address for a name. |
| AAAA | IPv6 address for a name. An AAAA response can travel over IPv4 DNS transport, and an A response can travel over IPv6. |
| CNAME | Alias pointing at another name, which may need its own address lookup. |
| PTR | Reverse lookup data, commonly mapping an address to a name. It does not authenticate identity. |
| NS / SOA | Zone authority and zone metadata. A negative response can also include an SOA for negative caching. |

A **TTL** is how long a DNS record may ordinarily be cached. Negative answers can be cached as well. A cached result can satisfy a request without a fresh upstream lookup. Applications and browsers can maintain separate caches.

Clients can learn resolver addresses through DHCP or use manual settings. IPv6 may supply resolvers through router advertisements (RDNSS) or DHCPv6. Check both address families and each active link, including a VPN. Clients can select among several resolvers according to implementation and policy. A second public resolver is not guaranteed to be an unused backup. **Filtering** applies policy to a name or client and can return a sinkhole address, NXDOMAIN, REFUSED, or another configured result. A client exception may allow the same name for one device while it is blocked for another. [DNS foundations](https://www.rfc-editor.org/rfc/rfc1034.html) · [IPv6 RDNSS](https://www.rfc-editor.org/rfc/rfc8106.html) · [AdGuard Home FAQ](https://github.com/AdguardTeam/AdGuardHome/wiki/FAQ)

A DNS answer only provides name-resolution information. Routing, firewall policy, TCP or UDP connectivity, TLS validation, and application behavior are separate stages.

## 2. Configured resolver versus answering endpoint

| Observation | What it establishes | What still needs checking |
| --- | --- | --- |
| Router WAN DNS setting | Intended router resolver or forwarding inputs. | LAN DHCP/IPv6 advertisements and what the client received. |
| DHCP or IPv6 advertisement | Resolver information offered by that configuration source. | Applied lease, manual overrides, VPN and application settings. |
| Client resolver list | Configured addresses and sometimes per-link selection. | Resolver selected for this name and transport. |
| Local systemd-resolved stub | For example, `127.0.0.53` is a local listener for stub clients when enabled. | Per-link settings, cache and selected upstream. A Linux host can use another resolver stack. |
| Explicit query with `@server` | Targets a particular address for that command, bypassing the usual resolver choice. | Whether the ordinary client or application uses that path. Network redirection or an intermediary can complicate attribution. |
| Query tool's server field | Immediate responding endpoint as seen by the tool, possibly a stub, router, proxy or forwarder. | Actual upstream or authoritative path. Match service-side logs or authorized telemetry. |
| AdGuard upstream settings | Intended pools and routing rules for forwarded queries. | Which upstream handled a particular request, if any. A cache hit, rewrite or block may avoid upstream contact. |

## 3. Read-only client commands

Replace synthetic names and documentation addresses with authorized equivalents. `allowed.lab.test` is a placeholder for a controlled local zone. The trace example uses the reserved documentation domain `example.net` and is optional. It generates external iterative traffic and should run only in a separately authorized lab.

**F15** means executed with local files in disposable QA. **S** means shell syntax and reference reviewed with functional runtime pending. **B15** means attempted with output limited by workspace permissions. Recorded historical inputs and results appear in §6.

```bash
resolvectl status
resolvectl query allowed.lab.test
cat /etc/resolv.conf
dig allowed.lab.test A
dig @192.0.2.53 allowed.lab.test A
dig @192.0.2.53 allowed.lab.test AAAA
dig +trace example.net A
getent hosts batch15-fixture.test
getent -s files hosts batch15-fixture.test
nslookup allowed.lab.test
nmcli device show
ip route show
```

| Command | Utility and access | Expected or concerning result, limits and next safe step | QA |
| --- | --- | --- | --- |
| `resolvectl status` | systemd tools, running accessible systemd-resolved, normally regular user. | Example: a link lists DNS Servers and Current DNS Server. Check active link, split DNS domains and VPN. A missing bus/service means this tool cannot report resolver state. Inspect the actual manager. | S |
| `resolvectl query allowed.lab.test` | Same prerequisites, authorized query. | Expected address or an explicit resolution failure. It tests systemd-resolved, not every NSS or application path. Reported link and protocol help explain selection. Compare with normal application and explicit DNS results. | S |
| `cat /etc/resolv.conf` | cat and read access. Usually regular user. | Look for nameserver and search lines. A loopback address can be intentional. Missing or unexpected entries warrant checking the network manager or resolved state. A generated file can represent only a stub or part of the effective settings. | S |
| `dig allowed.lab.test A` | BIND tools and authorized resolver access, normally regular user. | Examine status, answer, TTL and SERVER. NOERROR with no A data can mean no record of that type. Timeout, SERVFAIL or unexpected NXDOMAIN needs comparison with a targeted query and logs. SERVER names the immediate endpoint. | S |
| Both `dig @192.0.2.53` queries above | Same tools and reachable authorized server. | Separate A and AAAA responses. A valid answer from the named target establishes that query path only. Compare with the non-explicit query and server logs. An IPv6 DNS endpoint requires a separate authorized test if relevant. | S |
| `dig +trace example.net A` | BIND tools and authorized iterative DNS access. Regular user. | Expect delegation steps and then an answer or referral outcome. A timeout can reflect blocked direct DNS. It does not reproduce the local recursive resolver's cache, filter or application path. Do not use it for private zones. | S |
| Both `getent hosts` queries above | glibc getent with NSS and readable local config, regular user. The second uses glibc's service override. | The normal command follows the hosts database policy. The files-only variant can isolate hosts-file data and returns nonzero on a missing key. Address-family selection differs from an explicit A or AAAA lookup. Compare results to dig, then to the affected application. | F15, files-only and NSS success on fixture |
| `nslookup allowed.lab.test` | BIND nslookup or compatible client, authorized DNS access, regular user. | Shows result and server in typical builds. Server may be a stub/forwarder. Compare status and record type with dig. Unlike getent it queries DNS. | S |
| `nmcli device show` | nmcli and NetworkManager, with authorized access, usually regular user. | Example: per-device IP4.DNS and IP6.DNS. Missing fields or unavailable NetworkManager may indicate another manager or no lease. Inspect active link and compare to the server actually answering. Keep raw addresses private. | S |
| `ip route show` | iproute2 in the relevant Linux namespace, normally regular user. | Default and connected IPv4 routes provide context. The default table does not show every policy route or IPv6 path. Netlink denial limits observation. Inspect the applicable IPv6/VPN routes with authorized access. | B15, exit 1/netlink denied in fixture |

**NSS** is the system policy for choosing name sources, such as files, DNS and local resolver modules. `getent hosts` uses that policy, while `dig` sends DNS requests. A browser's encrypted resolver or an app's own library may add another path. Avoid assuming that either command reproduces the application. [resolvectl](https://www.freedesktop.org/software/systemd/man/latest/resolvectl.html) · [BIND tool manuals](https://bind9.readthedocs.io/en/latest/manpages.html) · [getent manual](https://man7.org/linux/man-pages/man1/getent.1.html)

**Fixture results:** A private mount/network namespace provided a synthetic hosts file only to the fixture. Normal and files-only `getent` returned `127.0.0.42 batch15-fixture.test` with exit 0. A files-only unknown key returned exit 2. No DNS server was queried. `dig`, `nslookup`, `resolvectl` and `nmcli` were unavailable. Fixture namespace and file were cleaned up.

## 4. Verify filtering from a client

Use a pre-existing lab policy and names you control. This walkthrough requires no filter, cache, DHCP, VPN or client setting changes. **Synthetic scenario:** lab clients should use AdGuard Home for `allowed.lab.test` and `blocked.lab.test`. The lab already has an allowed record and a blocking rule. The selected mode returns `0.0.0.0` for A on the blocked name. That expected value is specific to this example.

1. **Verify configuration.** On the affected client record active links, IPv4 and IPv6 resolver candidates, local stub settings and VPN state. A router's DNS setting does not prove the client used it.
2. **Verify arrival.** Query the allowed and blocked name through the client's ordinary DNS path. Note local time zone, exact name, type and SERVER. Then compare with an explicit query to the authorized AdGuard address. Label direct and ordinary results separately.
3. **Match client and request.** View AdGuard's query log in an authorized read-only session. Correlate time, name/type and the logged client identifier. Forwarders, NAT, or proxying can cause the log to show an intermediary. Missing records may also reflect retention, exclusions or cached client responses.
4. **Verify the decision.** Examine allowed, cached, rewritten or filtered status, and the matched rule or list when exposed. Example: the test A query records the expected client and a matching block rule. A response alone, even NXDOMAIN or a sinkhole address, does not prove AdGuard applied that rule.
5. **Verify the response received.** Check status and answer against the predetermined A and AAAA expectations. Account for cache and multiple configured resolvers. Use a fresh prearranged test name when available without changing settings.
6. **Verify the application path.** Repeat with a controlled name through the affected application's normal usage and correlate application diagnostics with the AdGuard record. Check browser Secure DNS, Android Private DNS, VPN split-DNS policy, IPv6 resolvers and bypass profiles. DNS-over-HTTPS and DNS-over-TLS encrypt traffic to a resolver and can go to the intended filter or to a different provider. Inspect configuration without changing it. A browser cache hit or successful page load alone cannot prove resolver selection.

## 5. Docker and application name resolution

On Docker user-defined networks, embedded DNS at `127.0.0.11` typically resolves reachable container names or aliases and forwards other requests. Compose services can resolve by service name on a shared project network. A container name, alias and configured hostname serve different roles. Check effective membership from the caller's viewpoint. On the legacy default bridge, automatic name behavior differs. Host and container resolver settings can differ as well.

Inside a separate container, `localhost` refers to that container's network namespace. Processes sharing a Gluetun namespace share loopback and the network view. Historical Compose has used both `container:gluetun` and `service:gluetun`. Verify membership and the actual listener before assuming an address works. VPN routing, provider DNS, or a local Gluetun forwarder can affect DNS, depending on deployment. A healthy host lookup says little about the VPN namespace. If an application cannot resolve its database or Redis hostname, it can fail before authenticating or making any application request. Distinguish DNS resolution errors from refused connections and credential failures. [Docker Engine networking](https://docs.docker.com/engine/network/) · [Playbook Docker chapter](docker-diagnostics.md)

## 6. Dated homelab examples

| Date and evidence | Finding and limit |
| --- | --- |
| July 18–21 and October 30, 2026, Sony AdGuard | Indexed service and user query excerpts show service startup and a successful localhost lookup after Wi-Fi took over in July. October indexed output reported an allowed reply and a blocked address response, plus upstream error messages and an unavailable systemd-resolved bus. A localhost answer and historical service status do not establish router-wide client filtering, the exact matched rule or which upstream answered. Historical timeline (private research record) |
| November 6–13, 2026, ASUS router and upstream | Indexed records describe temporary Cloudflare DNS after Sony power trouble. The November router capture records a later startup window with DHCP/DNS-related activity. Router settings and that log alone do not establish actual client lease contents, forwarding endpoint, or whether filtering was restored. Cloudflare has been discussed both as a router DNS choice and as an upstream for a filtering service. Preserve those distinct roles. Router capture (private research record) · Batch 05 timeline (private research record) |
| Fire TV exception, historical report with exact date unverified | The user reported that bypassing filtering for the Fire TV restored Paramount+ behavior. Original rule scope, query log and matched playback record were unavailable here. Treat this as a reported workaround. The service symptom alone cannot identify the blocked name or prove the cause. |
| October 3, 2026, Gluetun | The saved log shows DNS exchange failures near VPN health-check restarts. These events illustrate temporal correlation. They do not prove DNS was the initial trigger, the VPN peer/rule cause, or sustained later health. Gluetun log, including lines 13–26 (private research record) |
| May 11–12, 2026, Immich | Indexed handoff identifies database/Redis hostname failures, including `getaddrinfo EAI_AGAIN redis`, and replacement names `immich_postgres` and `immich_redis`. Original later screenshots show healthy server/database and a successful SQL query after correcting the table name. They do not establish the exact Compose edit or verify that the replacement names caused recovery. May service and first SQL capture (private research record) · Later SQL capture (private research record) · Case H-014 (private research record) |
| November 2026, HP ProDesk | Fresh DNS service on the HP was planned. First boot, actual mount or client resolver changes, and allowed/blocked client checks remain unverified. Replacement plan (private research record) |

## 7. Troubleshooting quick reference

| Symptom | First safe comparison | What to record before changes |
| --- | --- | --- |
| Direct AdGuard query works, ordinary path differs | Compare response endpoints, active links, IPv6 candidates and VPN policy. | Exact client/time/name/type and both outputs. |
| Server answers; app behaves differently | Compare NSS result with app diagnostics, caches and encrypted DNS settings. | Whether app lookup appears in the expected filter log. |
| DNS times out or fails | Compare scoped normal and explicit queries, resolver logs and route context. | Endpoint, status/error, link and transport. |
| Name resolves; site or app fails | Check existing client or service logs for route, firewall, connection, TLS or HTTP errors. | Last stage with evidence. An address answer is not a successful connection. |
| Container cannot resolve service | Review actual network membership, alias, caller and namespace. | Exact name lookup error and whether the targets shared the expected network. |

**Repeatable sequence:** identify affected client and scope → check configured DNS → identify immediate answering endpoint → find the expected filter's client/request → verify decision and response → compare NSS and application → investigate cache, IPv6, encrypted DNS and VPN → separate route/TLS/app issues → record facts and unresolved hypotheses before proposing changes. No step requires restarting, editing settings, flushing caches or changing policy.
