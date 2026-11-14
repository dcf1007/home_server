# 03 — ZSTD ZRAM with compressed SSD writeback

**Scope:** optional, independently selectable Debian 13 installation profile. **Status:** documented design and source code, **not a deployed, validated or tested profile**. **Documentation revision:** 2026-11-14. **Provenance:** complete uploaded `zram_zstd_writeback_design(1).md` (included below), plus user-approved installation decisions made afterward.

> **Source fidelity:** Sections under **“Original design — complete source”** reproduce the uploaded design, including the complete generator configuration, Bash monitor, systemd units, commands, operating policy, limitations and upstream links. Its proposed kernel version and unit names are examples **not proofs that Debian 13 supplies these interfaces**. The later installation decisions in this introduction **supersede** any conflicting original operational assumptions.

## Installation-profile behavior (approved after the source document)

The source design describes setting up an existing system. The custom Debian installer must integrate it without silently making destructive choices:

1. **Explicit opt-in with an explicit kernel-profile dependency.** ZRAM starts **unchecked** and is independently selectable from Debian tweaks, OMV and Docker. **ZRAM requires the [Ensure 7.x kernel branch profile](09_ensure_7x_kernel.md).** If ZRAM is selected while Ensure 7.x is unchecked, prompt the user to **explicitly select Ensure 7.x or deselect ZRAM**. Never select Ensure 7.x or any other profile silently; do not require Debian tweaks.
2. **Ordinary interactive disk partitioning.** The user manually selects an OS disk and may create a **Linux swap partition** in the standard Debian partitioning screens. The example suggested size is **16 GB**, but the user may choose another and confirm it. The installer must never automatically select, create or resize the backing partition.
3. **One partition, two roles; approved GPT conversion.** With ZRAM **unchecked**, any user-created swap partition stays **conventional swap** (GPT type Linux swap). With ZRAM **selected**, the same user-confirmed partition becomes **raw, unformatted ZRAM writeback backing**: change its GPT type to **Linux filesystem (gdisk `8300`; GUID `0FC63DAF-8483-4772-8E79-3D69D8477DE4`)**, name it **`zram-writeback`** in the GPT partition-name field (**`PARTLABEL`**, *not* a filesystem `LABEL`), and remove existing swap/filesystem signatures after explicit confirmation. It must not be mounted, independently enabled by `swapon`, or listed for conventional swap activation in `/etc/fstab`. ZRAM uses the **confirmed `PARTUUID`**, not the descriptive `PARTLABEL`; record its actual capacity.
4. **ZRAM selected, no swap partition.** The ZRAM profile must interrupt configuration and ask the user to choose **return to manual partitioning and create a swap partition**, or **deselect ZRAM**. Do not silently continue with no backing partition or add a swapfile/another device. Debian Installer's own warning about having no swap does not replace this profile-specific check.
5. **Approved conversion timing — first ZRAM profile operation.** As soon as execution of the **explicitly selected ZRAM profile** begins, its **first operation** is to detect the manually user-created swap partition and positively establish its identity. **Immediately after detection and explicit confirmation of that exact partition and its destructive conversion**, change **only that partition**'s GPT type to `8300`, set the GPT name to `zram-writeback`, and remove old swap/filesystem signatures. This must happen **before any other ZRAM-specific provisioning**, such as generator files, ZRAM services or first-boot enablement; never perform the conversion during ordinary disk partitioning, when ZRAM is unchecked, or defer it to first boot. Inspect whether Debian Installer/partman already initialized, `mkswap`-formatted or activated the partition; verify no mounted/active swap or stale `/etc/fstab`/systemd swap reference survives. Do **not** re-create, resize, mount, `mkfs`-format or `mkswap`-format the physical backing. If there is no uniquely identified user-confirmed candidate, if swap is still active and safe deactivation cannot be demonstrated, or if partman timing prevents safe conversion, **stop immediately**, preserve diagnostics and request intervention; never proceed with a live swap device.
6. **Installer provisioning and first boot.** Before ZRAM setup, require the explicitly selected **Ensure 7.x kernel branch** profile to finish installing and validating the newest eligible Linux 7.x kernel and matching headers. If standard Debian repositories lack an eligible kernel, **Ensure 7.x** prompts the user to explicitly select the **Backports** profile; only Backports enables its repository at **default priority 100**, performs the user-reviewed installed-package upgrade and cleanup, and verifies success. After prerequisites are complete, ZRAM configures the generator, service drop-in and monitor for first boot, and validates `compressed_writeback`, resident-limit support, `writeback` and sysfs ordering on the actual target kernel.
7. **Critical initialization failure:** If the **ZRAM device fails to initialize**, **stop normal boot and enter systemd emergency mode**. A separate local root password must have been set interactively during installation for emergency recovery. The systemd dependency/failure mechanism implementing this must be tested; the service unit in the original source **does not alone establish this guarantee**.
8. **Monitor failure is different:** If the pressure monitor dies while ZRAM is correctly initialized, **log the error and restart the monitor**; **do not enter emergency mode merely for a monitor failure**.
9. **No silent fallback.** If a selected profile cannot satisfy critical dependency, generator, writeback, credential or boot-order checks, the installation must stop with diagnostics; do not substitute independent swap, disable ZRAM, change the memory policy or claim success without explicit approval.
10. **Approved ZRAM-only reclaim tuning:** Set `vm.swappiness=100` in a **dedicated** file `/etc/sysctl.d/90-zram-swappiness.conf` **only when ZRAM is selected**. Leave Debian's effective swappiness unchanged when ZRAM is not selected. The original source below describes this setting as optional; this subsequent decision explicitly approves it for the selected installation profile. Verify the effective value after first boot.

