# Installer-only implementation

**Current lifecycle — 2026-11-20:** Native stages 10, 50, 55 and 60 run before the selected-profile executor at `61my-cdd`; the unmodified Simple-CDD verifier, custom status guard, unmodified CD-ROM eject and unmodified final message follow at `62simple-cdd`, `63my-cdd-status`, `64cdrom-detect` and `65final-message`. The early selector registers a pre-pkgsel `90my-cdd-order` relocation hook and a finish-install `00my-cdd-order` check; native udebs and hook contents are unchanged. The CD-ROM APT-source preseed remains; no forced ifupdown or suppressed completion dialog. A repeat finalization after stage 61 starts is blocked (exit 10) before native network finalization; inspect logs and recover manually or restart the installation rather than replaying operations. ISO/GTK/text/first-boot testing is pending.

## Native progress reporting — 2026-11-20

**Nearest user prompt:** “i would choose option A” (native Debian Installer progress feedback rather than embedded terminal or live output changes).

- Use native cdebconf templates and status messages for selected profiles, administrator/recovery checks, APT index refresh/simulation/approved execution, kernel candidates, firmware candidates and license preparation, OMV/Docker signing-key downloads, writeback partition inspection/preparation, GRUB/initramfs refresh, package/service verification and completion. Firmware counts actual candidate tokens; local profile progress counts verified completion markers, not elapsed time.
- Trixie `finish-install` 2.124 already starts its own bar (https://sources.debian.org/src/finish-install/2.124/debian/postinst). Trixie cdebconf 0.280 GTK destroys previous bars on START, and its command dispatcher ignores DC_NOTOK for progress INFO (https://sources.debian.org/src/cdebconf/0.280/src/modules/frontend/gtk/progress.c and https://sources.debian.org/src/cdebconf/0.280/src/commands.c). Do not start a competing nested bar. Initially use existing native progress INFO; after APT or anna handoff, open a custom native bar between native operations with actual completed profile count; stop it before another native transaction or exiting the hook. This cannot restore the already-replaced finish-install bar and frontend rendering is not yet tested. Native APT mechanism unchanged. No change to command capture/log streaming, package choices, acceptance/dialogs, credentials, partition policy, repositories, OMV first boot, or the independent Netplan experiment.
- Validation: source inspection and static consistency checks only; rebuild/test GTK and text frontend, base-only recovery, firmware candidate progression, transitions to/from APT including failure/cancel, and final native completion. Do not infer continuous animation or per-command percentage for blocking operations.


This directory contains **Debian Installer integration**, not generic post-install configuration instructions. The standalone server howtos are in the [repository root](../../../README.md). Netinst adaptation notes are in [99's guide](../../README.md).

## Entry points and mechanisms

- `profile-confirm.sh`, `profile-confirm.templates`: native early preseed Debconf selection summary, with explicit default-No approval before selected-profile operations.
- `ordered-selection.sh`: read-only seven-profile order/dependency parser.
- `finish-order.sh`: registered as pre-pkgsel `90my-cdd-order` for relocations, and finish-install `00my-cdd-order` for fail-closed order and replay checks.
- `run-selected.sh`: registered native finish-install stage `61my-cdd` executor, target logging, approval/recovery preflight and ordered dispatch. Its native GTK/text failure note displays the failed command, exit status and real captured stdout/stderr; `in-target` stderr is redirected to stdout within the target to avoid syslog-only diagnostics.
- `profile-common.sh`: shared suite/version lookup, profile selection context, and signed APT refresh, without extra package-removal or priority restrictions.
- `backports.sh`, `ensure-7x-kernel.sh`, `extended-device-support.sh`, `zram-writeback.sh`, `debian-tweaks.sh`, `openmediavault.sh`, `docker.sh`: selected-only installer adaptations of the corresponding feature guides; filenames now match the native Simple-CDD profile IDs.
- `zram-writeback-selection.sh`: installer-native GPT selection using `util-linux-udeb` `blkid`, sysfs, /proc mount/swap state and BusyBox, with separate exact-device approvals.
- `openmediavault-firstboot.sh` and `openmediavault-firstboot.service`: OMV-only native systemd oneshot job staged by the selected profile; runs upstream `omv-confdbadm populate` and `omv-salt deploy run hosts` on first boot, logs output and final status, shows console/journal progress and errors, and deletes the unit, enablement symlink and own script on success or failure. The log remains as the only permanent artifact and prevents reruns.
- `63my-cdd-status`: native finish-install stage 63, checks final `COMPLETE` plus each explicitly selected profile's individual completion record, returning exit 10 when any required check fails.
- `IMPLEMENTATION_GATES.md`: actual runtime and first-boot issues still requiring testing.

Simple-CDD's unmodified native `62simple-cdd` hook runs seven possible verification-only `profiles/<name>.postinst` scripts **only when those profiles were selected**. The stage-61 runner installs selected packages and writes individual records; stage 63 checks the approved selection and those records. For OMV, the record means the approved packages were installed and the one-time first-boot job was registered—not that OMV initialization has already completed. The ZRAM helper uses the matching profile stem with a `-selection` suffix.

## Invariants

The seven optional profiles start unchecked, no disk is chosen by device-name guesswork, no ZRAM conversion happens without an explicit destructive confirmation, and no package plan is executed before review. Root rescue access must be usable. OMV and Docker are independent; no OMV-Extras/Compose plugin is installed.

Installer udebs are not interchangeable with full util-linux binaries. The installed-system [ZRAM chapter](../../../06_zram_writeback/README.md) deliberately uses the simpler full-Debian tools.

**Not yet established:** the revised OMV one-shot behavior in a booted Debian VM, complete OMV network/Salt configuration, full ZRAM first boot, and every installer combination. Isolated first-boot shell tests passed for both success and failure cases, but no complete VM first-boot test has passed. Use disposable VM disks to validate. See [active release checklist](../../validation_and_pending.md).

The former long installer README, including observed screenshot failures and earlier workarounds, is preserved in [history](../../history/installer-README-20261115.md).
