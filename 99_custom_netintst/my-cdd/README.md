# my-cdd — Debian 13 custom Simple-CDD ISO source

**Current lifecycle — 2026-11-20:** Native stages 10, 50, 55 and 60 run before the selected-profile executor at `61my-cdd`; the unmodified Simple-CDD verifier, custom status guard, unmodified CD-ROM eject and unmodified final message follow at `62simple-cdd`, `63my-cdd-status`, `64cdrom-detect` and `65final-message`. The early selector registers 61/63; `partman/early_command` calls `finish-order.sh` before partitioning, checks all three original native scripts and then renames them. Native udebs and script contents are unchanged. The CD-ROM APT-source preseed remains; no forced network backend or suppressed completion dialog. Relocation failure returns nonzero to native preseed error handling, which does not guarantee installation termination. No stage-00 guard or additional repeated-execution restriction is introduced. ISO/GTK/text/first-boot testing is pending.

## Native progress reporting — 2026-11-20

**Nearest user prompt:** “i would choose option A” (native Debian Installer progress feedback rather than embedded terminal or live output changes).

- Use native cdebconf templates and status messages for selected profiles, administrator/recovery checks, APT index refresh/simulation/approved execution, kernel candidates, firmware candidates and license preparation, OMV/Docker signing-key downloads, writeback partition inspection/preparation, GRUB/initramfs refresh, package/service verification and completion. Firmware counts actual candidate tokens; local profile progress counts verified completion markers, not elapsed time.
- Trixie `finish-install` 2.124 already starts its own bar (https://sources.debian.org/src/finish-install/2.124/debian/postinst). Trixie cdebconf 0.280 GTK destroys previous bars on START, and its command dispatcher ignores DC_NOTOK for progress INFO (https://sources.debian.org/src/cdebconf/0.280/src/modules/frontend/gtk/progress.c and https://sources.debian.org/src/cdebconf/0.280/src/commands.c). Do not start a competing nested bar. Initially use existing native progress INFO; after APT or anna handoff, open a custom native bar between native operations with actual completed profile count; stop it before another native transaction or exiting the hook. This cannot restore the already-replaced finish-install bar and frontend rendering is not yet tested. Native APT mechanism unchanged. No change to command capture/log streaming, package choices, acceptance/dialogs, credentials, partition policy, repositories, OMV first boot, or the independent Netplan experiment.
- Validation: source inspection and static consistency checks only; rebuild/test GTK and text frontend, base-only recovery, firmware candidate progression, transitions to/from APT including failure/cancel, and final native completion. Do not infer continuous animation or per-command percentage for blocking operations.


**Account setup and firmware consent (2026-11-20):** Initial root-password setup is skipped using the native `passwd/root-login=false` preseed; the existing late recovery-password dialog remains. Set `AUTO_ACCEPT_FIRMWARE_LICENSES=false` in `profile_defaults.conf` and rebuild to restore interactive vendor license dialogs. The default `true` preauthorizes only the two named agreements for selected Extended device support; review those terms before building/distributing. APT review remains mandatory.

This is the **installer implementation**, not the first step for a normal Debian server. For the uncomplicated post-install path see the [repository's numbered howtos](../../README.md); for the installer strategy see [99 — custom netinst](../README.md).

The source was relocated from `01_custom_netinst/my-cdd` to `99_custom_netintst/my-cdd`. **All executable build, profile and installer scripts, configuration and ISO assets were preserved without functional edits by that move.**

## Build

On a compatible Debian build host:

~~~sh
sudo apt-get update
sudo apt-get install git simple-cdd reprepro
git clone https://github.com/dcf1007/home_server.git
cd home_server/99_custom_netintst/my-cdd
./build.sh
~~~

For an existing clone, `git pull --ff-only` first and then run `./build.sh` from this directory. Intended output: `images/debian-13-amd64-CD-1.iso`. Build logs are produced here (`build-mirror-debug.log`, `build-debug.log`, `build-terminal.log`, `tmp/log/`).

The complete [build-project construction guide](../build_project.md) explains the build inputs and commands. [build.sh](build.sh) generates editable preseed suggestions from [profile_defaults.conf](profile_defaults.conf), runs Simple-CDD's mirror-only and build-only stages and propagates native build errors. The extra custom build refusal/ISO-content checks have been removed as requested.

## Source layout

- [simple-cdd.conf](simple-cdd.conf): seven optional profiles, all initially unchecked, no automatic selection.
- [profiles/](profiles): profile descriptions, `.extra` staging inputs, native per-profile `.postinst` success verifiers, and the **build-only** media profile.
- [installer/](installer): native GTK/text Debconf confirmation, selected-only stage-61 finish-install dispatcher, and single stage-63 completion guard.
- [scripts/](scripts): inputs staged on the ISO (Backports source, firmware inventory, ZRAM generator and monitor).
- [profile_defaults.conf](profile_defaults.conf): editable suggestions for native installer questions, **not** passwords, disk selection or preapproved optional profiles.
- [SOURCE_MANIFEST.md](SOURCE_MANIFEST.md): detailed chronological source provenance and past defects.

**Selected-profile execution order:** Debian tweaks → Backports → Ensure 7.x kernel → Extended device support → ZRAM writeback → OMV 8 → Docker. ZRAM requires separately selected Ensure 7.x. Only selected features are applied.

### Why the installer differs from the standalone guides

`udebs` are not ordinary Debian packages: Debian Installer is a stripped-down environment. Partition discovery/conversion uses native `blkid` from `util-linux-udeb`, `parted-udeb`, BusyBox, `/sys` and `/proc`. The ordinary [ZRAM guide](../../06_zram_writeback/README.md) can use full `wipefs` and `sgdisk` instead. Other installer-only mechanisms include `in-target`, cdebconf and Debian's native finish-install hook directory. The stage-10 CD-ROM cleanup now precedes the stage-61 profile executor without a custom source editor or double invocation.

**Validation:** The latest 2026-11-16 VM progressed through the approved ZRAM conversion and OMV signed APT repository to its complete package simulation. The custom, unrequested essential-package blacklist stopped the installation on a proposed `systemd-timesyncd` replacement before transaction approval. This review branch removes that policy and the other unapproved installer restrictions; APT plans and explicit approvals remain. **A rebuilt ISO, full OMV/Docker installation and first-boot ZRAM checks are still pending.** See [active release gates](../validation_and_pending.md).

The previous long README, including the detailed VM failures and obsolete interim tool strategies, is preserved in [history/my-cdd-README-20261115.md](../history/my-cdd-README-20261115.md).

**2026-11-17 OMV first-boot correction:** The selected OMV handler installs approved packages and registers a one-time systemd service rather than running `omv-confdbadm populate` in the unfinished target chroot. The first boot runs upstream `populate` and `hosts` commands once; boot console/journal output reports progress/errors, and only `/var/log/installer/my-cdd-omv-firstboot.log` remains after the one-time unit, enablement link and runner delete themselves. The installer records package/scheduling success separately from runtime OMV initialization status. All Docker and shared completion code remains unchanged. Fresh ISO and VM validation remain necessary.

**Current completion contract:** The existing stage-61 runner records individual selected-profile completion; native stage-62 Simple-CDD invokes each selected `.postinst` verifier; stage 63 refuses completion when any selected record or the overall status is missing. Installer modules share filenames with their Simple-CDD profile definitions. ISO and first-boot validation remain pending.
