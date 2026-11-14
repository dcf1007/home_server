# 03 — ZSTD ZRAM with compressed SSD writeback

**Scope:** optional, independently selectable Debian 13 installation profile. **Status:** documented design and source code, **not a deployed, validated or tested profile**. **Documentation revision:** 2026-11-14. **Provenance:** complete uploaded `zram_zstd_writeback_design(1).md` (included below), plus user-approved installation decisions made afterward.

> **Source fidelity:** Sections under **“Original design — complete source”** reproduce the uploaded design, including the complete generator configuration, Bash monitor, systemd units, commands, operating policy, limitations and upstream links. Its proposed kernel version and unit names are examples **not proofs that Debian 13 supplies these interfaces**. The later installation decisions in this introduction **supersede** any conflicting original operational assumptions.

## Installation-profile behavior (approved after the source document)

The source design describes setting up an existing system. The custom Debian installer must integrate it without silently making destructive choices:

1. **Explicit opt-in with an explicit prerequisite.** The ZRAM profile starts **unchecked** and is a separate option from **Debian tweaks**, **OMV** and **Docker**. ZRAM implementation remains entirely in this profile, but the user **must also explicitly select Debian tweaks**. If ZRAM is selected while Debian tweaks is unchecked, ask the user to **select Debian tweaks as well** or **deselect ZRAM**. Never silently enable Debian tweaks, never install ZRAM alone and require confirmation of the final selection.
2. **Ordinary interactive disk partitioning.** The user manually selects an OS disk and may create a **Linux swap partition** in the standard Debian partitioning screens. The example suggested size is **16 GB**, but the user may choose another and confirm it. The installer must never automatically select, create or resize the backing partition.
3. **One partition, two roles.** With the ZRAM profile **unchecked**, any user-created swap partition stays **conventional swap**. With ZRAM **selected**, the **same user-created partition** is re-purposed as **exclusive raw ZRAM compressed-writeback backing**; it must not be mounted, enabled by `swapon`, or listed for conventional swap activation in the installed system's `/etc/fstab`. The installer records the confirmed **PARTUUID** and the exact measured byte capacity.
4. **ZRAM selected, no swap partition.** The ZRAM profile must interrupt configuration and ask the user to choose **return to manual partitioning and create a swap partition**, or **deselect ZRAM**. Do not silently continue with no backing partition or add a swapfile/another device. Debian Installer's own warning about having no swap does not replace this profile-specific check.
5. **Partman integration is an open implementation requirement.** Validate whether Debian Installer has initialized, formatted or activated the partition before the profile stage. Avoid double activation and stale fstab entries. If safe conversion and navigation cannot be guaranteed, **stop for manual intervention**; do not assume a generator running later makes the partition safe.
6. **Installer provisioning and first boot.** Require and install the **newest currently available compatible kernel from the Linux 7.x major branch**, plus corresponding headers, prior to the first reboot. Check ordinary signed Debian 13 repositories first; if they offer no eligible 7.x kernel, explicitly require **enabling `trixie-backports`**, obtain user confirmation and verify APT metadata/candidates. Do **not** pin a fixed kernel version or package filename: use the version-tracking `linux-image-amd64` and `linux-headers-amd64` metapackages when their resolved candidates are 7.x, and verify package version, dependencies, boot entry and headers match. Do not automatically enable a separate **installer profile**. After enabling backports, complete the **explicitly approved full-system package upgrade checkpoint** defined below before proceeding with ZRAM. Then install/configure generator, service drop-in and monitor to initialize on the installed system's first boot; validate `compressed_writeback`, resident-limit support, `writeback` and other sysfs interfaces on the **actual installed kernel and Debian packages**.
7. **Critical initialization failure:** If the **ZRAM device fails to initialize**, **stop normal boot and enter systemd emergency mode**. A separate local root password must have been set interactively during installation for emergency recovery. The systemd dependency/failure mechanism implementing this must be tested; the service unit in the original source **does not alone establish this guarantee**.
8. **Monitor failure is different:** If the pressure monitor dies while ZRAM is correctly initialized, **log the error and restart the monitor**; **do not enter emergency mode merely for a monitor failure**.
9. **No silent fallback.** If a selected profile cannot satisfy critical dependency, generator, writeback, credential or boot-order checks, the installation must stop with diagnostics; do not substitute independent swap, disable ZRAM, change the memory policy or claim success without explicit approval.
10. **Approved ZRAM-only reclaim tuning:** Set `vm.swappiness=100` in a **dedicated** file `/etc/sysctl.d/90-zram-swappiness.conf` **only when ZRAM is selected**. Leave Debian's effective swappiness unchanged when ZRAM is not selected. The original source below describes this setting as optional; this subsequent decision explicitly approves it for the selected installation profile. Verify the effective value after first boot.

