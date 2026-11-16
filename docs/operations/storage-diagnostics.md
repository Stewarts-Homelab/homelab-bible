# Linux Storage, Mounts, and Free-Space Diagnostics: A Beginner's Guide

**Deployment & Operations Playbook · Standalone draft · Batch 14 · November 15, 2026**

Start here when a media path exists but the disk seems missing, a filesystem is nearly full, or two tools report different amounts of space. The commands are read-only. Work on an authorized Linux host and use paths as seen in the relevant **mount namespace**, the mount view available to a process. A container can see a different view from the host. The examples use GNU coreutils and util-linux.

## 1. Storage fundamentals

| Term | What it means |
| --- | --- |
| Physical disk and partition | The disk is the device. A partition is a defined region of a disk. Linux can also present virtual devices and use a filesystem on a whole disk. |
| Filesystem and directory | A filesystem organizes files and tracks allocation. A directory organizes names within it. The same directory path can expose a different filesystem after a mount. |
| Mount point | The exact path where the mounted source joins the directory tree. A directory may exist long before the mount is active. If the mount disappears, the directory can expose the underlying parent filesystem again. |
| Device name, UUID and label | A name such as `/dev/sdb1` is assigned by Linux and can change. Filesystem UUIDs normally persist across boots, but clones can duplicate them. A label is a human-readable identifier and can also be duplicated. A filesystem UUID differs from a partition UUID. Compare identity, size and expected layout together. |
| Internal, external and network storage | Internal and USB disks typically appear as local block devices. Network filesystems, such as NFS and SMB, may appear in the live mount table without a local disk in `lsblk`. For network storage, a client report need not explain the server's entire capacity or quotas. |
| Bind mount and Docker mapping | A Linux bind mount exposes an existing tree at another path without copying the tree. Docker can map a host directory with a bind or use a Docker-managed named volume. The host source and container destination answer different questions. |
| Capacity, free and available | Filesystem capacity covers the mounted filesystem. Free blocks may include blocks reserved for privileged or internal use. The `df` Available column reflects the space the filesystem reports as available for ordinary allocation. Quotas and other limits can affect individual writers. |
| Inode and hardlink | An inode identifies a filesystem object within one filesystem. Two hardlink paths share the same object and data. Two independent copies usually have different inodes even if their bytes match. A hardlink offers neither an independent copy nor a backup. |

## 2. Verify the mount before measuring usage

The following results are **synthetic**. In each row, use `--target` on the path the application actually opens and `--mountpoint` on the exact expected mount path. A configured row comes from fstab. A live row comes from the kernel mount view.

| Situation | Example observation | What it establishes |
| --- | --- | --- |
| Ordinary directory on root | `--target /mnt/media` returns `/ /dev/nvme0n1p1 ext4`. Exact `--mountpoint /mnt/media` gives no match. | The directory exists on root. Writing there would use root space. This example requires no writes. |
| Separate media mount | Both checks for `/mnt/media` return `/mnt/media /dev/sdb1 ext4`. | The path itself is mounted. Compare the source to the expected UUID and device identity. |
| Bind-mounted directory | Exact target is `/mnt/media`. A source may look like `/dev/sdb1[/library]`. Fstab records a source directory and `bind`. | The live source may display a backing filesystem or subtree. A whole-filesystem bind can look similar to a regular mount. Compare live rows and saved configuration before calling it a bind. |
| Configured but unmounted | `--fstab` lists `/mnt/media UUID=<media-uuid> ext4`. The exact live check has no match and `--target` returns `/`. | The planned source exists in configuration, but the expected mount is absent in this view. Leave writes paused and investigate the mismatch. |
| Nested mount | `--target /mnt/media` returns the media filesystem. `--target /mnt/media/archive` returns a distinct NFS mount at `/mnt/media/archive`. | The child path uses a separate filesystem. Results for the parent do not describe the child. |

**Why four checks?** `--target` finds the filesystem containing an existing path. `--mountpoint` checks the exact mount point. `--fstab` lists configured entries. `--verify` checks the mount table's usability and may warn about absent sources or paths. Neither fstab command activates a mount or proves one will succeed at reboot. [findmnt manual](https://manpages.debian.org/trixie/util-linux/findmnt.8.en.html)

## 3. Commands and how to read them

**F11** means Batch 11 disposable overlay/tmpfs or alternate-fstab fixture validation. **F14** means Batch 14 validation on disposable regular, hardlinked and sparse files or tmpfs. **S** means syntax and documentation reviewed with runtime validation pending for the stated invocation. Fixture paths differ from the examples. All command lines below were shell syntax checked. Historical commands are identified separately in the evidence table. [QA matrix](validation-matrix.md)

