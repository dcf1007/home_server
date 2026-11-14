# 07 — Selectable **ZSTD ZRAM with compressed SSD writeback** profile

**Status:** uploaded proposed design accepted as target architecture, **subject to full technical validation**. No tested kernel setup or monitor claimed. **Recorded:** 2026-11-14. **Provenance:** uploaded `zram_zstd_writeback_design(1).md` and explicit decisions replacing earlier 16 GB LZ4 ZRAM + 16 GB independent swap.

## Exclusive scope

ZRAM configuration belongs **only here**; it must not be part of the Debian tweaks profile. If this profile is selected, the installed system must use `systemd-zram-generator` to provide compressed swap with **ZSTD**, backed by a **dedicated 16 GB raw SSD partition**. That partition is not mounted, not formatted as a normal filesystem and **not** independently enabled with `swapon`. Identify it by stable **PARTUUID** and inspect measured physical capacity.

**Critical planning dependency:** the ZRAM profile is selected interactively but requires partitioning the SSD. The profile decision must therefore be available *before* the disk layout is committed or the custom installer must explicitly present the conditional partition for approval. No automatic repartitioning is permitted.

## Architecture requested

| Parameter | Proposed/approved target |
|---|---|
| Compression algorithm | **ZSTD** from first swap-out |
| Generator | `systemd-zram-generator` |
| Compressed writeback | Kernel `compressed_writeback` enabled before initializing zram |
| Physical resident memory limit | Half of actual `MemTotal`; for installed 32 GB RAM, about 16 GB |
| ZRAM logical size | Adaptive formula approximately installed RAM + raw backing partition capacity |
| Backing capacity | **16 GB**, measured from actual PARTUUID device |
| Independent swap | **None**; do not create/activate one |
| zswap | Disabled (proposed kernel argument `zswap.enabled=0`) |
| Writes to SSD | Triggered by pressure monitor rather than ordinary second swap device |
| Background daemon | One Bash monitor, supervised/restarted by systemd; no additional dedicated daemon |

Note: each written-back zram entry still consumes a full backing slot even if payload compression is effective; compressed writeback does **not** pack multiple entries into one SSD sector.

## Monitor policy from uploaded proposal — NOT YET VERIFIED

The uploaded document proposes polling kernel virtual files every **1 second**:

- `/proc/pressure/memory`, memory PSI `some avg10`;
- `/sys/block/zram0/mm_stat` for resident usage.

Trigger normal writeback when **resident usage is at least 80%** of its limit **and** PSI `some avg10` is at least **5%**. Continue while pressure persists; stop passes once resident usage is **under 70%** or PSI is below 5%, except in emergencies.

Increase eligibility over successive synchronous passes using time-since-last-use thresholds:

1. 24 hours;
2. 6 hours;
3. 1 hour;
4. 5 minutes;
5. 1 minute.

If resident usage reaches **95%**, writeback may proceed without the PSI threshold and can broaden selection to remaining pages. There is no per-pass `writeback_limit` in the proposed design. Consequently one pass can cause large SSD write I/O, and pages are **eligible by age**, not globally sorted oldest-first. A background monitor cannot guarantee relief before a sudden out-of-memory event.

The underlying sysfs operations in the uploaded proposal include writing an age threshold to `/sys/block/zram0/idle` and writing `type=idle` to `/sys/block/zram0/writeback`. **Do not deploy the uploaded Bash script unchanged** until parsers, permissions, failure behavior, concurrency, kernel facilities and test cases have been reviewed.

## Generator concept (provisional, not a copy/paste-ready release)

The uploaded design specifies these logical settings:

```ini
[zram0]
zram-size = ram + backingBytes / 1048576
zram-resident-limit = ram / 2
compression-algorithm = zstd
writeback-device = /dev/disk/by-partuuid/YOUR_PARTUUID
swap-priority = 100
```

`backingBytes` is intended to be populated by a generator command reading the actual block size. The early-boot timing of the PARTUUID symlink and re-evaluation behavior must be checked against the actual installed `systemd-zram-generator` version. A proposed `ExecStartPre` writes `yes` into the `compressed_writeback` sysfs attribute **before** the device is initialized; this ordering must be verified on the actual kernel and unit.

The original proposal optionally mentions `vm.swappiness=100`; that was **not independently approved as a fixed value**, so do not impose it without consulting the user.

## Startup / failure behavior

The user explicitly requires:

1. Prepare and configure the selected ZRAM system **during the Debian installation**, to become active on the **first boot**, but only if the compatibility checks pass.
2. If **ZRAM device initialization** fails, stop ordinary boot, enter **systemd emergency mode**, and require manual recovery. The separate local root password must have been set interactively during installation.
3. If the **writeback monitor** fails after ZRAM has initialized, **log and restart** the monitor via systemd; **do not** enter emergency mode solely because of monitor failure.
4. No fallback to independent SSD swap; the raw backing partition cannot simultaneously be ordinary swap.
5. Monitor unit must not run against a failed/partial ZRAM setup. Design a reliable dependency and failure propagation mechanism; do not assume a simple Wants/After relationship forces emergency mode.

**Important:** This stringent first-boot failure policy means an unsupported kernel feature or incorrect systemd wiring can prevent unattended startup. A different live installer kernel cannot conclusively validate the installed kernel's runtime ZRAM features.

## Acceptance tests on installed kernel

```sh
uname -r
lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,PARTUUID,MOUNTPOINTS
swapon --show
zramctl
cat /sys/block/zram0/compressed_writeback
cat /sys/block/zram0/backing_dev
cat /sys/block/zram0/disksize
cat /sys/block/zram0/mm_stat
cat /sys/block/zram0/bd_stat
cat /sys/block/zram0/io_stat
cat /proc/pressure/memory
systemctl status dev-zram0.swap zram-pressure.service
journalctl -b -u systemd-zram-setup@zram0.service -u zram-pressure.service
```

Test emergency activation for intentional ZRAM initialization failure **in a disposable VM first**, and test monitor restart separately. Confirm that `swapon --show` reports only the selected ZRAM swap hierarchy and that the raw partition is not mounted or independently swapped.

## References

- [Linux ZRAM kernel documentation](https://docs.kernel.org/admin-guide/blockdev/zram.html)
- [Memory PSI documentation](https://docs.kernel.org/accounting/psi.html)
- [Debian ZRAM generator configuration](https://manpages.debian.org/unstable/systemd-zram-generator/zram-generator.conf.5.en.html)
- [Upstream ZRAM generator](https://github.com/systemd/zram-generator)
- **User-provided source:** `zram_zstd_writeback_design(1).md` (uploaded in this planning conversation; not yet copied into this GitHub directory).
