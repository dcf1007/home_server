# 08 — Validation gates, decisions deferred, and release checklist

**Status:** open engineering checklist; no installer artifact built or tested. **Recorded:** 2026-11-14. **Provenance:** conversation decisions and uploaded ZRAM compressed-writeback proposal.

## Installation profile acceptance matrix

| Choice | Install-time action | Validation |
|---|---|---|
| Base Debian | Interactive install, minimal, SSH + standard utilities, manual disk selection | Boots UEFI, ext4 OS filesystem, hostname, local/root passwords, DHCP, confirmed installation target |
| Debian tweaks | Non-menu OS customizations (no ZRAM) | Kernel 7.x+headers, default stable fallback initially, GRUB, journald, fsck, SSD, APT pin and no unattended upgrades |
| OpenMediaVault 8 | OMV package installation only plus disable OMV cron-apt; user configures OMV afterwards | Package transaction safe; networking and the installer-confirmed administrator account SSH/sudo work; root SSH disabled; OMV cron-apt is inactive |
| Docker | Official Docker engine, containerd, Buildx and Compose CLI | Packages installed, `docker.service` and `docker.socket` inactive/disabled until approval |
| ZSTD ZRAM | Generator, manually selected raw backing, compressed writeback, monitor and ZRAM-only `vm.swappiness=100` | Kernel support/ordering verified; effective swappiness 100 only when selected; appropriate emergency behavior, monitor restart and no independent swap |

**All four optional profiles are separately displayed and initially unchecked.** **ZRAM can be selected without Debian tweaks** and must validate/install its own Linux 7.x kernel, matching headers, compatible generator and writeback prerequisites, explicitly requesting backports approval if necessary and completing a reviewed upgrade before proceeding. Never auto-select another option. Other compatibility checks remain mandatory.

## Blocking verification issues

1. **Global APT pin 900 versus OMV 8:** official OMV guidance warns of incompatible backports dependencies. Simulate intended package set and ask before any policy change.
2. **Kernel availability and package upgrade:** require the newest eligible Linux 7.x kernel (matching headers; moving metapackages; no fixed version), using standard Debian repos if possible or explicitly approved `trixie-backports` if necessary. If backports is newly enabled, require full, explicitly reviewed completion of all eligible package upgrades **before proceeding**; stop on package removals/conflicts that have not been approved. Check effective pinning and the installed target-kernel boot entry.
3. **ZRAM API compatibility:** verify selected kernel and Debian generator support resident limit, compressed writeback, early device setup and dynamic backing-size measurement; inspect uploaded monitor for logic/errors.
4. **User-controlled swap partition, conditional role:** user creates swap in ordinary Debian Installer partitioning (16 GB suggested). Without ZRAM, use as conventional swap. With ZRAM, re-purpose the **same** partition exclusively for raw PARTUUID writeback and prevent normal swap activation. If absent and ZRAM selected, explicitly offer **return to partitioning** or **deselect ZRAM**. Validate partman stage/order, swap signatures, `/etc/fstab`, user confirmation and safe navigation before shipping.
5. **Emergency recovery:** ensure systemd *really enters* emergency mode for a failed ZRAM initialization, with usable local root credentials; test this in a disposable environment.
6. **OMV / SSH / network:** ensure OMV does not enable root SSH or block the installer-confirmed administrator account; check DHCP and DNS.
7. **OMV scheduled updates:** verify environment variable and Salt deploy method on exact OMV version; confirm cron-apt is disabled. Verify Debian APT unattended package installation separately.
8. **Installer UI custom screens:** ensure requested order for the installer-confirmed administrator account/sudo/root passwords and interactive confirmation is achievable with Debian Installer and Simple-CDD.
9. **Docker service suppression:** ensure packages install without starting daemon/socket, including during package maintainer scripts.
10. **Firmware package selection and locale overrides:** broad proactive firmware coverage was approved; a provisional, Debian-13-package-name-verified inventory is in [04 Debian tweaks](04_debian_tweaks.md). Exact candidates and installation transactions still require simulation under the backports preference, inclusion/exclusion rationale and confirmation. Custom date/number formatting still needs implementation review.
11. **OS installation target selection:** require explicit confirmation of the installation disk and destructive partition writes; validate the selection procedure using disposable test disks.
12. **Installer image release:** verify boot modes, unsigned customized image provenance and USB integrity when media validation policy is finalized.

## Deferred / still open

- **Broad firmware coverage approved:** exact package names proposed and cross-checked against Debian's published package list; final installable set, dependencies and user confirmation **not yet finished**.
- Installation-media verification workflow (deferred to USB preparation).
- **Confirmed:** all four optional profiles are **unchecked by default**; the user explicitly selects and confirms desired components. Validate empty-selection behavior, **ZRAM-only installation without Debian tweaks**, and all selected combinations. No optional profile may be activated implicitly.
- **Resolved:** if the user makes a swap partition and ZRAM is unselected, use ordinary swap; if ZRAM is selected, use the same partition exclusively as its raw backing. If no swap is created, ordinary Debian's no-swap warning applies; ZRAM must prompt to return or be deselected. Technical integration of the two roles remains unverified.
- Precise validated method for date/number formatting beyond base `en_US.UTF-8`.
- Native system snapshot/rollback requirement (earlier deferred; ext4 root selected, so native Btrfs root snapshots are not available without a future migration).
- Exact device-independent partition labels or type GUID for raw ZRAM backing if special marking is needed.
- Whether/when Docker daemon should later be activated; OMV Compose and other services are separate later-phase decisions.
- Any required safe exceptions to global backports pin 900 must receive **explicit approval**.
- All profile/script implementations must be reviewed before production.

## Failure policy and evidence

- **Critical selected-profile failure:** stop, preserve logs, request manual intervention, never silently switch profiles or report success.
- **ZRAM init failure:** enter systemd emergency mode for local recovery, requiring a root password set during installation.
- **ZRAM monitor failure:** log and restart the monitor; do not independently trigger emergency mode.
- **Update installation:** user approval only (security included); no automatic reboots.
- Keep logs of `apt-cache policy`, simulated transactions, profile selections, partition identification and installer exit status in the installer/build evidence bundle.

## Reference index

[01 Preparation](01_custom_cdd_preparation.md) · [02 APT backports](02_backports_apt.md) · [03 ZRAM](03_zram_writeback.md) · [04 Debian tweaks](04_debian_tweaks.md) · [05 Base install](05_base_installation.md) · [06 OMV](06_openmediavault.md) · [07 Docker](07_docker.md)
