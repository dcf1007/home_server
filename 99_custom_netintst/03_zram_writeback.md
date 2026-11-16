# 03 — Build the ZRAM writeback installer profile

**Build goal:** implement the source of an **optional, separately approved GPT-partition conversion** and ZSTD ZRAM writeback configuration **within Debian Installer**. The normal [05 — ZRAM guide](../05_zram_writeback/README.md) uses full Debian tools (`lsblk`, `wipefs`, `sgdisk`). This source recipe uses native udebs, BusyBox and `/proc`/`/sys` because the installer is much smaller.

**Safety:** writing the first 1 MiB of a partition permanently destroys its old signature and data in that area. This construction guide contains **source excerpts, not commands to run against the host disk**. Build and test using **throwaway VM disks only**.

## Step 1 — Register the profile and its prerequisite

In `simple-cdd.conf` offer `zram-writeback` but keep `auto_profiles=""` and `default_profiles=""`. Create its menu description `profiles/zram-writeback.description`.

The early `installer/ordered-selection.sh` must reject ZRAM unless `ensure-7x-kernel` was **independently selected**. The late module also checks that the kernel profile wrote its successful completion marker before touching a backing partition. **Never auto-select the kernel or choose a disk for the user.**

In `installer/run-selected.sh` the mapping is:

~~~sh
zram-writeback) module=zram; handler=profile_zram ;;
~~~

Create `profile_zram()` in `installer/profile-zram.sh` and keep the module sourced only by the selected dispatcher. Its `profiles/zram-writeback.postinst` verifies the success marker; it never repeats partition work.

## Step 2 — Stage every required source and data asset

Create `profiles/zram-writeback.extra` as in the actual project:

~~~text
installer/profile-zram.sh
installer/zram-selection.sh
scripts/zram-generator.conf.template
scripts/10-compressed-writeback.conf
scripts/zram-pressure.sh
scripts/zram-pressure.service
scripts/90-zram-swappiness.conf
~~~

These files land under `/cdrom/simple-cdd` on the ISO; they are **not** automatically run or installed when the profile is unselected.

The generator and monitoring files are the same design assets used by the normal Debian ZRAM how-to. Only the partition-selection and conversion mechanics are installer-specific.

## Step 3 — Include only official Debian Installer native packages

In the **build-only** `profiles/installer-media.udebs`, stage:

~~~text
parted-udeb
util-linux-udeb
~~~

They supply native `parted` and low-level `blkid` respectively. Keep this list in the **build-only** profile; adding a normal `parted` or `util-linux` `.deb` to `/target` would not make the command available to the running installer.

At the start of `profile_zram()`, verify the installed-target 7.x profile completion and required staged templates. If `parted` or `blkid` is absent in the installer, load their official udebs with `anna-install`; then check that their commands really exist.

The current source uses this pattern:

~~~sh
if ! command -v parted >/dev/null 2>&1; then
    capture anna-install parted-udeb ||
        fatal 'Could not load official parted-udeb into Debian Installer'
fi
~~~

The module performs the same absent-tool check for `blkid` and `util-linux-udeb`. It also checks that BusyBox supplies the required `dd` and `swapoff` applets. Failure stops **before** any partition modification.

## Step 4 — Create a separate native partition-selection helper

Write `installer/zram-selection.sh` with a few **sourceable functions**, then source it inside `profile_zram()`:

~~~sh
. "$MEDIA/zram-selection.sh"
~~~

This helper should define **standard partition-type GUIDs**, with comments making clear they are **types**, not disk-specific PARTUUIDs:

~~~sh
# Standard GPT partition type GUIDs, not device-specific PARTUUIDs.
ZRAM_SWAP_GUID=0657fd6d-a4ab-43c4-84e5-0933c84b4f4f
ZRAM_DATA_GUID=0fc63daf-8483-4772-8e79-3d69d8477de4
~~~

Use native `blkid -p -o export` to examine `PART_ENTRY_SCHEME`, `PART_ENTRY_TYPE`, `PART_ENTRY_UUID`, `PART_ENTRY_NUMBER` and the partition name. Use `/sys/class/block` to determine parent disk, partition number and size (reported in **512-byte sectors**). Read the parent disk's partition-table type and require **GPT**.