```bash
findmnt --target /mnt/media -o TARGET,SOURCE,FSTYPE,OPTIONS
findmnt --mountpoint /mnt/media -o TARGET,SOURCE,FSTYPE,OPTIONS
lsblk -o NAME,TYPE,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
df -hT -- /mnt/media
df -B1 -- /mnt/media
df -i -- /mnt/media
du -x -h --max-depth=1 -- /mnt/media
du -B1 -- /mnt/media/downloads/sample.mkv /mnt/media/movies/sample.mkv
du --apparent-size -B1 -- /mnt/media/downloads/sample.mkv /mnt/media/movies/sample.mkv
stat --format='dev=%d inode=%i links=%h bytes=%s blocks=%b block_unit=%B %n' -- /mnt/media/downloads/sample.mkv /mnt/media/movies/sample.mkv
findmnt --fstab -o TARGET,SOURCE,FSTYPE,OPTIONS
findmnt --verify --verbose
cat -- /etc/fstab
```

| Command from above | Why, prerequisites and privileges | Expected or concerning result and next safe step | Validation |
| --- | --- | --- | --- |
| `findmnt --target` | Locate the live filesystem containing the path. Needs util-linux and an accessible existing path. Normally regular user. | Example: target `/mnt/media`, source `/dev/sdb1`. If target is `/` or another unexpected parent, verify the exact mount before scanning or writing. A missing path can return no match. | F11 |
| `findmnt --mountpoint` | Check exact live mount status. Same utility and privileges. | Example: target `/mnt/media`, type `ext4`, options include `rw`. No match means the path is not an exact mount in this view. Compare containing filesystem, namespace and intended entry. Check stderr. | F11 |
| `lsblk` | Match disk and partition tree, filesystem type, UUID, label and mount paths. Needs visible block-device metadata; normally regular user, but some probing may require device access. | Example: `sdb disk 7.3T` with child `sdb1 part 7.3T ext4`. Parent filesystem fields can be blank. If inventory is empty or fields missing, check device visibility and the host view. Network mounts may have no block row. | S. Guest block and metadata behavior pending. |
| `df -hT` | Read type, capacity, used and available for the filesystem containing the path. Needs GNU coreutils and an accessible path. Regular user. | Example: ext4, 7.3T size and 200G available. If you see the root device or an unexpected type, return to the mount checks. | F11 |
| `df -B1` | Compare filesystem usage in byte-scale columns across timestamps. Same access. | Used and Available are separate columns. Compare Used for the same source and scope in two snapshots. Concurrent writes can change the result. | F11 |
| `df -i` | Read the filesystem's inode counters. Same access. | High inode use with free bytes can prevent creation of new files. Check whether the filesystem reports meaningful inode limits, then investigate directories with many small files. | F14 on tmpfs. No inode exhaustion induced. |
| `du -x -h --max-depth=1` | Estimate allocated usage by child directory on the same filesystem. Requires traversal/read access. Run only from a confirmed target. | Large child totals help narrow the search. Permission errors make totals incomplete. `-x` skips different filesystems, but a same-filesystem bind can still complicate traversal. Identify mount boundaries before interpreting totals. | F14 on sample directory. Nested network/bind behavior not runtime-tested. |
| `du -B1` | Show allocated usage for selected files in bytes. Requires accessible paths. | In one invocation, GNU `du` generally counts a hardlinked file once. A missing second line can reflect deduplication. Compare the paths with `stat`. | F14 |
| `du --apparent-size -B1` | Show logical lengths in bytes instead of allocated usage. Same access. | A sparse file may have a large logical length and few allocated blocks. GNU hardlink de-duplication still applies with these options. | F14 |
| `stat --format=...` | Read device number, inode, link count, logical bytes, allocated blocks and bytes per reported block. Accessible regular-file paths, no elevation ordinarily. | Same device plus inode for confirmed regular files identifies one file object. Confirm both paths and their mount view. Different inodes do not establish different contents. This command does not follow symlinks by default. Allocated bytes are reported blocks times block unit. | F14 |
| `findmnt --fstab` | Read planned mount entries. Needs readable fstab and util-linux. Normally regular user. | Expected target and UUID are present. Missing or unexpected entries call for comparing the dated baseline and live source. Keep UUIDs and private shares local. | F11 with alternate fixture table. |
| `findmnt --verify --verbose` | Validate fstab without mounting. Needs util-linux and readable table, paths and device metadata as applicable. Start as regular user. | A clean fixture returned exit 0. Check warnings, stderr and access limits on the host. A clean report does not establish a successful boot mount. | F11 with alternate fixture table. |
| `cat -- /etc/fstab` | Read literal entries and comments. GNU coreutils and file read access. Usually regular user. | Check source, target, type, mount options, dump and check-order fields. Compare a UUID or bind source to live evidence. Redact credentials, private share names and identifiers before sharing. | S for this exact invocation. Historical `cat /etc/fstab` appears in the March source. |

