# Stage 2: Install Ubuntu Server

**Goal:** Install Ubuntu Server 24.04 LTS on a dedicated, empty drive and confirm that it boots, connects to the network, and has a working administrator account.

**Who this is for:** Beginners setting up a desktop, mini PC, or disposable virtual machine as a homelab server.

> **Stop before installing if:** You want to keep Windows on the same drive, preserve files on the target disk, use RAID, or install onto an existing shared EFI partition. Those require a separate installation plan. **This guide assumes the target disk can be completely erased.**

## 1. Gather what you need

- A compatible 64-bit PC with a working power supply and ventilation, or an isolated UEFI virtual machine.
- A **dedicated, expendable installation drive**. For a practice VM, 2 virtual CPUs, 4 GB RAM, and a 32 GB virtual disk are reasonable starting points, not universal requirements.
- A monitor and keyboard for first setup, plus Ethernet where practical.
- A USB flash drive you can erase (physical PC only).
- A second computer for downloading Ubuntu and making the installer.
- Backups of anything important, stored somewhere other than the installation drive.

**Why:** The installer can erase an entire disk. A backup on that same disk is not protection.

### Checkpoint

- [ ] I have identified the exact computer or VM.
- [ ] I know which drive Ubuntu will erase.
- [ ] I have checked for important data and verified my backup.
- [ ] I have a way to access the machine locally if networking fails.

## 2. Download Ubuntu Server

