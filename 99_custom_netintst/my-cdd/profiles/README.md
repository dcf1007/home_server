# Simple-CDD 0.6.9 profile inputs

**Current lifecycle — 2026-11-20:** Native stages 10, 50, 55 and 60 run before the selected-profile executor at `61my-cdd`; the unmodified Simple-CDD verifier, custom status guard, unmodified CD-ROM eject and unmodified final message follow at `62simple-cdd`, `63my-cdd-status`, `64cdrom-detect` and `65final-message`. The early selector registers a pre-pkgsel `90my-cdd-order` relocation hook and a finish-install `00my-cdd-order` check; native udebs and hook contents are unchanged. The CD-ROM APT-source preseed remains; no forced ifupdown or suppressed completion dialog. A repeat finalization after stage 61 starts is blocked (exit 10) before native network finalization; inspect logs and recover manually or restart the installation rather than replaying operations. ISO/GTK/text/first-boot testing is pending.

The seven optional checkbox names stay in `simple-cdd.conf` and start unchecked. The native `simple-cdd/profiles` Debconf question is reused and explicitly confirmed before the original `simple-cdd-profiles` udeb processes selections. No optional profile is selected automatically.

| Profile | Selected-only operation |
|---|---|
| `debian-tweaks` | Approved root filesystem, GRUB, SSH root-login and conditional manual-update settings |
| `backports` | Signed Debian Backports, complete reviewed upgrade and individually approved cleanup |
| `ensure-7x-kernel` | Linux 7.x moving image and matching headers |
| `extended-device-support` | Broad firmware and both CPU microcode families, explicit licenses and omissions |
| `zram-writeback` | Confirmed raw GPT backing, compressed ZRAM writeback and monitor |
| `openmediavault` | Official OMV 8 package installation and one-time first-boot initialization using two upstream commands |
| `docker` | Official Docker Engine/Compose packages and native service defaults |

All selected behavior is implemented by `installer/profile-*.sh` modules, sourced once in the approved order by `installer/run-selected.sh`. The original Debian Installer finish-install hook order performs CD-ROM APT cleanup at stage `10apt-cdrom-setup`, then runs the custom executor at registered stage `61my-cdd`, followed by the unmodified Simple-CDD stage `62simple-cdd`. One final `63my-cdd-status` checks the executor's overall completion state before the native success message.

**All seven optional profiles have executable `.postinst` verifiers and per-profile completion markers.** Stage 61 writes the marker after its selected handler succeeds; the original Simple-CDD stage 62 runs that profile's verification-only `.postinst` in-target. The stage-63 final guard also checks every selected record and overall `COMPLETE`, returning exit 10 if incomplete. For `openmediavault`, the installer record verifies that the package installation and first-boot job registration succeeded. Only `/var/log/installer/my-cdd-omv-firstboot.log` reports the actual post-boot OMV result; the first-boot unit and runner remove themselves, with no separate status/attempt marker or login notice. Optional profile `.extra` files stage only their selected handler source/asset inputs; the shared files are supplied by `default.extra`. There are deliberately no optional `.packages` files, because those would queue package installation before the user's complete per-transaction APT review.

The native `apt-setup/disable-cdrom-entries=true` preseed option handles installation-CD entries before selected APT transactions, without a duplicate editor or second hook invocation. The build-only `installer-media` profile makes `zstd`, `parted-udeb` and `util-linux-udeb` available on the ISO; it is never a selectable installed-system profile.

All root-password recovery, APT transaction approvals, firmware omissions and ZRAM destructive confirmations use the existing native Debian Installer GTK/text frontend. Neither OMV nor Docker changes custom SSH, groups or automatic-update policy. A fresh disposable-VM ISO and first-boot test are still required.

**Canonical names:** `profiles/<name>.description`, `profiles/<name>.extra`, `profiles/<name>.postinst` and `installer/<name>.sh` use the identical profile identifier for all seven optional choices. The additional ZRAM helper is `installer/zram-writeback-selection.sh`; general shared framework scripts are not profile-specific.
