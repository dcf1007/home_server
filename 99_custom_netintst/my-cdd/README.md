# my-cdd — Debian 13 custom Simple-CDD ISO source

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

The complete [build-project construction guide](../build_project.md) explains every required file and check. The [build.sh](build.sh) script keeps upstream Simple-CDD `default.*` inputs, runs mirror-only then build-only to handle installer `UDebComponents`, generates editable preseed suggestions from [profile_defaults.conf](profile_defaults.conf), validates shell syntax and staged assets, and checks that `zstd` plus `parted-udeb` and `util-linux-udeb` are present on the ISO.

## Source layout

- [simple-cdd.conf](simple-cdd.conf): seven optional profiles, all initially unchecked, no automatic selection.
- [profiles/](profiles): profile descriptions, `.extra` packaging inputs, completion-verifying postinst scripts, and the **build-only** media profile.
- [installer/](installer): native GTK/text Debconf confirmation, ordered late-command dispatcher, selected-only modules and fail-closed completion guard.
- [scripts/](scripts): inputs staged on the ISO (Backports source, firmware inventory, ZRAM generator and monitor).
- [profile_defaults.conf](profile_defaults.conf): editable suggestions for native installer questions, **not** passwords, disk selection or preapproved optional profiles.
- [SOURCE_MANIFEST.md](SOURCE_MANIFEST.md): detailed chronological source provenance and past defects.

**Selected-profile execution order:** Debian tweaks → Backports → Ensure 7.x kernel → Extended device support → ZRAM writeback → OMV 8 → Docker. ZRAM requires separately selected Ensure 7.x. Only selected features are applied.

### Why the installer differs from the standalone guides

`udebs` are not ordinary Debian packages: Debian Installer is a stripped-down environment. Partition discovery/conversion uses native `blkid` from `util-linux-udeb`, `parted-udeb`, BusyBox, `/sys` and `/proc`. The ordinary [ZRAM guide](../../06_zram_writeback/README.md) can use full `wipefs` and `sgdisk` instead. Other installer-only mechanisms include `in-target`, cdebconf and preseed/late_command.

**Validation:** The user-supplied latest ISO screenshots show ZRAM conversion and generator installation, but the selected tweaks profile then failed during target OpenSSH validation. This branch includes a proposed transient-runtime-directory correction, **not yet retested**. First-boot ZRAM writeback remains unverified. See [active release gates](../validation_and_pending.md).

The previous long README, including the detailed VM failures and obsolete interim tool strategies, is preserved in [history/my-cdd-README-20261115.md](../history/my-cdd-README-20261115.md).
