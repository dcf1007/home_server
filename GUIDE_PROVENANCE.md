# Guide source provenance

**Creation date:** 2026-11-16 (Europe/Berlin).  
**Nearest user prompt:** “this repo is a full guide on how i set up my home NAS (+more) server. the final result is a custom install debian, but i want each step applicable on a freshly installed system individually as you would normally do it. therefore rename the 01_custom_netinst to 99_custom_netintst and add the various things we have been doing with their own howtos as 01 02 03 etc. these should take the easiest approach possible, so things we have modified to make them udeb compatible can follow the easier procedures with the tools of a full debian system. This refactoring might also move content from the actual guides, so the netinst guide focuses on that, how to make things viable within the netinst.”

**Source revision:** `dcf1007/home_server`, `main` commit `96ead557168a61e230c6466c8d037754622603ad` (merged PR #11).  
**Modification type:** documentation reorganization and additions; all existing Simple-CDD executable source, profiles, build variables, Debconf templates and staged ISO assets relocated **unchanged**.

## Content mapping

| New active chapter | Primary original source |
| --- | --- |
| `01_base_debian/` | `01_custom_netinst/05_base_installation.md`, `profile_defaults.conf` |
| `02_backports/` | `02_backports_apt.md`, `profile-backports.sh`, signed Backports template |
| `03_kernel_7x/` | `09_ensure_7x_kernel.md`, `profile-kernel.sh` |
| `04_extended_device_support/` | `10_extended_device_support.md`, `profile-firmware.sh`, firmware candidate list (same blob copied) |
| `05_zram_writeback/` | `03_zram_writeback.md`, `profile-zram.sh`, `zram-selection.sh`, five original design assets (same blobs copied) |
| `06_debian_tweaks/` | `04_debian_tweaks.md`, `profile-tweaks.sh` |
| `07_openmediavault/` | `06_openmediavault.md`, `profile-omv.sh`; update-policy helper adapted from original Python subroutine |
| `08_docker/` | `07_docker.md`, `profile-docker.sh` |
| `99_custom_netintst/` | Entire previous `01_custom_netinst/` subtree, including all installer files, moved without executable changes |

Every former numbered planning document and landing page is retained in [99_custom_netintst/history](99_custom_netintst/history/), preserving the original text and uploaded ZRAM design. Its original chronology is **historical**, including superseded status and techniques.

The post-install commands were made independently runnable on a normal Debian installation; the simplified OMV quick install follows the vendor route, Docker follows its official signed apt repository, and ZRAM uses full installed-system `sgdisk` and `wipefs` rather than udeb-specific workarounds.

## External technical references checked during extraction

- [Debian 13 Backports instructions](https://backports.debian.org/Instructions/)
- [OpenMediaVault 8 installer on Debian](https://www.openmediavault.org/install) and [official Debian-specific guidance](https://docs.openmediavault.org/en/stable/installation/on_debian.html)
- [Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)
- [Linux kernel ZRAM](https://www.kernel.org/doc/html/latest/admin-guide/blockdev/zram.html) and [zram-generator configuration](https://github.com/systemd/zram-generator/blob/main/man/zram-generator.conf.md)
- [Debian wipefs](https://manpages.debian.org/trixie/util-linux/wipefs.8.en.html) and [sgdisk](https://manpages.debian.org/trixie/gdisk/sgdisk.8.en.html)

## Validation boundary

Links and file-layout identity are checked statically where possible. **No new ISO build, Debian Installer run, physical disk conversion or first boot is claimed** for this documentation reorganization. The original installer functionality remains subject to the [active validation gates](99_custom_netintst/08_validation_and_pending.md).

All new content is committed directly into the repository; no user-facing sandbox artifact is created for this change. Git retains the previous files by history, and the separate archival Markdown copies preserve their text.
