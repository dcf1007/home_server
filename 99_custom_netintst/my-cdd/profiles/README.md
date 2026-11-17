# Simple-CDD 0.6.9 profile inputs

The seven optional checkbox names stay in `simple-cdd.conf` and start unchecked. The native `simple-cdd/profiles` Debconf question is reused and explicitly confirmed before the original `simple-cdd-profiles` udeb processes selections. No optional profile is selected automatically.

| Profile | Selected-only operation |
|---|---|
| `debian-tweaks` | Approved root filesystem, GRUB, SSH root-login and conditional manual-update settings |
| `backports` | Signed Debian Backports, complete reviewed upgrade and individually approved cleanup |
| `ensure-7x-kernel` | Linux 7.x moving image and matching headers |
| `extended-device-support` | Broad firmware and both CPU microcode families, explicit licenses and omissions |
| `zram-writeback` | Confirmed raw GPT backing, compressed ZRAM writeback and monitor |
| `openmediavault` | Official OMV 8 installation and two vendor initialization commands |
| `docker` | Official Docker Engine/Compose packages and native service defaults |

All selected behavior is implemented by `installer/profile-*.sh` modules, sourced once in the approved order by `installer/run-selected.sh`. The original Debian Installer finish-install hook order performs CD-ROM APT cleanup at stage `10apt-cdrom-setup`, then runs the custom executor at registered stage `11my-cdd`, followed by the unmodified Simple-CDD stage `14simple-cdd`. One final `15my-cdd-status` checks the executor's overall completion state before the native success message.

**All seven optional profiles have executable `.postinst` verifiers and per-profile completion markers.** Stage 11 writes the marker after its selected handler succeeds; the original Simple-CDD stage 14 runs that profile's verification-only `.postinst` in-target. The stage-15 final guard also checks every selected record and overall `COMPLETE`, returning exit 10 if incomplete. Optional profile `.extra` files stage only their selected handler source/asset inputs; the shared files are supplied by `default.extra`. There are deliberately no optional `.packages` files, because those would queue package installation before the user's complete per-transaction APT review.

The native `apt-setup/disable-cdrom-entries=true` preseed option handles installation-CD entries before selected APT transactions, without a duplicate editor or second hook invocation. The build-only `installer-media` profile makes `zstd`, `parted-udeb` and `util-linux-udeb` available on the ISO; it is never a selectable installed-system profile.

All root-password recovery, APT transaction approvals, firmware omissions and ZRAM destructive confirmations use the existing native Debian Installer GTK/text frontend. Neither OMV nor Docker changes custom SSH, groups or automatic-update policy. A fresh disposable-VM ISO and first-boot test are still required.

**Canonical names:** `profiles/<name>.description`, `profiles/<name>.extra`, `profiles/<name>.postinst` and `installer/<name>.sh` use the identical profile identifier for all seven optional choices. The additional ZRAM helper is `installer/zram-writeback-selection.sh`; general shared framework scripts are not profile-specific.
