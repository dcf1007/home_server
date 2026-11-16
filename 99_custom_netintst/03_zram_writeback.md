# Netinst — ZRAM writeback: complete installer procedure

**Purpose:** convert one explicitly approved GPT swap partition into raw backing storage for **ZSTD-compressed ZRAM swap** on the newly installed Debian 13 system.

This is an **installer-specific implementation**, not an ordinary shell procedure. For a normal, already installed Debian server, use [05 — ZRAM writeback](../05_zram_writeback/README.md), which can use full `lsblk`, `wipefs` and `sgdisk`. The custom installer has a much smaller **udeb** environment.

**WARNING:** this workflow destroys the old swap signature and the first 1 MiB of the selected partition. It may affect another operating system using the same swap partition. Do not test it on valuable disks.

## Step 1 — Choose the feature and its explicit prerequisite

At the Simple-CDD selection screen, select **Ensure Linux 7.x kernel** and **ZRAM writeback**. You must choose both; the installer never selects the kernel on your behalf.

First, follow ordinary Debian Installer **Manual partitioning** and create or select a suitable GPT **swap partition**. It stays ordinary swap until this profile runs near the end of the installation.

The installer requires the **7.x image+headers profile to have completed successfully** before touching a backing partition. It also checks that the generator template and ZRAM selection files are available on the installation media.

## Step 2 — Load the native installer disk tools

A normal Debian system has the complete util-linux toolkit. Debian Installer generally does not. The ISO therefore stages:

- `parted-udeb` for editing the exact selected GPT entry;
- `util-linux-udeb` for native `blkid` probing;
- BusyBox for small native tools, including targeted `swapoff` and `dd`.

The profile loads missing official udebs with `anna-install`, checks required executable applets and refuses to operate if tools, `/proc`, `/sys` or PARTUUID links are missing. **It never copies full target-side util-linux executables into the installer.**

## Step 3 — Find possible backing partitions

The profile enumerates live partition devices under `/sys/class/block`, obtains size and parent-disk information, and asks native `blkid` about the **GPT** entries.

Eligible choices are limited to:

1. A GPT Linux **swap-type** partition that still identifies as swap; or
2. A previously converted Linux data-type partition named `zram-writeback`, with either no recognized signature or a residual swap signature.

It excludes non-GPT or unreadable partitions. It checks the target root really exists under `/target`, rejects duplicate selected PARTUUIDs, active mounts and device holders, and verifies the device really belongs to the expected GPT disk/partition number.

## Step 4 — Select the exact partition

If the target's freshly generated `/target/etc/fstab` contains **one** conventional swap reference resolving unambiguously to **one eligible swap partition**, the profile can identify it automatically.

Otherwise the native Debian Installer screen lists each eligible partition's **device, size, type and PARTUUID**. The first choice is **Stop without changing a partition**. Choosing an entry identifies a candidate; it is **not permission to destroy anything**.

Compare the displayed device and parent disk with what you chose in Partman. Do not approve a swap area shared with another OS unless you accept losing that conventional swap.

## Step 5 — Approve the destructive conversion separately

The next **default-No** confirmation displays:

- Exact partition device and current **PARTUUID**;
- Partition size and parent disk;
- Whether selection came from `fstab` or your manual choice;
- The proposed **1 MiB erase** and new GPT type/name.

If the information is wrong or unclear, select **No**. The program stops without performing the destructive conversion. Selecting **Yes** permits **only that exact partition**, subject to the remaining checks.

## Step 6 — Deactivate that partition's swap, only if necessary

The installer reads `/proc/swaps`. If the chosen partition contains **used swap**, it calculates how much RAM would be needed to move those pages out.

The required free-memory margin is the **used swap plus the greater of 256 MiB or one-eighth of total RAM**. If this is unavailable, it refuses conversion without calling `swapoff`.

If memory is sufficient, it displays a **second, independent default-No** prompt for deactivating **that exact partition**. After approval, the program rechecks the device and memory, calls the BusyBox `swapoff` applet **only on this partition**, and verifies that it is no longer active. Other swap devices are untouched; it never invokes `swapoff -a`.

If the chosen partition has no used swap, it still verifies that it is not active before conversion.

## Step 7 — Preserve the remaining target filesystem configuration

Before writing, the installer makes a snapshot of `/target/etc/fstab` and prepares a copy with **only the chosen partition's conventional swap entry removed**. It recognizes supported `UUID=`, `PARTUUID=`, `LABEL=` and exact device references only when they identify the chosen block device without ambiguity.

It does not accept an ambiguous `PARTLABEL=` reference and refuses a resulting target configuration containing **another independent ordinary swap entry**, as that would conflict with the intended ZRAM-only swap policy. It checks that `fstab` has not changed between approval and conversion.

## Step 8 — Erase the old signature and change its GPT type

**Only after all confirmations and validation pass**, the installer writes zeroes to the first **1 MiB of the selected partition**, never its whole parent disk:

~~~text
busybox dd if=/dev/zero of="$device" bs=4096 count=256 conv=notrunc,fsync
~~~

This line documents the internal operation; **you do not type it in Debian Installer**. The device variable is the verified selected partition.

The installer then changes **only that GPT entry** using native `parted`:

- New GPT **partition type**: Linux data, commonly called `8300`, GUID `0FC63DAF-8483-4772-8E79-3D69D8477DE4`;
- New **partition name**: `zram-writeback`.

These are standard **type identifiers**, not hardcoded device-specific UUIDs. No filesystem is formatted and no partition is deleted or recreated.

It immediately re-probes the partition to confirm its type, name, **original PARTUUID** (unchanged because the entry was not recreated), absence of a filesystem/swap signature and no mount or active swap. A failed check **stops further provisioning**.

## Step 9 — Install the generator and monitor in the target

After conversion succeeds, the prepared `fstab` is installed atomically; unrelated mount entries are preserved.

The installer displays and requests approval for the target `systemd-zram-generator` package transaction. It then copies the project's configuration and service files to `/target`, replacing **both** template `YOUR_PARTUUID` placeholders with the **actual verified PARTUUID**.

The installed files establish the intended ZSTD algorithm, backing device, resident limit, pressure monitor, `vm.swappiness=100`, compressed writeback configuration and **emergency mode on ZRAM setup failure**. The pressure monitor is enabled for first boot; its own failure should restart the monitor rather than force emergency mode.

The target GRUB default is adjusted to include `zswap.enabled=0` without replacing its other parameters; GRUB is regenerated. Finally the installer rechecks that the local **root password is usable** for emergency recovery.

## Step 10 — Verify after the first actual boot

The installer cannot demonstrate working writeback before boot. On a disposable VM after reboot, verify:

- `uname -r` starts with `7.` and matching headers exist;
- `swapon --show` lists `/dev/zram0`, **not** the physical backing partition as ordinary swap;
- the ZRAM setup and pressure-monitor systemd services work;
- `/sys/block/zram0/compressed_writeback` is available and enabled;
- backing-device counters change under **controlled** memory pressure;
- an intentionally broken setup enters emergency mode and the monitor can restart safely.

**Unverified:** the live Trixie installer `blkid -p` data flow, BusyBox erase, GPT changes, generator startup and first-boot writeback. A successful ISO build **does not** close these tests.

See [08 — Validation](08_validation_and_pending.md). The exact implementation is available in [profile-zram.sh](my-cdd/installer/profile-zram.sh) and [zram-selection.sh](my-cdd/installer/zram-selection.sh), **after** the procedure has been explained here.
