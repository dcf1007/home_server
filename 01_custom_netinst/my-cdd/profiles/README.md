# Simple-CDD 0.6.9 profile inputs

The working sources here define a **fixed menu of seven optional profiles**, all unchecked, plus a special always-present `default` profile.

| Profile | Intended behavior |
|---|---|
| `backports` | Enable signed trixie-backports at priority 100; reviewed eligible upgrade and cleanup |
| `ensure-7x-kernel` | Backports-first moving 7.x kernel + headers if Backports was selected |
| `extended-device-support` | Both CPU microcode packages and broad firmware, with explicit omissions |
| `zram-writeback` | Confirmed raw writeback partition, ZSTD compressed ZRAM and monitor |
| `debian-tweaks` | Optional nondefault ext4/boot/SSH/update changes |
| `openmediavault` | OMV 8 package and update policy, preserve admin SSH/sudo |
| `docker` | Official Docker packages with daemon/socket inactive |

**Actual source state:** The project intentionally customizes `default.preseed` to preserve manual, editable Debian Installer questions and `default.packages` for the agreed headless SSH/sudo/time-sync baseline. Because the project file **replaces**, rather than merges with, the upstream file, `default.packages` also retains upstream's `less` package. The project does **not** provide `default.downloads` or `default.udebs`; Simple-CDD automatically falls back to its own complete copies in `/usr/share/simple-cdd/profiles/` (including GRUB, debootstrap, busybox, storage and installer tools, plus the upstream `simple-cdd-profiles` udeb). The custom `installer-media.downloads` is enabled through `build_profiles="installer-media"` and adds the separate `zstd` command-line package **to the ISO only**, without adding an eighth selectable profile or automatically installing it in the target. ZRAM's kernel compression algorithm is independent of the `zstd` CLI.

Each optional `*.description` is a real menu item. Optional `*.packages` intentionally queue **no packages**, since that would bypass mandatory review, startup suppression or the ZRAM first-action conversion. Every optional `*.postinst` verifies a completion record written by the ordered [`installer/run-selected.sh`](../installer/run-selected.sh); it does not perform a second installation.

**Upstream behavior:** [the Simple-CDD 0.6.9 finish-install runner](https://sources.debian.org/src/simple-cdd/0.6.9/debian/14simple-cdd) executes only executable `*.postinst` files **inside the target**, in the order returned by the selected multiselect. The existing source dispatcher enforces Backports → Ensure 7.x → Extended support → ZRAM → tweaks → OMV → Docker rather than trusting UI selection order, but must still be validated in a running installer. [`../build.sh`](../build.sh) checks that every optional postinst is executable in the Git checkout; its tracked mode is already 100755.

**Never embed:** passwords, fixed installation-disk paths, automatically selected profiles, forced filesystem writes or unreviewed APT transactions. See [the preparation guide](../../01_custom_cdd_preparation.md).