**Do not port the ordinary guide's `lsblk -o` calls into this minimal environment.** The current `util-linux-udeb` does not provide the full target-side `lsblk` or `wipefs` toolset.

## Step 5 — Build an explicit eligibility and selection routine

Create `zram_collect_candidates()` to enumerate block partitions and accept only:

- A GPT partition whose type is **Linux swap** and whose signature is swap;
- A previously prepared **Linux data** partition named `zram-writeback`, with no signature or an old swap signature.

Reject unreadable disks, missing GPT metadata, unknown sizes and duplicate PARTUUID identities. Require that `/target/etc/fstab` exists and the installed root is mounted as expected.

Create `zram_choose_candidate()` to read **only the new target's swap entries** from `fstab`. It may automatically resolve a candidate **only when exactly one eligible GPT swap partition matches exactly one swap reference**. If not, present Debian Installer's native `my-cdd/zram-backing-select` choice list.

For manual selection, show **device, size, partition class and PARTUUID**. The first choice must be `Stop without changing a partition`. Selecting a candidate is *not* destructive consent.

Create `zram_validate_candidate()` to resolve `/dev/disk/by-partuuid/<uuid>` to the expected device, re-read GPT identity, check minimum partition size **at least 1 MiB**, reject partition holders and mounted filesystems, and refuse duplicate identities. **Revalidate immediately before destructive actions**, not only when building the menu.

The tracked source uses:

~~~sh
[ "$zi_sectors" -ge 2048 ] ||
    fatal 'Selected backing is smaller than the required 1 MiB signature erase'
~~~

The number **2048** is 1 MiB expressed in 512-byte Linux block sectors; this is a minimum bound check on the **selected partition**, not its parent disk.

## Step 6 — Create a separate default-No destructive confirmation

In `installer/profile-confirm.templates` define a native `my-cdd/zram-destructive` boolean with `Default: false`. Before showing it, substitute the exact verified partition device, PARTUUID, size, parent disk and whether selection was automatic/manual.

The real profile calls:

~~~sh
yes_no my-cdd/zram-destructive ||
    fatal 'User declined destructive ZRAM backing conversion'
~~~

This question must explicitly explain the **1 MiB erase** and change to GPT Linux data type `8300` with partition name `zram-writeback`. A refusal must stop **without executing the erase**. Early profile checkbox consent is not enough.

## Step 7 — Implement memory-safe, targeted swap deactivation

Write `zram_read_active_swap()` using native `/proc/swaps`, whose used field is in **KiB**. Resolve the active swap path to the exact candidate rather than assuming the first swap entry.

If the selected partition has used swap:

1. Read `MemAvailable` and `MemTotal` from `/proc/meminfo`.
2. Require free RAM greater than the used swap plus **the greater of 256 MiB or one-eighth of total RAM**.
3. Display a **second default-No `my-cdd/zram-swapoff` confirmation**, including the device and currently used swap.
4. Revalidate device identity, used swap and available memory.
5. Call BusyBox `swapoff` on **only the verified partition**.

The actual destructive-adjacent source call is:

~~~sh
capture busybox swapoff "$device" ||
    fatal 'Targeted swapoff failed; GPT and signatures left unchanged'
~~~

**Never** use `swapoff -a`. If swapoff fails, do not proceed to GPT conversion. Confirm from `/proc/swaps` that the selected partition is inactive before any write. This RAM margin is a conservative preflight, **not a guarantee** that the kernel can successfully page out all swap.

## Step 8 — Prepare the target fstab change before writing

Build `zram_prepare_fstab()` to save a byte-for-byte copy of `/target/etc/fstab` and prepare a revised file **before** changing the partition.

Remove only a conventional swap entry proved to refer to the selected partition. Supported exact selectors include `UUID=`, `PARTUUID=`, `LABEL=` (only when it resolves uniquely) and explicit device paths. An ambiguous `PARTLABEL=` swap reference is rejected.