## Approved profile-start conversion sequence

**Decision recorded 2026-11-14:** **At the very start of the ZRAM profile execution**, after finding and positively identifying the manually created swap partition, perform the confirmed raw-backing conversion **immediately**. The separate Backports/Ensure 7.x profile dependencies must have finished (or been explicitly resolved) **before ZRAM begins**, but conversion is not postponed until other ZRAM configuration or first boot.

1. Enter the selected ZRAM profile; **first discover** candidate swap partitions and inspect GPT type, partitions, capacity, FSTYPE, PARTUUID, PARTLABEL, mount/active-swap state and the installer's selected OS disk/partition record. If no candidate is found, offer **return to partitioner** or **deselect ZRAM**; if multiple candidates exist or their identity is unclear, ask the user to identify one explicitly. **Never choose by order or guessed device path.**
2. Confirm the **exact target partition, its size/PARTUUID and that prior contents/signatures will be destroyed**. Detection alone is not permission to destroy data. If confirmation is declined, stop or allow deselection/partitioner navigation; leave data and partition metadata unchanged.
3. **Immediately upon confirmation**, verify it is not mounted or active as swap, and only if safe, convert the chosen partition to **generic Linux data GPT type 8300**, assign GPT **PARTLABEL `zram-writeback`**, and remove any old swap/filesystem signatures. If Debian Installer has activated swap, no automatic `swapoff` is authorized without established safety; stop if safe deactivation is uncertain. Never wipe an entire disk.
4. Re-read the partition table and signatures. Verify the **same partition's PARTUUID**, type/name, raw/unformatted state, absence of conventional swap activation and `fstab`/systemd swap references. If metadata changes caused a PARTUUID change, **reconfirm the identity** and use the actual resulting UUID; do not blindly reuse a stale identifier.
5. **Only after the conversion is validated** proceed with ZRAM generator/service/sysctl/monitor provisioning and first-boot readiness. A critical failure stops installation with diagnostics; no installer-managed rollback, backup or implicit conventional-swap fallback.

