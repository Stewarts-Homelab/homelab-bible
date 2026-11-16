# Docker Container and Network Diagnostics: A Beginner's Guide

**Deployment & Operations Playbook chapter draft · Batch 13 · November 15, 2026**

Use this chapter when a container is missing, repeatedly exits, or appears to be running while a client cannot reach its application. The examples assume Docker Engine on Linux and Compose v2 where indicated. The diagnostic commands query state or validate local configuration. Use an already authorized account and the intended Docker context. Daemon access may grant extensive control of the host even though these particular commands are read-only.

**Validation labels:** **D** means Docker syntax reviewed against official documentation and shell syntax checked. Runtime validation is pending. **F** means tested with disposable Linux socket fixtures in Batch 12. Full enumeration was limited by netlink permissions. All outputs marked **example** are synthetic. Historical observations are listed separately. [Batch 11–12 QA matrix](validation-matrix.md)

## 1. Understanding Docker

An **image** contains the packaged files and defaults for an application. A **container** is an instance created from that image, with its own configuration and process state. **Docker Engine** manages those instances. **Compose** describes a group of services in a YAML file and gives that group a project identity. A Compose service name and its generated container name may differ.

A container can be created, running, paused, restarting, or exited. An exited one usually still appears in an all-containers listing. A restart policy controls certain automatic restarts. A health check is a separate probe configured for the container. Running, healthy, and reachable from a particular client answer three different questions.

A **bind mount** maps a specific host path into a container. A **named volume** is storage managed by Docker and referenced by name. Two containers can each use a path called `/data` with different backing storage. Check both the source and the destination before drawing conclusions about where files reside.

