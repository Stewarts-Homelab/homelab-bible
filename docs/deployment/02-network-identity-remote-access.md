# Stage 3: Network Identity and Secure Remote Administration

**Goal:** Give a newly installed Ubuntu Server a predictable name, verify its network connection, and enable secure administration from another computer when needed.

**Audience:** Beginners using Ubuntu Server 24.04 LTS on an authorized home or small-office network.

**Prerequisite:** Complete [Stage 2: Ubuntu Server Foundation](01-ubuntu-server-foundation.md). Keep physical or VM-console access available throughout this stage.

> **Safety rule:** Do not disable password authentication, change a working static address, or enable internet-facing SSH until you have verified a replacement way to connect. This guide does **not** require opening any router ports.

## 1. Understand the pieces

- **IP address:** Where the server can be reached on its network.
- **Default gateway:** The router used to reach other networks.
- **DNS:** Turns names into addresses.
- **DHCP:** Automatically provides an address and often gateway/DNS settings.
- **Hostname:** The server's own recognizable name.
- **SSH:** An encrypted way to administer the server from another device.
- **Firewall:** Controls which incoming connections are allowed.

For most beginners, **DHCP plus a router-side DHCP reservation** is easier and safer than immediately writing a static network configuration. A reservation asks the router to give the same address to the same network interface.

## 2. Record your existing connection

On the **Ubuntu server's local console**, run:

```bash
hostnamectl --static
ip -br address
ip route
resolvectl status
timedatectl status
```

**What to look for:** A recognizable hostname, an active interface with an address, a default route when the network requires one, a working DNS resolver, and correct time.

Write down the active interface name, current IP, gateway, and resolver in **private** notes. Never assume your interface is named `eth0`; modern Ubuntu systems often use names such as `enp1s0`.

### Checkpoint

- [ ] The server has the expected network address.
- [ ] I know how to return to its local console.
- [ ] I recorded the current network settings before changing anything.

## 3. Choose a stable address

**Recommended: DHCP reservation at the router.**

1. Find the server's Ethernet interface in your router's DHCP client list.
2. Match it carefully against the server's interface information.
3. Reserve an unused address appropriate for your LAN.
4. Follow your router's instructions to renew the lease or reboot at a suitable time.
5. Confirm the server received the intended address using `ip -br address`.

**Why:** Applications and other devices need a predictable destination, but you avoid managing static routes and DNS settings on the server itself.

**Alternative: Static IP using Netplan.** This is an advanced branch, not required for this stage. Use it only after recording the exact interface, subnet, gateway, DNS servers, and existing YAML. Ubuntu Server commonly uses Netplan, but the active renderer and configuration must be checked first. An incorrect static configuration can disconnect SSH. Use the local console and `sudo netplan try` with a rollback timeout when following a separately reviewed static-IP procedure.

> **Do not** copy a stranger's Netplan YAML unchanged. Interface names and subnets differ, and YAML whitespace matters.

## 4. Confirm the hostname and DNS

Check the current hostname:

```bash
hostnamectl --static
```

If it already matches your plan, **leave it alone**.

If it needs changing, choose a short hostname without spaces, then replace the example below with your choice:

```bash
sudo hostnamectl set-hostname homelab-server
hostnamectl --static
```

This changes the system hostname. It does **not** automatically create a DNS record on your router or DNS server.

To test network reachability and name resolution:

```bash
ping -c 3 1.1.1.1
getent hosts ubuntu.com
```

**Interpretation:** The first command tests reachability to a public IP if ICMP is allowed. The second checks name resolution through the system's normal lookup configuration. If DNS succeeds but ping fails, ICMP filtering may be involved. Neither command proves that your *server's hostname* is resolvable by other devices.

For local-name access, configure a DNS record or router-provided name according to your network design. Do not assume every home router publishes DHCP hostnames.

## 5. Check time synchronization

```bash
timedatectl status
```

Confirm the clock is correct and synchronization is active where expected. Accurate time matters for logs, TLS certificates, and troubleshooting. If time is wrong, investigate the time source and network before changing settings at random.

## 6. Decide whether SSH is needed

**If you will manage the server only at its local console, you can skip SSH.** No rule says every homelab machine needs a remotely accessible shell.

For administration from another trusted computer on the **same LAN**, OpenSSH is a common choice. First confirm you have local console recovery and know the server's current IP.

On the server, check whether the SSH service is already installed and running:

```bash
systemctl status ssh --no-pager
```

If it says the unit is not found, install OpenSSH Server using the Ubuntu package manager:

```bash
sudo apt update
sudo apt install openssh-server
```

Then verify:

```bash
sudo systemctl enable --now ssh
systemctl is-active ssh
```

Expected: `active`. Installing or enabling SSH changes the host's service exposure, so do this only on a network where you are authorized to administer the machine.

## 7. Connect from a trusted computer

From a **different computer** on the same approved network, replace the username and address with your own:

```bash
ssh your_username@192.168.10.20
```

