# DCF1007 — Customized Debian 13 netinst USB

**Project status:** documented installation plan, **not yet a built or tested ISO**. **Updated:** 2026-11-14. **Provenance:** DCF1007 home-server installation decisions and requested GitHub documentation structure.

Prepare an interactive, Simple-CDD-based **Debian 13 (Trixie), amd64** installation USB for `dcf1007-server`. The machine has a dedicated **256 GB system SSD**, **32 GB RAM** and nine NAS HDDs that must not be modified by the Debian system installer.

The USB supports UEFI and BIOS booting, highlights **Graphical install**, and waits for Enter; text-based installation and rescue remain available. The intended installed OS is **UEFI/GPT**, minimal/headless, with SSH and Standard system utilities. Disk selection and partition writes are manually confirmed, and both `david` and a separate local root password are entered interactively.

## Documentation map

| No. | Guide | Purpose |
|---|---|---|
| **01** | [Custom netinst / Simple-CDD preparation](01_custom_cdd_preparation.md) | Prepare the installer, profile menu, credentials, boot modes and test procedure |
| **02** | [Activate trixie-backports and configure APT priority](02_backports_apt.md) | Official repositories, provisional global backports pin **900**, security/compatibility checks |
| **03** | [Base Debian installation](03_base_installation.md) | Choices made through normal Debian Installer screens |
| **04** | [**Debian tweaks** profile](04_debian_tweaks.md) | All non-menu Debian customizations; **excludes ZRAM** |
| **05** | [**OpenMediaVault 8** profile](05_openmediavault.md) | OMV installation; disable its entire scheduled cron-apt update workflow |
| **06** | [**Docker** profile](06_docker.md) | Docker Engine, containerd, Buildx, Compose CLI; daemon/socket inactive until approval |
| **07** | [**ZSTD ZRAM writeback** profile](07_zram_writeback.md) | RAM-adaptive compressed swap backed by dedicated 16 GB raw SSD partition |
| **08** | [Validation and unresolved choices](08_validation_and_pending.md) | Failure policy, dependency checks, open items and release gates |

**Select independently at install time:** Debian tweaks, OpenMediaVault 8, Docker and ZSTD ZRAM compressed writeback. The **02 backports guide is not an additional selectable profile**: its non-menu APT policy belongs to the **Debian tweaks** profile. Normal Debian Installer settings are separate.

## Key constraints

- **No unapproved actions on NAS HDDs.** Whether to physically disconnect them is deferred.
- Root filesystem: **ext4**, 5% reserved blocks, `noatime,errors=panic`, ordinary ordered journaling; weekly TRIM; no LVM, encryption or separate `/boot`.
- Installer EFI partition **1 GiB**; ZRAM option requires a **dedicated 16 GB raw PARTUUID partition**, **not ordinary swap**. SSD layout when ZRAM is not selected still needs a decision.
- Kernel 7.x and corresponding headers from backports before first reboot; stable kernel available initially. GRUB menu visible **5 seconds**, newest kernel by default.
- `david`: sudo and initial SSH password login. Separate local root password before first reboot; root SSH login prohibited.
- **Manual software updates and reboots only**. Explicitly disable Debian unattended upgrades in Debian tweaks, and disable OMV's scheduled cron-apt when OMV is selected.
- Docker packages install if selected, **without activating Docker daemon/socket** during installation or on first boot.
- If a selected profile fails critical checks, **stop** and retain logs; no silent alternative or false success.
- ZRAM initialization failure must enter emergency mode; ZRAM monitor failure must be logged and retried without emergency mode.
- APT backports priority **900** is **provisional** and potentially incompatible with OMV. No ISO release or automatic adjustment until compatibility is verified and approved.

## Scope and provenance

These pages distinguish **approved user choices** from **engineering proposals requiring validation**. This repository currently contains **documentation only** for this plan; it does not certify a prepared USB, tested Simple-CDD profile scripts or a successful first boot.

**Primary sources:** user's extended Debian 13 installation planning conversation and uploaded `zram_zstd_writeback_design(1).md`; official Debian, APT, Simple-CDD, Linux, Docker and OpenMediaVault documentation linked in the numbered pages.

Start with [01 — Custom installer preparation](01_custom_cdd_preparation.md), then [02 — Backports APT](02_backports_apt.md). Track blockers in [08 — Validation](08_validation_and_pending.md).