A **network namespace** gives processes a network view, including interfaces, routes, sockets and loopback. On a **bridge network**, containers generally have their own networking views and communicate over a virtual network. On a user-defined bridge, service names or network aliases can resolve when the caller and target share that network. The legacy default bridge has different name-resolution behavior. **Host networking** shares the Docker host's network view on Linux. **Shared container networking** uses another container's network namespace. These arrangements determine the meaning of `localhost`. [Compose networking](https://docs.docker.com/compose/how-tos/networking/)

## 2. Checking Container Health

First answer **is the expected container present on the expected Engine?** The synthetic names below are `demo-app` and `demo_default`. Replace them with names from your authorized project. Run one line at a time.

```bash
docker context show
docker container ls
docker container ls --all
docker container inspect --format 'status={{.State.Status}} exit={{.State.ExitCode}} restarts={{.RestartCount}} policy={{.HostConfig.RestartPolicy.Name}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' demo-app
docker container logs --since 30m --tail 100 --timestamps demo-app
```

| Command | Why and prerequisites | Expected example or concerning result | Interpretation and next safe step | QA |
| --- | --- | --- | --- | --- |
| `docker context show` | Identify the selected context. Needs Docker CLI and access to local CLI settings. No daemon permission required for this local check. | Example: `local-lab`. An unfamiliar context is concerning. | Verify the intended Engine and check for environment or command-line overrides before querying it. Context name alone does not authenticate the Engine. | D |
| `docker container ls` | See running containers. Needs Docker CLI and authorized Engine access, as do the remaining Engine queries. | Example: `demo-app   Up 10 minutes`. An expected name may be absent. | Compare with all containers. Check the project and Engine before treating absence as an application failure. | D |
| `docker container ls --all` | Include stopped containers on the same Engine and account. | Example: `demo-app   Exited (1)`. No matching name may indicate an incorrect target or a container that was never created or has been removed. | Use the exact returned name for inspection. For an exited container, read logs covering the exit before proposing a change. | D |
| Status `docker container inspect` above | Read lifecycle, exit code, restart count, configured policy and health probe state. Needs an existing container and Engine access. | Example: `status=running exit=0 restarts=0 policy=no health=none`. Rising counts, `restarting` or `unhealthy` deserve investigation. | `health=none` means no Engine health state is exposed. A configured probe confirms only its own scope. Check timestamps and application logs. | D |
| `docker container logs --since 30m --tail 100 --timestamps demo-app` | Read recent application output for an existing container whose logs are readable by the Engine. | Example: `2026-01-01T12:00:03Z ERROR upstream name lookup failed`. Empty output or a log-driver error may mean this query cannot retrieve the evidence. | Compare with the incident window and application log location. Look for the first error and any later recovery. Keep raw logs private. | D |

## 3. Understanding Docker Networking

Follow the path from the **caller**. A browser on your laptop, a reverse proxy in Docker, and an app inside a VPN namespace reach the same service through different routes. A **reverse proxy** accepts requests on behalf of an application and forwards them to a configured **origin**, the backend address it uses.

- **Bridge:** Two containers on the same user-defined bridge can typically use the target's service name and container port. Inside one container, `127.0.0.1` reaches its own loopback, so it normally cannot address a separate bridge container.
- **Host:** On Linux, the application binds directly in the host namespace. Inspect the host listener. Normal Docker port publication does not apply to host networking.
- **Shared namespace:** `network_mode: service:gluetun` references a Compose service. `container:gluetun` references an existing container by name. Processes sharing that namespace can use the same loopback if the target application is listening there. Any required Docker port publication is configured on the namespace owner for a bridge-based Gluetun setup. This is separate from VPN-provider inbound forwarding and from the app's own listening socket.

A **published port** is a mapping from a host address and port to a container port. Example: `127.0.0.1:18080` on the host mapped to `8080/tcp` in the container makes the host address loopback-only in ordinary routing. Containers that talk directly on a shared bridge generally use the target's container port. A Docker mapping gives no assurance that a process is accepting connections. Conversely, Docker can implement publication using forwarding rules, so a matching host userspace listener can be absent. IPv4 wildcard `0.0.0.0` concerns IPv4 visibility in the inspected namespace. It does not establish firewall access or IPv6 behavior. [Compose service options](https://docs.docker.com/reference/compose-file/services/) · [Compose networking](https://docs.docker.com/compose/how-tos/networking/)

```bash
docker container inspect --format 'mode={{.HostConfig.NetworkMode}} networks={{json .NetworkSettings.Networks}} ports={{json .NetworkSettings.Ports}}' demo-app
docker network inspect --format 'driver={{.Driver}} members={{range .Containers}}{{.Name}} {{end}}' demo_default
docker container port demo-app
docker container inspect --format '{{range .Mounts}}{{println .Type .Source .Destination}}{{end}}' demo-app
ss -lnt
ss -lnu
```

| Command | Why and prerequisites | Expected example or concerning result | Interpretation and next safe step | QA |
| --- | --- | --- | --- | --- |
| Network `docker container inspect` above | Read effective network mode, membership and ports for an existing container on the authorized Engine. | Example: `mode=demo_default networks={...} ports={...}`. A mode of `container:<id>` with empty network fields may be normal. | Inspect the referenced owner as well. Compare the client's and target's attached networks. Retain only sanitized fields. | D |
| `docker network inspect` above | Verify that the named network exists and identify attached containers. Needs Engine access and the exact network name. | Example: `driver=bridge members=demo-app demo-proxy`. Network not found or expected member absent. | Check Engine, project name and whether the network was intended to be external. Missing membership limits the routes available. | D |
| `docker container port demo-app` | List published mappings for the named container. Needs Engine access. | Example: `8080/tcp -> 127.0.0.1:18080`. Blank output can be expected for an unpublished service or dependent namespace. | Inspect the owner if shared. Verify protocol and intended client path before calling it a fault. | D |
| Mount `docker container inspect` above | Trace volume type, source and destination on the Engine. Needs daemon access and a known container. | Example: `volume /example/volume /data`. An unexpected source or missing mount can explain missing data or settings. | Compare proposed and observed mounts prior to any restart or change. Do not share raw host paths publicly. | D |
| `ss -lnt` | See TCP listening sockets in the current Linux namespace. Requires iproute2 and normally no elevation for addresses and ports. | Example: `LISTEN ... 127.0.0.1:18080`. Wildcard and loopback have different scope. Stderr may report a netlink error even on exit 0. | Compare with publication and app logs. A host query does not inspect a bridge container's sockets. | F |
| `ss -lnu` | See bound UDP sockets in the current namespace. Same prerequisites. | Example: `UNCONN ... 0.0.0.0:15353`. UNCONN is normal for a bound connectionless UDP socket. | Compare expected address, port and protocol. Keep stderr and capture context. Neither socket check tests end-to-end reachability. | F |

### Historical examples

| Date and evidence | What it teaches | Limit |
| --- | --- | --- |
| Dec 18, 2025 indexed Prowlarr material and April 2026 saved guide | A historical excerpt used `container:gluetun`. The later guide documents `service:gluetun` for qBittorrent and suggests a container name for Prowlarr's target. Before choosing a hostname, establish where both processes actually run and which namespace owns the socket. | Historical revisions and source types differ. The actual Dec 18 service discovery and published bindings remain unverified. Batch 03 ledger (private research record) · April guide, lines 417–443 (private research record) |
| Sep 23, 2026 UTC · saved Portainer inspect | Bridge mode, Docker socket bind and named volume `portainer_data` mounted at `/data`. The source/type fields explain where settings lived in that snapshot. | This capture documents Portainer alone. Portainer inspect, lines 37, 47 and 165–175 (private research record) |
| Oct 3, 2026 · indexed Compose/runtime and saved Gluetun logs | The indexed October Compose revision used `service:gluetun`. A dated namespace comparison reported qBittorrent and Gluetun shared a network namespace. Saved Gluetun logs show repeated startup health failures and tunnel restarts. | The logged VPN restarts do not establish Docker container restarts. Full service membership and durable forwarding remain open. Batch 04–05 timeline (private research record) · Gluetun log, lines 13, 38 and 71 (private research record) |
| Nov 13–14, 2026 CST · saved Jellyfin logs | Nov 13 shows a bind-override warning alongside listener messages. Nov 14 shows later all-interface startup. A proxy could still have the wrong origin, route or network even while the app starts. | The actual proxy network relationship, paired network.xml and successful playback are unverified. Nov 13 log, lines 47, 52 and 78 (private research record) · Nov 14 log, lines 39, 88 and 114 (private research record) |

## 4. Troubleshooting Common Problems

| Symptom | First safe checks | What to record before suggesting a change |
| --- | --- | --- |
| Container missing or stopped | Context, running and all-container lists, then status/logs for an existing item. | Engine and project, container name, exit code and first error in the incident interval. |
| Restart loop | Inspect restart count, policy and health. Match container lifecycle to app log timestamps. | Whether the engine restarted the container or the app retried an internal dependency. |
| Missing Docker network | Inspect exact network on same Engine. Compare attached networks and intended Compose project. | Missing network versus missing membership, and whether the configuration declares it external. |
| Incorrect service hostname | Identify the caller's namespace and the target's service or network alias. Check for a shared network. | Caller, target, expected port and resolution error. Use loopback only when the listener shares that network view. |
| Port conflict | Compare existing Docker mappings and host TCP or UDP output. Review any already captured binding error. | Address, protocol, port, namespace and whether Docker implements publication without a userspace listener. |
| Permission denied | Confirm CLI context and approved account, then identify daemon, file or netlink denial. | Exact error and access scope. Avoid bypassing policy by changing socket permissions or group membership. |
| Running but unreachable | Work from application logs to target listener scope, proxy origin and client path. | Which stage has evidence. A health check can pass with a broken client route. |
| VPN-dependent apps lose connectivity | Compare Gluetun and dependent namespace fields, startup logs and reported tunnel state. | Distinguish tunnel egress, host publication, VPN lease and application listener. Preserve the time window and avoid changes until evidence is correlated. |

## 5. Safe Diagnostic Workflow

### Walkthrough · A proxy returns HTTP 502 (synthetic example)

1. **Identify the symptom.** Record time, client and intended route. In this example the reverse proxy returns 502. That establishes the client reached a responding intermediary. The backend remains to be checked.
2. **Check status.** Confirm the context, then list all containers. Example: both `demo-proxy` and `demo-app` are running. Check the health field and policy. A running state confirms only the container process state.
3. **Inspect logs.** Read timestamped output for both containers in the affected window, substituting `demo-proxy` for the proxy. Example: proxy logs report connection refused at the origin while app logs report startup. That directs attention to the origin address, port and listening interface.
4. **Inspect network configuration.** Inspect both containers and the expected network. Example: both members are on `demo_default`. If the proxy configuration points at `127.0.0.1:8080` and the proxy has its own namespace, its loopback is the wrong target for a separate app. Record that as a candidate explanation and verify the configured origin independently.
5. **Check listeners and publication.** Compare the logged app address with the intended internal Docker port. Use host socket output only for the host's view. An unpublished backend can still be reachable by a proxy sharing its bridge. When publication is required, verify the mapped address and protocol. No route change or connectivity probe is performed by these inspection commands.
6. **Compare with intended Compose configuration.** Use the full authorized file set and the original variable and profile context. The example assumes a single local file. Use quiet validation to avoid printing rendered values.

```bash
docker compose -f ./compose.yaml config --quiet
```

| Command | Why and prerequisites | Expected example or concerning result | Interpretation and next safe step | QA |
| --- | --- | --- | --- | --- |
| `docker compose -f ./compose.yaml config --quiet` | Validate the Compose model. Needs Compose v2 and read access to the file and any referenced inputs. Ordinary validation does not require daemon access. | Example: exit 0 and no rendered model. Missing variables may produce warnings, and invalid models can return a nonzero status. | Check stderr and compare the intended service, network and port declarations with inspected state. Validation does not deploy anything or prove the network exists. | D |

7. **Record findings before proposing changes.** Keep a short incident record with the timestamp, context, caller-to-backend path, status/health, first error, network mode and membership, bind scope and published mapping. Label what was observed and what still requires a separately authorized test. Keep sensitive settings out of shared records.

### End-of-chapter reference

- **Order:** Symptom → context and status → logs → network mode and members → socket and published port → intended Compose → recorded findings.
- **Common mistakes:** Diagnose against the wrong Engine, equate `Up` with working playback, use host `localhost` inside a container, expect every container to publish ports, or interpret a service-name error without locating the caller.
- **Scope:** Commands that create, restart, remove or edit resources are outside this chapter. D-labeled commands still need a disposable Engine/Compose runtime check. Use the matrix for prerequisites, cleanup and verification before promoting the chapter. [QA matrix](validation-matrix.md) · [Docker CLI](https://docs.docker.com/reference/cli/docker/) · [Container inspect](https://docs.docker.com/reference/cli/docker/container/inspect/) · [Container logs](https://docs.docker.com/reference/cli/docker/container/logs/) · [Compose config](https://docs.docker.com/reference/cli/docker/compose/config/)