## Kernel 7.x and backports prerequisite — latest eligible version, never fixed

1. Refresh signed Debian 13 stable, updates and security repository metadata; inspect `apt-cache policy linux-image-amd64 linux-headers-amd64`. Check whether an eligible **Linux major version 7** image, with matching headers, can be installed from those standard repositories.
2. If not, **ask the user to enable `trixie-backports`** (or verify that it is already enabled); never silently alter repository policy or select another installer profile. If consent is refused or a verified 7.x candidate is absent, **stop** the selected ZRAM profile and request manual intervention or deselection.
3. Resolve the **newest available eligible 7.x candidate** from currently configured signed repositories, including any backports candidate, under the *approved effective APT policy*. Use moving metapackages `linux-image-amd64` and `linux-headers-amd64`, not a hardcoded package such as `linux-image-7.2.12...`, and ensure they actually select a 7.x image and corresponding headers. Do not introduce package version holds, APT version locks or a kernel-specific pin.
4. **Immediately after enabling backports**, refresh indexes, simulate the complete upgrade transaction, show its package version changes, proposed installations and removals, request **explicit user confirmation**, then apply the upgrade. This **one-time installation checkpoint is approved only as an interactive, reviewed action**, not permission to enable unattended upgrades afterward. Keep the system-upgrade requirement separate from mere `apt update`, which only refreshes package lists.
5. Before proceeding with ZRAM, verify the upgrade completed successfully, the package database is consistent and **no installed package remains eligible for upgrade under the approved repository/pinning policy**. If package removals, dependency conflicts, held packages or unupgradable candidates prevent this, **stop and request further approval**; never force-remove packages or silently skip pending upgrades. The exact removal approval policy remains a consequential installation choice.
6. Confirm the installed boot default will use the newest eligible 7.x kernel and that required compressed-writeback features actually work. Do not claim a new kernel is *running* inside the Debian installer: the target kernel takes effect only after reboot.

### Illustrative validation commands (not an automatic installer script)

```sh
apt-get update
apt-cache policy linux-image-amd64 linux-headers-amd64
apt-get -s full-upgrade
apt-mark showhold
dpkg --audit
apt list --upgradable
```

`apt full-upgrade` may remove installed packages to resolve dependencies. The actual transaction requires an on-screen review and explicit confirmation; any material unexpected removal or incompatibility is an installation **stop**, not a silent acceptance. Debian's global backports priority **900**, currently specified in **Debian tweaks**, increases the number of potentially upgraded packages and must pass the [APT compatibility gate](02_backports_apt.md).

**Dependency not changed by this update:** The currently documented ZRAM profile requires an explicit selection of **Debian tweaks**; this update neither auto-selects it nor removes that prerequisite. Whether to retain that prerequisite despite the ZRAM kernel checks is the next decision.

## Approved ZRAM-only sysctl configuration

During installation, **only if the ZRAM profile is selected**, create `/etc/sysctl.d/90-zram-swappiness.conf` with:

```ini
# Applied only by the independently selected ZRAM profile.
vm.swappiness = 100
```

Ensure the intended target system loads this setting on first boot. Confirm with `sysctl vm.swappiness` (expected `vm.swappiness = 100`). **If ZRAM is not selected**, do not create this file or otherwise override `vm.swappiness` as part of the ZRAM profile. Test both profile-selection paths; do not assume an existing local sysctl override is absent without inspecting it. The original uploaded source, reproduced below, remains unchanged.

## Deployment checklist specific to the customized installer

- [ ] Validate the ZRAM prerequisite selection: with Debian tweaks unchecked, prompt to **select Debian tweaks** or **deselect ZRAM**, without implicit selection. Test independently from the missing-swap-partition warning.
- [ ] Detect and confirm the chosen disk/partition **before** any destructive conversion; display its device identity, capacity, FSTYPE and PARTUUID.
- [ ] Verify the partition will not be used as ordinary swap when ZRAM is selected; ensure **no fstab, initramfs, systemd or installer-generated swap activation** re-enables it.
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
