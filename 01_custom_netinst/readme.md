# Customized Debian 13 netinst USB

**Project status:** documented installation plan, **not yet a built or tested ISO**. **Updated:** 2026-11-14. **Provenance:** custom server home-server installation decisions and requested GitHub documentation structure.

Prepare an interactive, Simple-CDD-based **Debian 13 (Trixie), amd64** installation USB for a configurable hostname. The example hardware has a **256 GB system SSD** and **32 GB RAM**; these are illustrative, not universal requirements. Confirm actual hardware and the OS installation disk in the installer.

The USB supports UEFI and BIOS booting, highlights **Graphical install**, and waits for Enter; text-based installation and rescue remain available. The intended installed OS is **UEFI/GPT**, minimal/headless, with SSH and Standard system utilities. Disk selection and partition writes are manually confirmed, and both the installer-confirmed administrator account and a separate local root password are entered interactively.

## Documentation map

The table follows the **actual optional installer-profile menu order**, not the historical filenames' numbers. Every optional profile is initially unchecked.

| Guide | Purpose |
|---|---|
| [01 — Custom netinst / Simple-CDD preparation](01_custom_cdd_preparation.md) | Installer build process and profile menu architecture |
| **[02 — Backports](02_backports_apt.md)** | Optional repository at default priority 100; reviewed upgrade and cleanup |
| **[09 — Ensure 7.x kernel branch](09_ensure_7x_kernel.md)** | Newest eligible Linux 7.x and headers; request Backports explicitly if necessary |
| **[04 — Debian tweaks](04_debian_tweaks.md)** | Kernel-independent GRUB, filesystem/recovery, journaling, SSH and manual-update policies |
| **[10 — Extended device support](10_extended_device_support.md)** | Vendor microcode, broad device firmware, initramfs driver defaults and SSD TRIM checks |
| **[03 — ZSTD ZRAM writeback](03_zram_writeback.md)** | ZSTD compressed swap and raw PARTUUID writeback backing; requires Ensure 7.x |
| **[06 — OpenMediaVault 8](06_openmediavault.md)** | Optional OMV packages and disabled cron-apt scheduling |
| **[07 — Docker](07_docker.md)** | Docker packages; daemon/socket inactive |
| [05 — Base Debian installation](05_base_installation.md) | Native installer GUI, disk partitioning and account confirmation |
| [08 — Validation and pending](08_validation_and_pending.md) | Integration checks and remaining choices |

**[Canonical editable installer GUI defaults](profile_defaults.conf)** · [Reference example](profile_defaults.conf.example)

**All seven optional profiles start unchecked, in this menu order:** **Backports → Ensure 7.x kernel branch → Debian tweaks → Extended device support → ZRAM → OpenMediaVault 8 → Docker**. The user must explicitly select and confirm every component. **Debian tweaks remains fully functional on Debian's default kernel, independent of Ensure 7.x.** **ZRAM depends on Ensure 7.x**, but remains independent of Debian tweaks. If Ensure 7.x is unchecked when ZRAM is selected, ask to **select Ensure 7.x or deselect ZRAM**. Ensure 7.x first searches the normal Debian repositories; if Linux 7.x is unavailable, ask to **select Backports or cancel the kernel-dependent profile**. Backports is maintained at Debian's default priority **100**; its profile alone owns the reviewed full upgrade and cleanup, while Ensure 7.x installs **only kernel-related packages** selectively from Backports when needed. No other profile is silently selected.

## Key constraints

- **Installer GUI settings:** suggested hostname, administrator username, local domain, installer language/locale, Spanish keyboard, `Europe/Berlin` timezone, UTC RTC, DHCP and tasksel selections are centralized in [profile_defaults.conf](profile_defaults.conf), editable and confirmed in the native installer regardless of optional profiles. No passwords or disk target are stored.
- **Manual OS disk selection:** verify the target device and explicitly confirm destructive partitioning operations before proceeding.
- Root filesystem: **ext4**, 5% reserved blocks, `noatime,errors=panic`, ordinary ordered journaling; no LVM, encryption or separate `/boot`. Debian tweaks covers filesystem policy; Extended device support verifies Debian's weekly TRIM timer.
- Installer EFI partition **1 GiB**; the user may create a swap partition in manual partitioning (**16 GB suggested**). **Without ZRAM**, use it as ordinary swap; **with ZRAM**, re-purpose that same partition exclusively as raw PARTUUID-backed writeback storage, never ordinary swap. If none was created and ZRAM is selected, offer to return to partitioning or deselect ZRAM. No swap and no ZRAM is permitted after Debian Installer's normal warning.
- The separately selected **Ensure 7.x kernel branch** profile installs the **newest eligible Linux 7.x image and matching headers**, without a fixed version lock. If stable repositories do not provide 7.x, it requests **explicit selection of Backports** and then only the necessary backported kernel-related packages. **Backports** performs an explicitly approved normal full upgrade of all eligible installed packages under priority **100**, followed by separately reviewed **autoremove/purge cleanup**. Removals require review/approval; preserve the stable fallback kernel initially. Installed GRUB menu remains visible for **5 seconds**, defaulting to the newest kernel.
- When **Extended device support** is selected, it installs the reviewed CPU-vendor microcode and **broad proactive firmware** (networking, storage, wireless, graphics, audio and others), and verifies initramfs driver policy and weekly SSD TRIM. The package inventory is in [10 Extended device support](10_extended_device_support.md), subject to APT simulation and explicit approval. Debian Installer's standard firmware detection remains available with this option unchecked.
- the installer-confirmed administrator account: sudo and initial SSH password login. Separate local root password before first reboot; root SSH login prohibited.
- **Manual software updates and reboots only**. Explicitly disable Debian unattended upgrades in Debian tweaks, and disable OMV's scheduled cron-apt when OMV is selected.
- Docker packages install if selected, **without activating Docker daemon/socket** during installation or on first boot.
- The ZRAM profile alone sets `vm.swappiness=100` using `/etc/sysctl.d/90-zram-swappiness.conf`; no ZRAM-specific swappiness change when the profile is unchecked.
- If a selected profile fails critical checks, **stop** and retain logs; no silent alternative or false success.
- ZRAM initialization failure must enter emergency mode; ZRAM monitor failure must be logged and retried without emergency mode.
- **Backports uses the default priority 100, not 900.** No blanket preference for backported packages. Explicit kernel selections and necessary dependencies still require APT compatibility validation, particularly with OMV.

## Scope and provenance

These pages distinguish **approved user choices** from **engineering proposals requiring validation**. This repository currently contains **documentation only** for this plan; it does not certify a prepared USB, tested Simple-CDD profile scripts or a successful first boot.

**Primary sources:** user's extended Debian 13 installation planning conversation and uploaded `zram_zstd_writeback_design(1).md`; official Debian, APT, Simple-CDD, Linux, Docker and OpenMediaVault documentation linked in the numbered pages.

Start with [01 — Custom installer preparation](01_custom_cdd_preparation.md), then [02 — Backports APT](02_backports_apt.md). Track blockers in [08 — Validation](08_validation_and_pending.md). Every proposed hostname and administrator username is an editable default, not a fixed installation requirement.
