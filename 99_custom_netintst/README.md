# 99 — How to build the custom Debian netinst

This section is a **construction manual for the custom installer source**, not an account of clicking through the installer. It explains **what files to create or edit, which code is needed, how the pieces connect, and how to validate the resulting ISO**.

For commands to execute on a **normal already installed Debian 13 system**, use the independent [01–08 server setup guides](../README.md). In particular, do not run the installer profile shell modules on a running server: they depend on Debian Installer's `/target`, `/cdrom`, `anna-install` and Debconf environment.

## How the custom installer is assembled

1. **[01 — Create the Simple-CDD project and build image](01_custom_cdd_preparation.md):** build-host tools, `simple-cdd.conf`, media inputs, editable defaults, two-stage build and ISO checks.
2. **[05 — Implement the installation framework](05_base_installation.md):** preseed hooks, original seven-checkbox selection, Debconf confirmation, shared dispatcher, completion guard and logging.
3. **[00 — Construct a selectable profile](00_profile_construction.md):** the common file pattern and helper API used by each feature.
4. **Implement the individual features** using the recipes below; each explains the real source and includes implementation excerpts that can be reproduced or modified.
5. **[08 — Validate what you built](08_validation_and_pending.md):** syntax, ISO staging, GUI/text VM installation, failures and first boot.

| Build guide | Source you will construct |
| --- | --- |
| [02 — Backports](02_backports_apt.md) | Signed source, APT priority checks, reviewed upgrades and cleanup |
| [09 — Linux 7.x](09_ensure_7x_kernel.md) | Select a viable suite, validate image/header pair, update boot |
| [10 — Firmware](10_extended_device_support.md) | Firmware inventory, safe package selection, original license dialogs |
| [03 — ZRAM writeback](03_zram_writeback.md) | Native udeb disk discovery, approvals, GPT conversion, target provisioning |
| [04 — Debian tweaks](04_debian_tweaks.md) | Selected-only target GRUB, ext4, SSH and update policy |
| [06 — OMV 8](06_openmediavault.md) | Signed OMV package source, target admin access, OMV update policy |
| [07 — Docker](07_docker.md) | Official Docker source, signed packages, safe installer execution |

**Important distinction:** the scripts in [`my-cdd/installer/`](my-cdd/installer/) are the **actual versioned implementation**. These how-tos explain how it was constructed and how to change it—not instructions to re-run that code on the target. Read the documented steps first; links to source are for auditing exact details.

**Status:** the source code exists, but a full post-refactor ISO/VM/first-boot validation is still outstanding. Earlier design notes and failures are retained in [history/](history/).
