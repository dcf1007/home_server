# 08 — Validation gates, decisions deferred, and release checklist

**Status:** open engineering checklist; no installer artifact built or tested. **Recorded:** 2026-11-14. **Provenance:** conversation decisions and uploaded ZRAM compressed-writeback proposal.

## Installation profile acceptance matrix

| Choice | Install-time action | Validation |
|---|---|---|
| Base Debian | Interactive install, minimal, SSH + standard utilities, manual disk selection | Boots UEFI, ext4 OS filesystem, hostname, local/root passwords, DHCP, confirmed installation target |
| Backports | Explicitly enable `trixie-backports` at default priority **100**; review/complete eligible upgrades, autoremove and purge leftovers | Full upgrade and cleanup confirmed; all proposed removals explicitly reviewed; no eligible upgrades left; no critical package removed |
| Ensure 7.x kernel branch | Install newest eligible Linux **7.x** image and matching headers from standard repos, or request Backports and install only necessary kernel-related backports packages | Correct version, headers and GRUB; initial stable-kernel fallback; no fixed version lock; backports selected explicitly if required |
| Extended device support | Additional CPU microcode and proactively installed firmware | Appropriate vendor microcode; final broad firmware package set simulated and reviewed |
| ZSTD ZRAM | Generator, manually selected raw backing, compressed writeback, monitor and ZRAM-only `vm.swappiness=100` | Kernel support/ordering verified; effective swappiness 100 only when selected; appropriate emergency behavior, monitor restart and no independent swap |
| Debian tweaks | Non-default OS settings only; no ZRAM, firmware, repository pinning or kernel installation | Root mount exceptions, manual-only filesystem repairs, root SSH disabled, no unattended updates  |
| OpenMediaVault 8 | OMV package installation only plus disable OMV cron-apt; user configures OMV afterwards | Package transaction safe; networking and the installer-confirmed administrator account SSH/sudo work; root SSH disabled; OMV cron-apt is inactive |
| Docker | Official Docker engine, containerd, Buildx and Compose CLI | Packages installed, `docker.service` and `docker.socket` inactive/disabled until approval |

**All seven optional profiles are separately displayed and initially unchecked, in this exact menu order: Backports → Ensure 7.x kernel branch → Extended device support → ZRAM → Debian tweaks → OMV → Docker.** Debian tweaks is **independent of Ensure 7.x**; it neither requires nor installs a 7.x kernel, and must work with the default Debian kernel. ZRAM can be selected without Debian tweaks, but it **requires explicit selection of Ensure 7.x**. If Ensure 7.x is unchecked, offer to select it or deselect ZRAM. Ensure 7.x checks ordinary Debian repositories; if a suitable 7.x kernel is unavailable, offer to explicitly select Backports or stop/deselect the requesting profile. Backports remains at priority **100**, owns the reviewed eligible-package upgrade and cleanup; Ensure 7.x owns selective installation of kernel-related backported packages. No optional profile is selected automatically.

## Blocking verification issues

1. **Selective Backports compatibility versus OMV 8:** Debian's default Backports priority **100** replaces the revoked priority **900**. Check metapackage candidates and any explicitly selected backported dependencies; simulate selected OMV and Docker transactions. Do not create a global higher-priority pin.
2. **Dependency chain and kernel selection:** ZRAM **requires explicitly selected Ensure 7.x**, never auto-selects it. Ensure 7.x chooses the newest compatible 7.x and matching headers from standard repos if possible; otherwise asks to explicitly select Backports. Backports keeps **priority 100**, completes the reviewed full upgrade of eligible packages and separately reviewed autoremove/purge. Ensure 7.x then selectively requests only necessary kernel-related packages from Backports. Stop on incomplete upgrades, unapproved removals or conflicts. Verify moving metapackages and installed default kernel/headers.
3. **ZRAM API compatibility:** verify selected kernel and Debian generator support resident limit, compressed writeback, early device setup and dynamic backing-size measurement; inspect uploaded monitor for logic/errors.
4. **User-controlled swap partition, conditional role:** user creates swap in ordinary Debian Installer partitioning (16 GB suggested). Without ZRAM, use as conventional swap. With ZRAM, re-purpose the **same** partition exclusively for raw PARTUUID writeback and prevent normal swap activation. If absent and ZRAM selected, explicitly offer **return to partitioning** or **deselect ZRAM**. Validate partman stage/order, swap signatures, `/etc/fstab`, user confirmation and safe navigation before shipping.
5. **Emergency recovery:** ensure systemd *really enters* emergency mode for a failed ZRAM initialization, with usable local root credentials; test this in a disposable environment.
6. **OMV / SSH / network:** ensure OMV does not enable root SSH or block the installer-confirmed administrator account; check DHCP and DNS.
7. **OMV scheduled updates:** verify environment variable and Salt deploy method on exact OMV version; confirm cron-apt is disabled. Verify Debian APT unattended package installation separately.
8. **Installer GUI defaults and interaction:** [profile_defaults.conf](profile_defaults.conf) is the single canonical source for editable suggestions (hostname, username, empty domain, English/`en_US.UTF-8`, Spanish keyboard, `Europe/Berlin`, UTC RTC, DHCP and headless SSH/standard tasks). Validate mapping of symbolic keys to actual installer questions, on-screen editability, confirmation, account/sudo/root-password ordering and use even when Debian tweaks is unchecked. Do not put secrets, fixed disk targets or profile preselection in this file.
9. **Docker service suppression:** ensure packages install without starting daemon/socket, including during package maintainer scripts.
10. **Extended device support:** broad proactive firmware coverage was approved; its candidate inventory and microcode selection are in [10 Extended device support](10_extended_device_support.md). Final package transactions require simulation under the actual repository policy (Backports priority **100**, if selected), with explicit review of dependencies and removals.
11. **OS installation target selection:** require explicit confirmation of the installation disk and destructive partition writes; validate the selection procedure using disposable test disks.
12. **Installer image release:** verify boot modes, unsigned customized image provenance and USB integrity when media validation policy is finalized.
13. **Manual failure recovery:** induce critical optional-profile failures in disposable tests; verify installation stops, diagnostics can be retrieved and no snapshot/backup/rollback/reinstall action is performed automatically. Determine which logs survive failed installations and hard reboots.

