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

**Actual source state:** `default.preseed`, `default.udebs` and `default.packages` are initial legitimate Simple-CDD inputs. Each optional `*.description` is a real menu item. Each optional `*.packages` intentionally queues **no packages**, since that would bypass mandatory review, startup suppression or ZRAM first-action conversion. Every optional `*.postinst` now verifies a per-profile completion record written by the ordered [`installer/run-selected.sh`](../installer/run-selected.sh). It fails if the selected operation did not complete, and does not install anything a second time.

**Upstream behavior:** [the Simple-CDD 0.6.9 finish-install runner](https://sources.debian.org/src/simple-cdd/0.6.9/debian/14simple-cdd) executes only executable `*.postinst` files **inside the target**, in the order returned by the selected multiselect. The existing source dispatcher enforces Backports → Ensure 7.x → Extended support → ZRAM → tweaks → OMV → Docker rather than trusting UI selection order, but must still be validated in a running installer. [`../build.sh`](../build.sh) checks that every optional postinst is executable in the Git checkout; its tracked mode is already 100755.

**Never embed:** passwords, fixed installation-disk paths, automatically selected profiles, forced filesystem writes or unreviewed APT transactions. See [the preparation guide](../../01_custom_cdd_preparation.md).