1. Open the [official Ubuntu Server download page](https://ubuntu.com/download/server).
2. Choose **Ubuntu Server 24.04 LTS, 64-bit (amd64)**. Use the latest available 24.04 point-release image and record its filename.
3. Download the ISO and the matching checksum information from Canonical.
4. Follow Canonical's [ISO verification instructions](https://ubuntu.com/tutorials/how-to-verify-ubuntu). Authenticate the signed checksum list before trusting a hash comparison.

Once you have authenticated `SHA256SUMS`, you can check the downloaded ISO from the directory containing both files:

```bash
sha256sum --check --ignore-missing SHA256SUMS
```

**Expected:** The exact ISO filename reports `OK`. If verification fails, stop and download or verify the files again. A matching hash alone does not prove who published the checksum list.

## 3. Make the installation USB

**Physical computer:** Use the [official Ubuntu USB installation guidance](https://ubuntu.com/tutorials/create-a-usb-stick-on-ubuntu) or a reputable image-writing utility. Select the **USB flash drive**, not an internal SSD or media drive.

**Virtual machine:** Attach the ISO as a virtual DVD. You do not need a USB stick.

> **Warning:** Writing the installer erases the selected USB drive. Double-check its size and model before confirming.

## 4. Boot the installer

1. Connect the installer USB and Ethernet cable, if using them.
2. Power on the computer and open its temporary boot menu. The key varies by manufacturer.
3. Select the **UEFI** entry for your installer.
4. Choose the installer language and keyboard layout.
5. Select the standard Ubuntu Server installation option.
6. Confirm that networking works. DHCP is the simplest starting choice for a home lab.
7. Use the default package mirror unless your network requires another one.

Installer screens can change between point releases. Follow the labels shown on your machine rather than assuming every screenshot will match.

## 5. Choose the installation disk carefully

This is the most important decision in the entire installation.

1. Locate the **target disk** by its capacity, model, and connection details.
2. Compare it against the hardware inventory you made in Stage 1.
3. For this beginner guide, choose a **guided installation using the entire dedicated disk**. A simple non-LVM layout is fine when the installer offers it.
4. Read the proposed partition changes and confirm the EFI and Ubuntu partitions are on the intended disk.
5. **Stop** if any drive is unidentified, an unexpected partition is listed for deletion, or the plan affects a drive you want to keep.

**Never identify a disk by `/dev/sda` or `/dev/nvme0n1` alone.** Those names can differ between systems.

**Safer option:** With the computer powered off, temporarily disconnect non-target storage drives if that is practical and safe for your hardware.

Only approve the installer's final write confirmation when you are certain the target disk may be erased. There is no guaranteed undo after that point.

## 6. Create your administrator account

The installer will ask for a few details:

| Field | What to enter |
| --- | --- |
| Server name | A short, recognizable hostname, such as `homelab-server` |
| Username | Your own non-root administrator username |
| Password | A strong, unique password |
| SSH setup | Skip for this initial local-only baseline |
| Optional packages/snaps | Skip unless you have a specific need |

**Why skip extras?** First verify that Ubuntu works locally. We will configure remote access and applications in their own stages.

Finish installation. When prompted, remove the USB or detach the ISO, then reboot.

## 7. Log in and check the basics

Sign in with the username and password you just created.

Run these commands **one at a time**. They are checks, not installation or formatting commands.

### Confirm Ubuntu installed

```bash
cat /etc/os-release
```

Look for Ubuntu and `VERSION_ID="24.04"`.

### Confirm your username and administrator access

```bash
whoami
sudo -l
```

`whoami` should show your account. `sudo -l` may ask for your password and should list the commands your account is permitted to run.

### Check your network

```bash
ip -br address
ip route
```

Look for an IP address on your wired network interface and a default route if internet access is expected.

Then test connectivity and name resolution:

```bash
ping -c 3 1.1.1.1
getent hosts ubuntu.com
```

The ping checks IP connectivity to an external host, assuming your network permits ICMP. The `getent` command checks whether the system can resolve a name. A failed ping alone does not always mean the network is down.

### Check time synchronization

```bash
timedatectl status
```

Look for the correct time and a synchronized clock after the network has had time to settle.

### Check the installed drive

```bash
lsblk -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINTS
findmnt /
```

Verify that `/` (the root filesystem) is on the drive you intended to install Ubuntu on. If you see unexpected storage or mounting results, **stop before configuring additional drives**.

## 8. First-boot checklist

- [ ] Ubuntu starts without the installation USB.
- [ ] I can sign in using my own account.
- [ ] My account has the expected `sudo` access.
- [ ] My network has the expected IP configuration.
- [ ] Internet connectivity and DNS work, if required.
- [ ] The system time is correct.
- [ ] Ubuntu is installed on the intended drive.
- [ ] I have recorded any errors or warnings for later investigation.

If a check fails, fix that issue before moving on. Don't pile Docker and five other services on top of an installation that isn't working yet. Future-you deserves better.

## 9. If something goes wrong

| Problem | First thing to check |
| --- | --- |
| Installer starts again after reboot | Remove the installer USB and check UEFI boot order |
| Can't sign in | Confirm keyboard layout, username, and password |
| No IP address | Check Ethernet cable, link lights, and DHCP |
| IP works but names don't resolve | Check DNS configuration and network policy |
| Wrong disk or unexpected partitions | Stop further writes; compare with the original disk inventory |
| System clock is wrong | Check time settings, network access, and synchronization status |

**If the wrong disk may have been erased:** Stop using it. Do not reinstall, format, or attempt random repair commands. Preserve the disk and seek appropriate data-recovery help. Recovery is not guaranteed.

## 10. Record your baseline

Save a short private record of:

- Install date and Ubuntu ISO filename
- Computer model and **intended** OS drive
- Hostname and administrator username (never the password)
- Ubuntu version and kernel (`uname -r`)
- Network configuration and DNS results
- Root filesystem (`findmnt /`)
- Any unresolved problems

Keep serial numbers, credentials, internal network details, and raw logs out of public documentation unless deliberately sanitized.

**Next:** Return to the [deployment roadmap](README.md) for network identity, remote administration, persistent storage, and Docker. This chapter intentionally does **not** configure SSH, additional drives, or application containers.

---

### Maintainer notes: validation status

This is a simplified, documentation-reviewed guide adapted from the existing Stage 2 draft. The original draft recorded command-level review and some synthetic checks, **not a successful end-to-end Ubuntu installation**. The full install, boot-media verification, disk selection, and first-boot observations still require an authorized isolated test before the chapter can be marked runtime-validated.

References: [Ubuntu Server installation](https://ubuntu.com/server/docs/tutorial/basic-installation/) · [Ubuntu 24.04 release notes](https://documentation.ubuntu.com/release-notes/24.04/) · [Ubuntu release lifecycle](https://ubuntu.com/about/release-cycle) · [Validation matrix](../operations/validation-matrix.md).