The address above is an **example**, not an address you should blindly use.

On the first connection, SSH shows the server's host-key fingerprint. **Verify the fingerprint through a trusted channel** before accepting it. You can inspect the server's ED25519 public host-key fingerprint from its local console:

```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

If the key is absent, investigate the SSH installation instead of inventing a fingerprint. Once verified, accept the key on the client and sign in.

After connecting:

```bash
whoami
hostnamectl --static
```

Check that you are logged into the intended account on the intended server. Then use `exit` to disconnect.

### Checkpoint

- [ ] SSH is reachable from an approved client, if enabled.
- [ ] I verified the host-key fingerprint.
- [ ] I can sign in and return to the local console.
- [ ] No router port-forwarding was needed.

## 8. Firewall: allow only what you need

Ubuntu often uses **UFW** as a convenient firewall interface, but it may not be enabled by default. Check its state first:

```bash
sudo ufw status verbose
```

**If UFW is inactive and SSH is needed:** At the local console, plan the allowed management sources and rules *before* enabling it. A simple LAN-only example, assuming your trusted subnet really is `192.168.10.0/24`, is:

```bash
sudo ufw allow from 192.168.10.0/24 to any port 22 proto tcp
sudo ufw enable
sudo ufw status verbose
```

Replace the example subnet with your **actual authorized management subnet**. The rule allows SSH from that entire subnet, not from just one admin computer. For tighter access, use a trusted admin host's individual IP instead. Review existing firewall policies before adding rules. If UFW is already active, do not blindly enable it again or overwrite existing policy.

**Immediately test a new SSH session from the approved client while keeping the console open.** If access fails, recover at the console and review the firewall rules. Firewall changes are not risk-free.

**Never forward TCP port 22 from your internet router just to complete this guide.** Remote-from-anywhere access is a separate design involving VPN or another approved management path.

## 9. Optional: SSH keys

SSH keys are recommended for ongoing administration, but configure them **before** disabling any existing login method.

On the **client computer**, check whether you already have a suitable SSH key. If not, create an Ed25519 key:

```bash
ssh-keygen -t ed25519
```

Protect the private key and consider a passphrase. Do not upload it to GitHub or share it with a guide author.

If `ssh-copy-id` is available and password login is currently permitted:

```bash
ssh-copy-id your_username@192.168.10.20
```

Open a **new** connection to test key authentication:

```bash
ssh your_username@192.168.10.20
```

Only after verifying key-based access and a recovery method should you consider a separately reviewed SSH-hardening change. This chapter deliberately does **not** disable password authentication automatically.

## 10. Troubleshooting without guessing

| Symptom | Safe first check |
| --- | --- |
| No network address | Ethernet link, DHCP service, interface shown by `ip -br address` |
| IP works, websites don't resolve | `resolvectl status` and `getent hosts ubuntu.com` |
| Server name doesn't resolve on another device | Router DNS registration or dedicated local DNS record |
| SSH connection refused | `systemctl status ssh` and listener/firewall configuration |
| SSH connection times out | Correct IP, subnet/routing, firewall and client network |
| SSH host-key warning | **Stop** and independently verify the server identity; do not delete known-host entries blindly |
| SSH works locally but not from LAN | UFW rule scope, host routing and network isolation |
| Clock is wrong | `timedatectl status`, NTP source and network reachability |

Avoid changing several settings at once. Record the failing test, change one thing, and test again.

## 11. Completion and handoff

Record the following in a **private, deployment-specific worksheet**:

- Hostname and server role
- Network interface and chosen address method (DHCP, reservation or planned static)
- IP, gateway, DNS and time-source configuration
- Whether SSH is installed, enabled and reachable
- Authorized SSH client(s) and host-key fingerprint
- Firewall status and permitted management sources
- Any outstanding problems and the console recovery path

Do **not** commit real passwords, SSH private keys, API tokens, VPN keys, or client-specific infrastructure details. Public examples should use placeholders and documentation-only addresses.

**Stage 3 passes when:** the intended network path works, name resolution and time are checked, and any requested remote administration works from an approved client **without losing console recovery**.

**Next:** Return to the [deployment roadmap](README.md) for Stage 4: storage identity and persistent mounts. Network shares should wait until the network baseline is reliable.

---

### Maintainer validation status

**Documentation-reviewed; runtime validation pending.** The steps above have not been demonstrated as a complete installation-and-SSH rehearsal in this project. Router menus, host interfaces, existing UFW policy, and SSH authentication behavior vary by deployment. Test in an isolated authorized environment before labeling this chapter fully verified.

References: [Ubuntu Server networking](https://documentation.ubuntu.com/server/how-to/networking/) · [Ubuntu OpenSSH](https://documentation.ubuntu.com/server/how-to/security/openssh-server/) · [Ubuntu firewall](https://documentation.ubuntu.com/server/how-to/security/firewalls/) · [Netplan](https://netplan.readthedocs.io/).
