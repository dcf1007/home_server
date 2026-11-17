# Installer-only implementation

This directory contains **Debian Installer integration**, not generic post-install configuration instructions. The standalone server howtos are in the [repository root](../../../README.md). Netinst adaptation notes are in [99's guide](../../README.md).

## Entry points and mechanisms

- `profile-confirm.sh`, `profile-confirm.templates`: native early preseed Debconf selection summary, with explicit default-No approval before selected-profile operations.
- `ordered-selection.sh`: read-only seven-profile order/dependency parser.
- `run-selected.sh`: registered native finish-install stage `11my-cdd` executor, target logging, approval/recovery preflight and ordered dispatch. Its native GTK/text failure note displays the failed command, exit status and real captured stdout/stderr; `in-target` stderr is redirected to stdout within the target to avoid syslog-only diagnostics.
- `profile-common.sh`: shared suite/version lookup, profile selection context, and signed APT refresh, without extra package-removal or priority restrictions.
- `backports.sh`, `ensure-7x-kernel.sh`, `extended-device-support.sh`, `zram-writeback.sh`, `debian-tweaks.sh`, `openmediavault.sh`, `docker.sh`: selected-only installer adaptations of the corresponding feature guides; filenames now match the native Simple-CDD profile IDs.
- `zram-writeback-selection.sh`: installer-native GPT selection using `util-linux-udeb` `blkid`, sysfs, /proc mount/swap state and BusyBox, with separate exact-device approvals.
- `15my-cdd-status`: native finish-install stage 15, checks final `COMPLETE` plus each explicitly selected profile's individual completion record, returning exit 10 when any required check fails.
- `IMPLEMENTATION_GATES.md`: actual runtime and first-boot issues still requiring testing.

Simple-CDD's unmodified native `14simple-cdd` hook runs seven possible verification-only `profiles/<name>.postinst` scripts **only when those profiles were selected**. The stage-11 runner installs selected features once and writes their individual records; stage 15 performs the final check. The ZRAM helper uses the matching profile stem with a `-selection` suffix.

## Invariants

The seven optional profiles start unchecked, no disk is chosen by device-name guesswork, no ZRAM conversion happens without an explicit destructive confirmation, and no package plan is executed before review. Root rescue access must be usable. OMV and Docker are independent; no OMV-Extras/Compose plugin is installed.

Installer udebs are not interchangeable with full util-linux binaries. The installed-system [ZRAM chapter](../../../06_zram_writeback/README.md) deliberately uses the simpler full-Debian tools.

**Not yet established:** reliable early confirmation and stage-11 Debconf behavior, native partition metadata probing, approved BusyBox erase, full ZRAM first boot and OMV network/Salt behavior. Use disposable VM disks to validate. See [active release checklist](../../validation_and_pending.md).

The former long installer README, including observed screenshot failures and earlier workarounds, is preserved in [history](../../history/installer-README-20261115.md).
