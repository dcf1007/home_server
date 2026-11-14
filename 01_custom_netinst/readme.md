# Customized Debian 13 netinst USB

**Project status:** documented installation plan, **not yet a built or tested ISO**. **Updated:** 2026-11-14. **Provenance:** custom server home-server installation decisions and requested GitHub documentation structure.

Prepare an interactive, Simple-CDD-based **Debian 13 (Trixie), amd64** installation USB for a configurable hostname. The example hardware has a **256 GB system SSD** and **32 GB RAM**; these are illustrative, not universal requirements. Confirm actual hardware and the OS installation disk in the installer.

The USB supports UEFI and BIOS booting, highlights **Graphical install**, and waits for Enter; text-based installation and rescue remain available. The intended installed OS is **UEFI/GPT**, minimal/headless, with SSH and Standard system utilities. Disk selection and partition writes are manually confirmed, and both the installer-confirmed administrator account and a separate local root password are entered interactively.

## Documentation map

| No. | Guide | Purpose |
|---|---|---|
| **01** | [Custom netinst / Simple-CDD preparation](01_custom_cdd_preparation.md) | Build steps, installation profile menu and confirmations |
| **02** | [**Backports** selectable profile](02_backports_apt.md) | Repository activation, provisional priority 900, **reviewed full upgrade of eligible installed packages** |
| **03** | [**ZSTD ZRAM writeback** profile](03_zram_writeback.md) | ZSTD compressed swap with dedicated raw SSD backing |
| **04** | [**Debian tweaks** profile](04_debian_tweaks.md) | Debian customization outside normal installer screens; **no ZRAM** |
| **05** | [Base Debian installation](05_base_installation.md) | Normal installer questions, partitioning and account confirmation |
| **06** | [**OpenMediaVault 8** profile](06_openmediavault.md) | Optional OMV install and disabled cron-apt scheduling |
| **07** | [**Docker** profile](07_docker.md) | Docker packages; daemon/socket disabled pending approval |
| **08** | [Validation and unresolved choices](08_validation_and_pending.md) | Integration checks, failure handling and remaining choices |

[Editable installation identity defaults](profile_defaults.conf.example)

**All five optional profiles start unchecked:** **Backports**, ZRAM, Debian tweaks, OpenMediaVault 8 and Docker. The user must explicitly select and confirm any desired component. **ZRAM is independent of Debian tweaks**. ZRAM and Debian tweaks require an eligible Linux 7.x kernel; if it is unavailable from ordinary Debian repositories, offer **select Backports explicitly or deselect/stop the requesting profile**. The **Backports profile alone** enables `trixie-backports`, configures provisional APT priority 900, performs the reviewed full upgrade and verifies completion before dependent profiles run. **Never silently enable another profile.** Normal Debian Installer settings are separate.

## Key constraints

- **Manual OS disk selection:** verify the target device and explicitly confirm destructive partitioning operations before proceeding.
- Root filesystem: **ext4**, 5% reserved blocks, `noatime,errors=panic`, ordinary ordered journaling; weekly TRIM; no LVM, encryption or separate `/boot`.
- Installer EFI partition **1 GiB**; the user may create a swap partition in manual partitioning (**16 GB suggested**). **Without ZRAM**, use it as ordinary swap; **with ZRAM**, re-purpose that same partition exclusively as raw PARTUUID-backed writeback storage, never ordinary swap. If none was created and ZRAM is selected, offer to return to partitioning or deselect ZRAM. No swap and no ZRAM is permitted after Debian Installer's normal warning.
- ZRAM and Debian tweaks require the **newest eligible Linux 7.x kernel** and matching headers, without pinning a fixed version. Check default Debian repositories first; when unavailable, require explicit selection of **Backports**. **Only the Backports profile** performs the explicitly confirmed full upgrade of eligible installed packages before dependent profiles continue. Stop on unresolved dependency/removal conflicts. Retain a stable fallback kernel initially. Installed GRUB menu is visible for **5 seconds**, newest kernel by default.
- Debian tweaks includes **broad proactive firmware coverage** (networking, storage, wireless, graphics, audio and others) in addition to Debian's automatic firmware detection. Candidate package inventory is documented in [04 Debian tweaks](04_debian_tweaks.md), subject to final APT simulation and confirmation.
- the installer-confirmed administrator account: sudo and initial SSH password login. Separate local root password before first reboot; root SSH login prohibited.
- **Manual software updates and reboots only**. Explicitly disable Debian unattended upgrades in Debian tweaks, and disable OMV's scheduled cron-apt when OMV is selected.
- Docker packages install if selected, **without activating Docker daemon/socket** during installation or on first boot.
- The ZRAM profile alone sets `vm.swappiness=100` using `/etc/sysctl.d/90-zram-swappiness.conf`; no ZRAM-specific swappiness change when the profile is unchecked.
- If a selected profile fails critical checks, **stop** and retain logs; no silent alternative or false success.
- ZRAM initialization failure must enter emergency mode; ZRAM monitor failure must be logged and retried without emergency mode.
- **If Backports is selected**, its provisional global APT priority **900** may be incompatible with OMV. No ISO release or automatic pin adjustment until compatibility is verified and approved.

## Scope and provenance

These pages distinguish **approved user choices** from **engineering proposals requiring validation**. This repository currently contains **documentation only** for this plan; it does not certify a prepared USB, tested Simple-CDD profile scripts or a successful first boot.

**Primary sources:** user's extended Debian 13 installation planning conversation and uploaded `zram_zstd_writeback_design(1).md`; official Debian, APT, Simple-CDD, Linux, Docker and OpenMediaVault documentation linked in the numbered pages.

Start with [01 — Custom installer preparation](01_custom_cdd_preparation.md), then [02 — Backports APT](02_backports_apt.md). Track blockers in [08 — Validation](08_validation_and_pending.md). Every proposed hostname and administrator username is an editable default, not a fixed installation requirement.
