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

**Actual source state:** `default.preseed`, `default.udebs` and `default.packages` are initial legitimate Simple-CDD inputs. Each optional `*.description` is a real menu item. Each optional `*.packages` intentionally queues **no packages**, since that would bypass mandatory review, startup suppression or ZRAM first-action conversion. Every optional `*.postinst` currently stops with an explicit error until the production executor has been implemented and reviewed.

**Upstream behavior:** [the Simple-CDD 0.6.9 finish-install runner](https://sources.debian.org/src/simple-cdd/0.6.9/debian/14simple-cdd) executes only executable `*.postinst` files **inside the target**, in the order returned by the selected multiselect. The future ordered executor must enforce Backports → Ensure 7.x → Extended support → ZRAM → tweaks → OMV → Docker rather than trusting UI selection order. [`../build.sh`](../build.sh) corrects GitHub's non-executable file mode once the profile implementations replace the unfinished stubs.

**Never embed:** passwords, fixed installation-disk paths, automatically selected profiles, forced filesystem writes or unreviewed APT transactions. See [the preparation guide](../../01_custom_cdd_preparation.md).