**Implementation still needs actual Debian Installer testing:** the ability to run this conversion at profile entry, partman stage ordering, safe handling of swap that partman may have already initialized/activated, and return-to-partitioner navigation have not been demonstrated. These are technical stop/release gates, not permission to change the approved timing.

## Approved raw GPT backing-partition representation

The installer still lets the user create the candidate partition through ordinary **manual Debian Installer partitioning**, as previously agreed. Only when **ZRAM** is explicitly selected and the user confirms the destructive role change:

| Property | Approved value |
|---|---|
| GPT type | **Linux filesystem (generic data)**, gdisk code **`8300`**, GUID **`0FC63DAF-8483-4772-8E79-3D69D8477DE4`** |
| GPT partition name / `PARTLABEL` | **`zram-writeback`** |
| `PARTUUID` | **Keep/record the actual confirmed partition UUID**; verify again after any partition-table writes; use for ZRAM configuration |
| Filesystem `FSTYPE` / filesystem `LABEL` / filesystem UUID | **None**; clear any old swap/filesystem signatures once safely inactive |
| Mount point, ordinary swap entry, `mkswap` on backing | **None**; absolutely no direct conventional swap activation |
| ZRAM device itself | **`/dev/zram0`** is the compressed RAM block device and **is** configured as a swap device by `systemd-zram-generator`, separately from raw backing |

**Why this type:** Linux swap GPT type `8200` (GUID `0657FD6D-A4AB-43C4-84E5-0933C84B4F4F`) is discoverable for automatic swap activation, so it is unsuitable after conversion. Other possibilities include **Linux reserved `8301`** (GUID `8DA63339-0007-60C0-C436-083AC8230908`), a less conventional special-purpose marker, or a custom GPT type GUID requiring more tooling. **`8300` is preferred** for standard Linux GPT tooling; its name does not force a filesystem, and generic data partitions do not receive automatic swap activation from `systemd-gpt-auto-generator`. Do not invent a new GUID.

**Partition name versus filesystem label:** `zram-writeback` is stored in the GPT as a **partition name**, visible as `PARTLABEL` (e.g. in `lsblk` or `blkid`). It is *not* a filesystem label; no `mkfs` or `mkswap` is performed on the backing. The GPT name is a human safety marker only: do **not** use it as the unique device selector, because names can be duplicated. The unique confirmed `PARTUUID` is used instead.

**How ZRAM uses it:** on the **installed system's first boot**, `systemd-zram-generator` configures ZRAM's `backing_dev` through `writeback-device = /dev/disk/by-partuuid/<confirmed-PARTUUID>` **before** `disksize` is finalized (subject to tested generator/device ordering). The selected kernel must support compressed writeback and all documented sysfs controls. The generated **`/dev/zram0`** virtual RAM device is formatted as **swap** and activated; the physical GPT backing partition is kept raw and used by the kernel only to receive ZRAM pages selected for writeback. The backing data is temporary, is not a mounted filesystem, and is **not a second independent swap device**.

**Conversion ordering and safeguards:** inspect `lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,PARTTYPE,PARTLABEL,PARTUUID,MOUNTPOINTS`, `swapon --show`, `wipefs`, generated target `/etc/fstab` and device dependencies; show the user the exact identity and that the partition will lose its prior contents. Obtain explicit confirmation before touching its GPT type/name or signatures. Verify that the candidate is **not active swap and not mounted**, that no other partition is being changed, and that the resulting type/name and recorded `PARTUUID` are correct. If the installer already activated swap, do not assume `swapoff` is safe; stop if its safe deactivation cannot be guaranteed. Remove swap signatures using a reviewed, partition-scoped mechanism (such as `wipefs`, not a full-disk wipe). Never target an entire disk for `wipefs`.

**Unselected ZRAM:** leave a user-created swap partition at normal Linux swap type, let Debian Installer format/use it normally, and **do not** rename it `zram-writeback` or alter its `PARTUUID`.

**Pre-implementation validation:** confirm partman hook timing, GPT manipulation tools, generator service ordering, and first-boot behavior on Debian 13/actual Linux 7.x packages. The original source section below remains verbatim.

