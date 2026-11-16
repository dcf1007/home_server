# Guide source provenance

**Current documentation revision date:** 2026-11-16 (Europe/Berlin).

**Nearest user prompt:** “in omv don't create external python scripts to do the tasks. one should do them by onelselves. also in the netinst way, i want the steps described in the guide, not just referenced to the profile sh script.”

**What changed:**
- Removed the standalone `07_openmediavault/disable-automatic-updates.py` helper and replaced that part of the OMV how-to with **manual OMV 8 web-interface settings**, explicit read-only database verification, Debian APT configuration editing and OMV Salt deployment when required.
- Expanded the live `99_custom_netintst/` guides to describe **what the installer does step by step**, including choices, APT approvals, firmware licenses, ZRAM disk operations, target service policy, and post-install verification. Profile source links remain only as implementation references.
- Kept the actual `my-cdd` installer shell modules, existing inline OMV database maintenance logic, seven profile choices, ZRAM assets, firmware inventory and ISO build behavior **unchanged**.
- Kept previous historical Markdown planning under `99_custom_netintst/history/`. The prior standalone OMV helper is recoverable through Git history if its old provenance needs inspection.

**Original restructuring basis:** `dcf1007/home_server` `main` at `96ead557168a61e230c6466c8d037754622603ad` (merged PR #11), followed by the organizational and readability revisions. The original Simple-CDD project was moved from `01_custom_netinst/` to `99_custom_netintst/` without changing the installer executables.

## Current chapter map

| Ordinary Debian human how-to | Netinst adaptation |
| --- | --- |
| [01 Base Debian](01_base_debian/README.md) | [Native screens and late stages](99_custom_netintst/05_base_installation.md) |
| [02 Backports](02_backports/README.md) | [Installer APT procedure](99_custom_netintst/02_backports_apt.md) |
| [03 Kernel 7.x](03_kernel_7x/README.md) | [Suite selection, kernel and headers](99_custom_netintst/09_ensure_7x_kernel.md) |
| [04 Firmware](04_extended_device_support/README.md) | [Complete license/omission flow](99_custom_netintst/10_extended_device_support.md) |
| [05 ZRAM writeback](05_zram_writeback/README.md) | [Full partition conversion](99_custom_netintst/03_zram_writeback.md) |
| [06 Debian tweaks](06_debian_tweaks/README.md) | [Selected target file changes](99_custom_netintst/04_debian_tweaks.md) |
| [07 OMV 8](07_openmediavault/README.md) | [Selected target OMV installation and policy](99_custom_netintst/06_openmediavault.md) |
| [08 Docker](08_docker/README.md) | [Signed Docker installation](99_custom_netintst/07_docker.md) |

## Verification boundary

These edits are **documentation-only plus removal of the unused standalone OMV helper**. No ISO was rebuilt, no installer was run, no OMV 8 GUI configuration was clicked on a live system, and no ZRAM partition or hardware was changed. The step-by-step descriptions are derived from the actual tracked `my-cdd` profile source and Debian/OMV/Docker documentation; runtime claims still require the [VM test plan](99_custom_netintst/08_validation_and_pending.md).