Filesystem type gives context for which checks apply. Options such as `ro` and `rw` describe read-only or read-write access at the mount level. A mount marked `rw` can still deny an application through permissions, quotas, or other policies. Any command reporting errors needs its output scoped to what it could inspect. [GNU df](https://www.gnu.org/software/coreutils/manual/html_node/df-invocation.html) · [GNU du](https://www.gnu.org/software/coreutils/manual/html_node/du-invocation.html) · [GNU stat](https://www.gnu.org/software/coreutils/manual/html_node/stat-invocation.html)

## 4. Why the numbers differ

- **Scope:** `df` asks the mounted filesystem about its blocks. `du` walks reachable directory entries and estimates use under the chosen path. Filesystem metadata, journals and reserved space can affect filesystem-wide accounting. Other directories and inaccessible paths can be outside the scan.
- **Deleted but open:** After a pathname is removed, a running process can keep the file open. The blocks can remain allocated until the last reference closes. A directory walk no longer sees that name. Seek process-level evidence before attributing a discrepancy to an open file.
- **Hardlinks:** Two names can represent one inode. Separate directory scans can each charge it, and one combined GNU `du` scan normally counts it once. Summed duplicate sizes do not equal space reclaimed. Deleting one link would leave the others pointing at the same data. This workflow makes no deletion recommendation.
- **Apparent versus allocated:** Sparse files contain logical ranges without corresponding allocated storage. Compression, shared extents, snapshots and filesystem-specific accounting can change the relationship further.
- **Inodes:** Free bytes alone do not ensure file creation. Filesystems with finite inode pools can exhaust their metadata entries first.

**Observed fixture result.** In Batch 14 on disposable tmpfs, two names showed equal device and inode, link count 2, logical length 16 bytes and 4,096 allocated bytes. A single allocated-size `du` call printed one hardlink entry. The synthetic sparse sample reported 1,048,576 logical bytes and zero allocated blocks. The fixture also returned inode totals. These observations validate the checks on that fixture only.

## 5. Dated homelab examples

| Date and evidence | Observation and limit |
| --- | --- |
| Mar 21 CDT / Mar 22 UTC, original inventory | Historical `cat /etc/fstab` and `lsblk` capture shows ext4 root and operations entries. The visible `sdd1` was the 8 TB HGST partition at `/mnt/media8tb`. The fstab entry configures ext4 by UUID and a bind from `/mnt/media8tb` to `/mnt/media`. The 4 TB WD `sdc1` appeared at `/mnt/backup4tb`, and the 500 GB WD `sda` backed `/mnt/ops`. The bind row establishes configured intent. No device names or assignments are generalized to a later boot. March capture, lines 8–16 and 40–54 (private research record) |
| March through September, dated project record | Early plans assigned downloads/seeding and temporary photo backup to the 4 TB drive. Later records describe putting downloads and imported media on the 8 TB drive with a common Docker `/data` mapping. Preserve these as dated role changes. The September candidate report contains 121 cross-tree groups and 27 download-only groups. The documented filesystem Used delta over a separate September conversion interval was 952.78 GiB. The two measurements have different scopes. Candidate inventory (private research record) · Timeline (private research record) |
| Oct 30–31, audit code and indexed output | The saved audit code supports path mapping and reads file metadata. Indexed Oct 31 output reports 101,542 files scanned and 18 file scan errors. The full JSON and CSV are missing. The October sum of sizes and single-link counts do not establish safe-to-remove files or filesystem space savings. Audit code (private research record) · Batch 05 evidence (private research record) |
| Nov 13–14, application logs | The Jellyfin log shows container paths such as `/tv` and `/movies`. That view does not resolve the host mount or prove the March bind alias was live in November. Seek matched host mount, capacity and Docker bind evidence. November Jellyfin capture (private research record) · Historical ledger (private research record) |
| November, replacement-server plan | The HP ProDesk plan uses an existing SSD, a 4 TB external drive and network access to the primary media storage. Installed drive identity, actual mount map and service migration still need direct evidence. Replacement-server plan (private research record) |

## 6. Walkthrough · The media path is nearly full

1. **Identify the intended target.** Record the client or container path, expected host path and expected device or remote share from a dated baseline.
2. **Check its backing filesystem.** Use the target lookup on the exact subdirectory involved. In the unmounted example, the result is root.
3. **Confirm the exact mount.** Check the expected parent mount separately. If the expected mount is missing, stop before scanning it as the media disk or making changes. Preserve the finding for a separately authorized response.
4. **Identify the source and filesystem.** Compare block tree, size, type and stable identity. For a network mount, use its source/type and the relevant client mount view.
5. **Check byte and inode capacity.** Read `df -hT`, `df -B1` and `df -i` on the confirmed path. Determine whether bytes, inodes or both are constrained.
6. **Narrow visible directory use.** Run the bounded `du` only on the verified target. Compare selected candidates with `stat`. Check stderr, nested mounts, aliases and scanned paths before comparing totals.
7. **Inspect mount configuration.** Compare the live results with fstab and verify messages. A managed automount or systemd mount can be defined elsewhere. Keep configuration and observation separate.
8. **Compare with the dated baseline.** Match the same filesystem and timestamp window. A path string, file-size sum or rounded use percentage on its own is insufficient.
9. **Record findings.** Capture date/time zone, host or namespace, target/source/type/options, available bytes and inodes, directory scan scope, relevant file identities and errors. Preserve uncertainty. Consider changes only after the location and likely cause are established.

**Quick reference:** `findmnt` answers where the path lives, `lsblk` describes local block storage, `df` measures the filesystem, `du` estimates visible directory or file allocation, and `stat` describes a specific file object. This chapter authorizes no partitioning, formatting, repair, remount, cleanup or fstab changes.
