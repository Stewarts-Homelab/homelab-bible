# Ubuntu Server Foundation: Installation and First-Boot Verification

**Deployment & Operations Playbook · Batch 19 · Draft · November 15, 2026**

**Scope:** Ubuntu Server **24.04 LTS (Noble Numbat), amd64**, on a dedicated empty disk or an isolated UEFI VM with one expendable virtual disk. Use the currently published 24.04 LTS point-release image from Canonical and record its exact filename. Canonical lists standard security maintenance for the release through May 2029. Package coverage and extended support vary, so verify the release and package lifecycle for your deployment. This is a documentation-reviewed procedure. A complete installation remains runtime-pending. Batch 20 found no suitable UEFI VM. Use the rehearsal worksheet (private research record) to collect actual results before marking the procedure tested. [Ubuntu Server release notes](https://documentation.ubuntu.com/release-notes/24.04/) · [Ubuntu release lifecycle](https://ubuntu.com/about/release-cycle)

## 1. Preflight and installation media

- **Hardware:** Confirm x86-64 support, UEFI boot, working local console and wired Ethernet where practical. For a minimal rehearsal, use a suggested 2 vCPU, 4 GiB RAM and 32 GiB expendable virtual disk. These are pilot sizing choices. Size the actual machine for the intended workloads. Keep media disks separate from this foundation install.
- **Recovery:** Back up important data and verify that a sample can be read from another device. Record the existing boot order, disk inventory and a recovery contact or console path. For a VM, use new expendable storage, with a checkpoint where supported. Never attach the real media drives to a test VM.
- **Intended disk:** Write down model, capacity, connection/slot and serial or other stable identifier from trusted inventory or firmware. Ensure the installer offers enough information to connect its displayed disk to that inventory. Identical disks with ambiguous identity are a stop condition. For dedicated installs, disconnect non-target data or OS disks while powered off if you can do so safely. Preserve confirmed backups even if you disconnect other disks.
- **Network choices:** Use an approved network with DHCP for this pilot. Record expected address range, gateway and resolver. Settle any approved static plan with the network owner before attempting it. Internet access may be needed to obtain media or updates. An explicitly offline install is acceptable only when later verification and updates have an agreed path.
- **Media:** Download the matching Ubuntu Server ISO and checksum files from Canonical. Follow the official verification guide to authenticate signed checksums using a trusted Ubuntu signing key. Then verify the intended ISO against that authenticated file. If writing a physical USB, use Canonical's boot-media guidance and identify the expendable USB by model and capacity. Writing the installer erases the selected USB. Recheck the device immediately before confirming. A VM can attach the ISO directly. [Ubuntu Server installation](https://ubuntu.com/server/docs/tutorial/basic-installation/) · [Verify Ubuntu media](https://ubuntu.com/tutorials/how-to-verify-ubuntu)

On the **preparation system**, from the folder containing the authenticated checksum list and the single intended ISO, run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```

Need GNU coreutils and read access, normally no elevation. This checks bytes and does not establish signer identity. Require exit 0 and an OK result bearing the **exact ISO filename**. Exit 1, FAILED, missing listing, or an unexpected file means stop and verify the source or download again. Ignore-missing permits other images listed in the manifest to be absent. Batch 19 reproduced OK/exit 0 and mismatch/exit 1 on synthetic files with coreutils 9.7. Canonical signing and USB boot remain untested here.

## 2. Installer steps · Actions before first boot

1. **Boot the installer in UEFI mode.** Use the temporary boot menu and choose the UEFI entry for the known USB or virtual DVD. Preserve the existing firmware boot policy. If the device will only boot in legacy mode, pause and verify media and firmware compatibility. Stay at the console so you can recover from a boot or network mistake.
2. **Confirm install context.** Select language, keyboard and the standard Ubuntu Server option where offered. Verify that the Ethernet interface receives the expected network settings. Use the approved proxy or mirror only if required. Record any offline or update choices. Screens and defaults can differ by installer version.
3. **Identify the install disk and proposed layout.** Guided whole-disk installation is appropriate *only* for the confirmed dedicated expendable disk. For this baseline choose simple guided storage without LVM if offered and suitable. Confirm the summary shows root on the intended disk and any required EFI partition on that same dedicated disk. If encryption or a different layout is required, plan and validate recovery first. Shared EFI, dual boot, RAID and existing data preservation are separate installation designs.
4. **Apply the disk safety gate.** Before partition deletion, format, filesystem creation, or the final installer write confirmation, match every proposed target to the preflight inventory. Stop if any disk is unidentified, the target might contain data, an unexpected disk/partition appears, the EFI destination is unclear, or the write plan differs from what you approved. Do not use a name like `/dev/sda` or `/dev/nvme0n1` alone. Cancel or go back before confirming. Installing Ubuntu can destroy data immediately after confirmation.
5. **Create the host identity and admin account.** Choose a unique hostname and a named local user with a strong password. Record the username and intended admin role without recording the password in the guide. Confirm the installer indicates the account will have administrator privileges. Keep local console access. Defer optional OpenSSH and other services to their own planned steps for this baseline.
6. **Finish and reboot.** Wait for the installer to report completion. Remove or detach installer media when prompted. Boot the intended disk, then sign in locally as the new account. If the installer returns, check removable media and UEFI boot order before reinstalling. After a successful login, run the ordered checks below. Do not configure storage, Docker, or remote access until the baseline passes.

**Recovery boundary:** Before writes, return to the installer or power down after exiting safely. If a destructive choice was already confirmed or the wrong disk may have been touched, stop further writes, preserve evidence, and seek recovery help. Do not rerun installation, format, or repair a suspected affected disk. Use verified independent backups or a disposable VM checkpoint where applicable. Partition deletion and formatting have no guaranteed rollback.

## 3. Shell commands · First successful login

Run the checks in order from the **installed system**, using the local account. Replace the reserved example `check.lab.test` with a controlled hostname expected to resolve on the approved network. If none exists, record DNS runtime as pending. Output examples are expectations, with no live host values embedded.

```bash
cat /etc/os-release
uname -r
test -d /sys/firmware/efi
hostnamectl --static
id
sudo -l
ip -br address show
ip route show default
ip -6 route show default
resolvectl status
getent hosts check.lab.test
timedatectl status
lsblk -o NAME,TYPE,SIZE,MODEL,FSTYPE,MOUNTPOINTS
findmnt --mountpoint / -o TARGET,SOURCE,FSTYPE,OPTIONS
findmnt --mountpoint /boot/efi -o TARGET,SOURCE,FSTYPE
journalctl -b -p warning --no-pager -n 30
```

**QA labels:** **R** means exact command shell syntax checked and behavior documentation-reviewed. It still needs an Ubuntu first-boot run. **F** means an earlier disposable fixture validated the described mechanism only. **B** means a related runtime check was previously blocked in Work mode. Regular user applies unless stated. **Read** queries local state. **Lookup** can send DNS traffic. **Auth** may prompt, update the sudo credential cache, and log the attempt. None of these commands installs anything or changes host configuration.

| Command above | Purpose / access | Expected observation | Common failure and next safe action | Class / QA |
| --- | --- | --- | --- | --- |
| `cat /etc/os-release` | Read OS identity. coreutils and readable file. | Ubuntu and VERSION_ID 24.04. | Another release or installer environment → confirm boot media and target. | Read / R |
| `uname -r` | Record current kernel. coreutils. | A nonempty kernel version to capture verbatim. | Unexpected kernel → compare image/boot history before changing packages. | Read / R |
| EFI directory test | Check Linux boot context. Shell and visible sysfs. | Exit 0, no output in the intended UEFI boot. | Exit 1 in a native boot → check firmware boot entry. Within a restricted environment the result is inconclusive. | Read / R |
| `hostnamectl --static` | Read static hostname. systemd and accessible host service. | Planned hostname. | Wrong name or unavailable bus → check the install context before editing. | Read / R |
| `id` | Confirm current username and groups. coreutils. | Intended named account. | Wrong account → log in locally as the planned user and review installer record. | Read / R |
| `sudo -l` | List permitted commands for this user. sudo and authorized credentials. | Expected administrative permissions; policy may prompt for password. | Denied or less access than expected → keep console, confirm account and policy through an authorized admin. | Auth / R |
| `ip -br address show` | Check interface and addresses. iproute2, netlink. | Expected Ethernet link and a usable address for the plan. | Missing address, only loopback or permission denial → distinguish cable/DHCP from the diagnostic access limit. | Read / R, related B |
| Both default-route checks | Check IPv4 and IPv6 main-table defaults separately. iproute2/netlink. | Gateway on expected interface for each deployed family. | Missing required route → check lease and intended network. No IPv6 default can be expected on an IPv4-only lab. | Read / R, related B |
| `resolvectl status` | See per-link DNS selection/configuration. systemd-resolved and bus access. | Expected resolver on the active link. | Unexpected DNS or missing service → inspect DHCP and actual resolver implementation. | Read / R |
| `getent hosts check.lab.test` | Exercise normal NSS resolution for a controlled name. glibc tools and approved resolver access. | Expected address from the client's configured name-resolution policy. | Empty or wrong result → compare NSS with direct DNS using the DNS chapter. A hosts-file answer alone does not verify DNS. | Lookup / R, F for prior hosts-file fixture |
| `timedatectl status` | Check current time, zone and synchronization. systemd/time services and bus. | Correct time and eventual sync where network time is intended. | Unsynced or wrong time → record state, then check network/time source and policy. Avoid assuming a display-zone difference is clock drift. | Read / R |
| `lsblk -o …` | Inventory devices, filesystem and active mounts. util-linux and visible block information. | Intended OS disk, partitions and mountpoints. | Missing disk or changed device label → compare stable inventory and boot context before any write. | Read / R, B for guest inventory |
| Exact `findmnt` checks | Check root and EFI mounts. util-linux and readable mount table. | Planned root source and separate EFI mount on intended disk for this layout. | Unexpected root source or missing EFI → inspect the installer record and boot path. Pause all storage configuration. | Read / R, F for earlier mount fixtures |
| Bounded `journalctl` | Read recent warnings from this boot. systemd journal and approved read access. | Review warnings against known devices, interface and services. | Repeated I/O, boot or driver errors need investigation. An empty or restricted journal does not prove health. | Read / R, B for populated journal |

## 4. Gate and baseline record

Record the install date and time zone, ISO filename and verification result, installer choices, target identity (keep full serial private), firmware/boot mode, Ubuntu and kernel, account and authorization result, expected hostname/interface, address/route/DNS/time state, root/EFI sources and any warning excerpts. Capture selected output in authorized project notes. Avoid publishing identifiers, internal addresses, credentials or raw logs. Stop if root or EFI lands on an unexpected disk, the admin account is unusable, required networking fails, or there are unexplained storage errors. Proceed to the next roadmap stage only once the necessary checks pass.

**Historical context only:** An April 2026 copy of the earlier NAS guide records manual dual-boot partitioning and describes an existing SATA EFI. The March 21–22 capture records ext4 root and an NVMe EFI mount in its own snapshot. The records do not establish the same disk layout or final state. The HP record is a plan. Keep each separate from this dedicated-disk procedure. April guide, sections 13–14 (private research record) · March disk and fstab capture (private research record) · Replacement planning record (private research record)

**Reference and verification:** [Playbook index for networking, storage and logs](../operations/README.md) · [Command QA checklist](../operations/validation-matrix.md) · [Ubuntu Server installation](https://ubuntu.com/server/docs/tutorial/basic-installation/) · [systemd command manuals](https://www.freedesktop.org/software/systemd/man/latest/) · [util-linux findmnt](https://manpages.debian.org/trixie/util-linux/findmnt.8.en.html). The full sequence, media boot, disk gates, first boot and command outputs still need an isolated Ubuntu Server installation. No actual installation or live changes took place in Batch 19.