## Deferred / still open

- **Broad firmware coverage approved under Extended device support:** candidate package names are documented; final installable set, dependencies, vendor-specific microcode selection and user confirmation **not yet finished**.
- Installation-media verification workflow (deferred to USB preparation).
- **Confirmed:** all seven optional profiles are **unchecked by default** and displayed Backports → Ensure 7.x → Extended device support → ZRAM → Debian tweaks → OMV → Docker. Validate empty selection; Debian tweaks working **without Ensure 7.x**, ZRAM explicitly requiring Ensure 7.x; Ensure 7.x asking for Backports when necessary; backports priority **100**; reviewed full upgrade, approved removals and post-upgrade autoremove/purge; all selected profile combinations. Never auto-select another profile.
- **Resolved:** if the user makes a swap partition and ZRAM is unselected, use ordinary swap; if ZRAM is selected, use the same partition exclusively as its raw backing. If no swap is created, ordinary Debian's no-swap warning applies; ZRAM must prompt to return or be deselected. Technical integration of the two roles remains unverified.
- **Resolved — no installer-managed snapshots, backups or rollback:** user explicitly declined all three. Failure handling is stop, preserve available diagnostics, and manual repair or reinstallation. Do not treat rollback as an outstanding feature.
- Exact device-independent partition labels or type GUID for raw ZRAM backing if special marking is needed.
- Whether/when Docker daemon should later be activated; OMV Compose and other services are separate later-phase decisions.
- **Resolved:** the global Backports priority-900 pin was revoked. Preserve Debian's default priority **100** and selectively install 7.x kernel packages when required; any deviation requires explicit approval.
- **Resolved:** Debian tweaks is **independent of Ensure 7.x kernel branch**. The kernel is installed only by the explicitly selected Ensure 7.x profile, not as a hidden Debian tweaks dependency.
- **Resolved:** native Debian Installer GUI defaults formerly described under Debian tweaks, including timezone and RTC, belong to [profile_defaults.conf](profile_defaults.conf) and native setup screens, not optional tweaks. Validate the exact mapping before release.
- All profile/script implementations must be reviewed before production.

## Failure policy and evidence

- **Critical selected-profile failure:** stop, preserve available logs, give diagnostics and leave recovery or reinstallation **manual**. No installer-generated snapshot, system-image backup, restore point, automatic rollback or fallback to a different profile; never falsely report success.
- **ZRAM init failure:** enter systemd emergency mode for local recovery, requiring a root password set during installation.
- **ZRAM monitor failure:** log and restart the monitor; do not independently trigger emergency mode.
- **Update installation:** user approval only (security included); no automatic reboots. Permitted package removals require explicit review and approval; after an approved full upgrade, separately review and approve `apt-get autoremove --purge` and any residual-configuration purges. Preserve the initially available stable fallback kernel.
- Keep logs of `apt-cache policy`, simulated transactions, profile selections, partition identification and installer exit status in the installer/build evidence bundle.

## Reference index

[01 Preparation](01_custom_cdd_preparation.md) · [02 Backports](02_backports_apt.md) · [09 Ensure 7.x](09_ensure_7x_kernel.md) · [10 Extended device support](10_extended_device_support.md) · [03 ZRAM](03_zram_writeback.md) · [04 Debian tweaks](04_debian_tweaks.md) · [06 OMV](06_openmediavault.md) · [07 Docker](07_docker.md) · [05 Base install](05_base_installation.md) · [GUI defaults](profile_defaults.conf)