References: [Discoverable Partitions Specification](https://wiki.freedesktop.org/www/Specifications/DiscoverablePartitionsSpec/); [Debian sgdisk manual](https://manpages.debian.org/trixie/gdisk/sgdisk.8.en.html); [Linux kernel ZRAM documentation](https://www.kernel.org/doc/html/latest/admin-guide/blockdev/zram.html); [zram-generator configuration documentation](https://github.com/systemd/zram-generator/blob/main/man/zram-generator.conf.md).

## Required profile: Ensure 7.x kernel branch

1. When ZRAM is selected, check whether the **[09 — Ensure 7.x kernel branch](09_ensure_7x_kernel.md)** profile was explicitly selected. If not, offer **select Ensure 7.x** or **deselect ZRAM**. Do not continue and never precheck it silently.
2. The Ensure 7.x profile queries ordinary signed Debian repositories for the newest eligible Linux **7.x** kernel and matching headers, using the moving kernel metapackages without fixed version locks.
3. **If ordinary repositories lack a suitable 7.x kernel**, Ensure 7.x, not ZRAM, asks for explicit selection of **[02 — Backports](02_backports_apt.md)** or deselection of the kernel-dependent profile.
4. Only the Backports profile activates `trixie-backports` at **Debian's built-in priority 100**, performs its complete reviewed upgrade of eligible installed packages, and performs its separately reviewed autoremove/purge cleanup. The Ensure 7.x profile then requests **only the necessary kernel-related packages** from Backports, preferring ordinary stable dependencies.
5. ZRAM starts configuration only after the selected kernel profile verifies the installed 7.x image, headers and boot configuration. The installed **target kernel**, not necessarily the running installer kernel, must expose required compressed-writeback and generator interfaces.
6. Kernel, Backports, ZRAM, Debian tweaks, Docker and OMV selection states remain independent. A missing prerequisite is an **interactive choice**, never permission for silent profile activation. On unresolved failure, stop with logs.

**Backports default-priority consequence:** installing Linux 7.x from Backports does **not** authorize a global preference for all backported packages. APT preference **900** was revoked in favor of **100**, and no priority-900 preferences file is installed. See [02 — Backports](02_backports_apt.md).

## Approved ZRAM-only sysctl configuration

During installation, **only if the ZRAM profile is selected**, create `/etc/sysctl.d/90-zram-swappiness.conf` with:

```ini
# Applied only by the independently selected ZRAM profile.
vm.swappiness = 100
```

Ensure the intended target system loads this setting on first boot. Confirm with `sysctl vm.swappiness` (expected `vm.swappiness = 100`). **If ZRAM is not selected**, do not create this file or otherwise override `vm.swappiness` as part of the ZRAM profile. Test both profile-selection paths; do not assume an existing local sysctl override is absent without inspecting it. The original uploaded source, reproduced below, remains unchanged.

## Deployment checklist specific to the customized installer

- [ ] Validate ZRAM with Debian tweaks unchecked, but **Ensure 7.x explicitly selected**. If Ensure 7.x is unchecked, ask to select it or deselect ZRAM. If the kernel profile cannot find an eligible 7.x from ordinary repositories, it must prompt for **explicit Backports selection** or cancellation. Confirm the Backports priority stays **100**, its reviewed upgrade and cleanup finish, and only kernel-related packages are explicitly requested from Backports.
- [ ] **At ZRAM profile entry, before other ZRAM-specific actions**, discover and positively identify the user-created swap partition; if absent or ambiguous, stop for explicit choice. Show identity, capacity, FSTYPE, PARTTYPE, PARTLABEL and PARTUUID and obtain **explicit confirmation**; then immediately convert only the selected partition to raw GPT type **8300** and GPT name **`zram-writeback`**.
- [ ] Verify the physical backing has **no filesystem or swap signature**, no mount, and no conventional swap activation; check GPT type **8300**, GPT name **`zram-writeback`**, and persistent **PARTUUID**. Ensure **no fstab, initramfs, systemd or installer-generated swap activation** re-enables it. `/dev/zram0` itself is the **only** activated swap device for this profile.
- [ ] Verify the backing path `/dev/disk/by-partuuid/<confirmed-PARTUUID>` exists at device setup time, and that `blockdev --getsize64` yields its actual byte capacity.
- [ ] Confirm the source's `set!backingBytes` expression, `zram-size` and `zram-resident-limit` are supported by the installed generator version and evaluate as intended; early generation may report zero temporarily.
- [ ] Verify the `compressed_writeback` sysfs switch is set **before** initializing `disksize`, and the service drop-in is effective (inspect `systemctl cat`).
- [ ] Ensure ZSTD compression is selected on first device initialization; disable `zswap` via `zswap.enabled=0`.
- [ ] When ZRAM is selected, create `/etc/sysctl.d/90-zram-swappiness.conf` with `vm.swappiness = 100` and verify it is effective on first boot. When unselected, neither create this file nor apply a ZRAM-specific swappiness override.
- [ ] Verify `writeback_limit_enable=0`, actual monitoring sysfs files, PSI parsing and one synchronous writeback pass at a time.
- [ ] Install the Bash monitor with mode 0755; verify `bash -n`; configure and enable its systemd service; test automatic restarts and logging.
- [ ] Validate two **distinct** service failure modes in disposable test environments: initialization failure enters emergency mode; monitor failure causes restart but permits ordinary boot.
- [ ] Verify no independent swap is active, backing writes/failed writes are observable, and documented memory/SSD write-exhaustion limits are understood.

**Do not interpret this checklist as executed.** Source-provided code appears below **unchanged**, for accurate implementation and review. It must not be run against a non-disposable partition or promoted to a production ISO before validation.

---

## Original design — complete source

The following is the **full uploaded** `zram_zstd_writeback_design(1).md`. It remains as written, including version-specific assertions, a reference to a disposable backing partition and the optional swappiness suggestion. The decisions above determine how it will eventually be incorporated into the selectable installer.

# Debian 7.2.12 — adaptive zram with compressed SSD writeback

**Goal:** Keep swapped pages ZSTD-compressed in RAM; write them to a dedicated SSD partition only when the kernel reports memory pressure **and** zram is relatively full. No zswap, VDO, recompression, writeback budget, custom kernel or additional daemon. Retain `systemd-zram-generator`; supervise one Bash monitor with systemd.

## 1. Policy

- **RAM-adaptive:** at boot, zram's physical-storage limit is `MemTotal / 2`; no hard-coded RAM size.
- **Backing-device-adaptive:** identify a dedicated partition by **PARTUUID** and measure its actual capacity. It must **not** also be active as ordinary swap or mounted.
- **Compression:** ZSTD from first swap-out; `compressed_writeback=yes` preserves compressed contents on disk, but each written entry still uses a page-sized backing slot.
- **Kernel reclaim:** unchanged; do not trigger swapping at a fixed percentage of occupied RAM.
- **Monitoring:** every **1 second**, read `/proc/pressure/memory` and `/sys/block/zram0/mm_stat`. These are virtual kernel files, not SSD reads.
- **Normal writeback:** zram at least **80%** of its resident limit **and** PSI `some avg10` at least **5%**.
- **Escalation:** one complete writeback pass at a time, from 24 h → 6 h → 1 h → 5 min → 1 min since last zram access; re-evaluate after each pass.
- **Stop further passes:** if zram falls below **70%**, or PSI falls below **5%** (unless the emergency condition applies).
- **Emergency:** at **95%** of the zram limit, permit writeback without the PSI condition and finally broaden selection to all remaining resident entries.
- **No `writeback_limit`:** a pass may overshoot the target and may generate substantial disk I/O. Existing pages are age-*eligible*, not strictly sorted oldest-first.

All thresholds are initial policy choices, **not** Debian defaults. This is a best-effort userspace policy; it cannot guarantee preventing swap-write failure during abrupt memory pressure.

## 2. Inspect the system first

```bash
uname -r
systemctl cat systemd-zram-setup@zram0.service
lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,PARTUUID,MOUNTPOINTS
swapon --show
```

Select a **disposable** backing partition and replace `YOUR_PARTUUID` everywhere below. Its previous data will not be preserved. Remove its independent swap entry from `/etc/fstab` **before** rebooting into this design. Do not casually run `swapoff` while RAM is already under pressure.

## 3. Keep `systemd-zram-generator`

`/etc/systemd/zram-generator.conf`:

```ini
# Early unit generation may precede creation of the PARTUUID symlink.
# The generator re-reads the configuration during device setup.
set!backingBytes = /usr/sbin/blockdev --getsize64 /dev/disk/by-partuuid/YOUR_PARTUUID 2>/dev/null || echo 0

[zram0]
zram-size = ram + backingBytes / 1048576
zram-resident-limit = ram / 2
compression-algorithm = zstd
writeback-device = /dev/disk/by-partuuid/YOUR_PARTUUID
swap-priority = 100
```

`ram` is in MiB; `blockdev` reports bytes. The chosen **logical** zram size is approximately RAM plus measured backing capacity. This is a planning value, **not a guarantee** that compression and backing space can populate every logical slot. The command returning zero during early unit generation is provisional: **verify the actual size after boot**. The second evaluation and backing-device dependency were checked in upstream `zram-generator` **v1.2.1**; verify your installed Debian package supports them.

To enable compressed writeback **before** the generator initializes `disksize`, create:

`/etc/systemd/system/systemd-zram-setup@zram0.service.d/10-compressed-writeback.conf`

```ini
[Service]
ExecStartPre=/bin/sh -c 'echo yes > /sys/block/zram0/compressed_writeback'
```

The generator still handles zram initialization, swap formatting, startup and teardown. Set the kernel boot argument `zswap.enabled=0`. Optionally start with `vm.swappiness=100` in `/etc/sysctl.d/90-memory.conf` and tune only after measurements.

## 4. Complete Bash monitor

`/usr/local/sbin/zram-pressure.sh`:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

Z=/sys/block/zram0
POLL=1
START=80
TARGET=70
EMERGENCY=95
PSI_MIN=500                  # 5.00% as hundredths of a percent
AGES=(86400 21600 3600 300 60)

state() {
    local kind avg whole fraction
    read -r _ _ used limit _ < "$Z/mm_stat" || return 1
    (( limit > 0 )) || return 1
    read -r kind avg _ < /proc/pressure/memory || return 1
    [[ $kind == some && $avg =~ ^avg10=([0-9]+)\.([0-9]{2})$ ]] || return 1
    whole=${BASH_REMATCH[1]}
    fraction=${BASH_REMATCH[2]}
    psi=$(( 10#$whole * 100 + 10#$fraction ))
    occupancy=$(( used * 100 / limit ))
}

for name in mm_stat idle writeback bd_stat compressed_writeback writeback_limit_enable; do
    [[ -e $Z/$name ]] || { echo "Missing $Z/$name" >&2; exit 1; }
done
read -r value < "$Z/compressed_writeback"
[[ $value == 1 ]] || { echo 'Compressed writeback is not enabled' >&2; exit 1; }
read -r value < "$Z/writeback_limit_enable"
[[ $value == 0 ]] || { echo 'Disable writeback_limit before starting' >&2; exit 1; }

while :; do
    state || { echo 'Cannot read PSI/zram state' >&2; exit 1; }
    if (( occupancy < EMERGENCY && (occupancy < START || psi < PSI_MIN) )); then
        sleep "$POLL"
        continue
    fi

    echo "Writeback triggered: zram=${occupancy}% PSI=${psi}bp"
    read -r _ _ before < "$Z/bd_stat"
    failed=0

    for age in "${AGES[@]}"; do
        state || exit 1
        # Once started, continue only while pressure + insufficient
        # headroom persist, or the emergency threshold is reached.
        if (( occupancy < EMERGENCY && (occupancy < TARGET || psi < PSI_MIN) )); then
            break
        fi
        if ! printf '%s\n' "$age" > "$Z/idle" ||
           ! printf '%s\n' 'type=idle' > "$Z/writeback"; then
            echo "Writeback failed for age=${age}s" >&2
            failed=1
            break
        fi
        echo "Writeback completed: age=${age}s"
    done

    state || exit 1
    if (( failed == 0 && occupancy >= EMERGENCY )); then
        echo 'Emergency writeback: all remaining eligible entries'
        if ! printf '%s\n' all > "$Z/idle" ||
           ! printf '%s\n' 'type=idle' > "$Z/writeback"; then
            echo 'Emergency writeback failed' >&2
            failed=1
        fi
    fi

    read -r _ _ after < "$Z/bd_stat"
    echo "Cycle complete; backing writes delta=$((after - before))"
    if (( failed || after == before )); then
        sleep 30                 # Avoid rapid retries on full/ineffective backing
    else
        sleep "$POLL"
    fi
done
```

**The actual writeback is** `printf 'type=idle\n' > "$Z/writeback"`. The sysfs operation completes before Bash moves to the next pass. No process is forked to supervise individual writes. The service checks conditions **between** passes, not during one.

## 5. systemd supervision

`/etc/systemd/system/zram-pressure.service`:

```ini
[Unit]
Description=Pressure-triggered zram writeback
BindsTo=dev-zram0.swap
After=dev-zram0.swap

[Service]
Type=exec
ExecStart=/usr/local/sbin/zram-pressure.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

After confirming the PARTUUID, backing-device ownership and installed generator version:

```bash
sudo chmod 755 /usr/local/sbin/zram-pressure.sh
sudo bash -n /usr/local/sbin/zram-pressure.sh
sudo systemctl daemon-reload
sudo systemctl enable zram-pressure.service
# Reboot in a controlled maintenance window; do not reset active zram.
```

## 6. Verify after boot

```bash
systemctl status dev-zram0.swap zram-pressure.service
swapon --show                       # Only /dev/zram0 should own this swap hierarchy
zramctl
cat /sys/block/zram0/compressed_writeback  # Expect 1
cat /sys/block/zram0/backing_dev
cat /sys/block/zram0/disksize        # Confirm measured backing size was included
cat /sys/block/zram0/mm_stat
cat /sys/block/zram0/bd_stat         # Third field: cumulative backing writes (4 KiB units)
cat /sys/block/zram0/io_stat        # Monitor failed_writes
cat /proc/pressure/memory
journalctl -b -u systemd-zram-setup@zram0.service -u zram-pressure.service
```

**Limitations:** This approach does not provide a kernel-native pressure-to-writeback trigger. A one-second Bash monitor is low-overhead but cannot intercept reclaim synchronously. `compressed_writeback=yes` does **not** pack several compressed entries into one SSD block or reduce host-write size per entry. An unrestricted `type=idle` pass can write much more than strictly necessary. Backing exhaustion and sudden memory pressure remain possible.

## Sources

- [Linux 7.2 zram interfaces](https://docs.kernel.org/7.2/admin-guide/blockdev/zram.html)
- [Linux PSI semantics](https://docs.kernel.org/accounting/psi.html)
- [Debian zram-generator configuration](https://manpages.debian.org/unstable/systemd-zram-generator/zram-generator.conf.5.en.html)
- [Upstream zram-generator v1.2.1 source](https://github.com/systemd/zram-generator/tree/v1.2.1/src)
- [Linux v7.2.12 zram driver](https://github.com/gregkh/linux/blob/v7.2.12/drivers/block/zram/zram_drv.c)