Keep all unrelated mount entries. The current design rejects another ordinary swap entry remaining in the installed target, rather than silently deactivating that other device. Check that `fstab` has not been changed elsewhere before using the revised file.

**Reason:** an old fstab swap line can reactivate the physical backing on the first boot, preventing exclusive ZRAM use.

## Step 9 — Write only the approved partition, then update its GPT entry

After all preceding validations, use the **installer-native BusyBox** command inside `profile_zram()`:

~~~sh
capture busybox dd if=/dev/zero of="$device" bs=4096 count=256 conv=notrunc,fsync ||
    fatal 'Could not erase swap signature from the confirmed backing partition'
~~~

**Meaning:** 256 blocks × 4096 bytes = **1 MiB**, starting from the beginning of **`$device`**, which was verified to be a partition. `conv=fsync` requests completion of the writes. This operation is destructive and **must never receive `$disk` as the output path**.

Do not use `sgdisk --zap-all` or `parted mklabel` here; those affect the whole parent GPT. Do not create a filesystem or delete/recreate the partition.

Then change the **existing partition's GPT entry** using native `parted`:

~~~sh
capture parted -s "$disk" type "$partn" "$ZRAM_DATA_GUID" ||
    fatal 'Could not change only the confirmed GPT partition type'
capture parted -s "$disk" name "$partn" zram-writeback ||
    fatal 'Could not set confirmed GPT PARTLABEL'
~~~

`$disk` is the parent disk; `$partn` is the selected partition number; the type GUID is standard Linux data (`8300` in gdisk terminology). This is **not** a hardcoded device-specific PARTUUID.

Re-read metadata and require correct type, name, unchanged PARTUUID, no signature, no mount and no active conventional swap. Holder checks are performed during pre-write candidate validation; the post-write code specifically rechecks mount and swap state. A failed check prevents provisioning. **The live Debian Installer's low-level `blkid` and `parted` sequence still needs VM validation.**

## Step 10 — Atomically install fstab and provision the target

Install the previously verified revised `fstab` through a temporary file on the target filesystem and an atomic rename. Recheck that no old reference to this partition remains as ordinary swap.

Show a complete reviewed target APT transaction for `systemd-zram-generator`; do **not** install the package silently. After approval, copy the staged design assets into `/target`:

- `/etc/systemd/zram-generator.conf` — replace **both** `YOUR_PARTUUID` placeholders with the dynamically probed partition's PARTUUID and verify no placeholder remains;
- `/etc/systemd/system/systemd-zram-setup@zram0.service.d/10-compressed-writeback.conf` — intended compressed writeback setup;
- `.../20-failure-emergency.conf` — `OnFailure=emergency.target` for ZRAM **setup** failure;
- `/usr/local/sbin/zram-pressure.sh` and `/etc/systemd/system/zram-pressure.service` — separately supervised pressure monitor;
- `/etc/sysctl.d/90-zram-swappiness.conf` — ZRAM-only swap policy.

Update target GRUB to include `zswap.enabled=0` without overwriting other kernel arguments. Enable the pressure-monitor service for first boot through the target `systemctl`. Recheck usable local root recovery. This is **configuration**; the installer cannot prove writeback works until the new system boots.

## Step 11 — Validate code and the real installer behavior

The two source modules are **POSIX shell**. From `my-cdd/`, check syntax only (this does not erase anything):

~~~sh
sh -n installer/profile-zram.sh
~~~

~~~sh
sh -n installer/zram-selection.sh
~~~

Build the image with `./build.sh`. On a **throwaway GPT VM disk**, test: no selection, missing 7.x prerequisite, ambiguous swap identity, wrong-device refusal, active swap/RAM margin, declined swapoff, declined destructive conversion, 1 MiB bounded erase, GPT type/name, PARTUUID, fstab, and first-boot ZRAM service/writeback behavior. The important steps remain **untested end to end**.

**Source:** [profile-zram.sh](my-cdd/installer/profile-zram.sh), [zram-selection.sh](my-cdd/installer/zram-selection.sh), [installer udeb media list](my-cdd/profiles/installer-media.udebs), and the staged [ZRAM assets](my-cdd/scripts/).
