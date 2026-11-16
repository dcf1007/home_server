# 99 — Build and use the custom Debian 13 netinst image

This is the **optional final chapter** of the home-server guide. The first eight chapters describe how to configure an **already installed Debian system** using normal package managers, editors and service controls. This chapter describes how the same changes are performed **during installation**, inside Debian Installer's more limited environment.

## Step 1 — Decide which approach you need

- **Ordinary Debian:** use [01–08](../README.md). No custom image is needed; each feature can be applied individually.
- **Custom installer:** build this ISO if you want to choose the same seven optional operations in the Debian Installer interface and have them applied before first boot.

The installer is intentionally **not** just a post-install shell script: early Debconf screens, ISO-staged packages, udebs, partition safety, target-system execution and failure handling must work while the machine is still being installed.

## Step 2 — Prepare and build the ISO

Follow the actual build-host instructions in [01 — Build preparation](01_custom_cdd_preparation.md). There you will find the dependencies, editable installer defaults, build commands, expected ISO location and checks.

## Step 3 — Boot the image and make normal Debian decisions

The expected installation flow is described in [05 — Base installation](05_base_installation.md). It includes the custom **seven-checkbox selection** and summary, normal partitioning and account screens, editable defaults, tasksel, late-stage approvals and success/failure indication.

All seven optional profiles are **unchecked by default**. Choosing ZRAM writeback requires separately selecting **Ensure Linux 7.x**. No disk, password or optional package set is silently selected.

## Step 4 — Understand exactly what each selected profile does

The linked pages describe the **actual ordered steps, user decisions, installer actions and verification checks**. You do not need to open the shell module to understand the procedure:

| Order | During the installer | Compare with ordinary Debian |
| --- | --- | --- |
| 1 | [Backports: sources, upgrades and removals](02_backports_apt.md) | [02](../02_backports/README.md) |
| 2 | [Linux 7.x: candidate selection, image and headers](09_ensure_7x_kernel.md) | [03](../03_kernel_7x/README.md) |
| 3 | [Extended device support: microcode, firmware and licenses](10_extended_device_support.md) | [04](../04_extended_device_support/README.md) |
| 4 | [ZRAM: select, confirm and convert one partition](03_zram_writeback.md) | [05](../05_zram_writeback/README.md) |
| 5 | [Debian tweaks: boot, mount, SSH and updates](04_debian_tweaks.md) | [06](../06_debian_tweaks/README.md) |
| 6 | [OMV 8: signed installation and update policy](06_openmediavault.md) | [07](../07_openmediavault/README.md) |
| 7 | [Docker: official signed packages and normal services](07_docker.md) | [08](../08_docker/README.md) |

The installer runs **only the selected profiles** in this fixed order. It displays the complete APT simulations and requires default-No approvals where appropriate.

## Step 5 — Test before using important disks

Use [08 — Validation](08_validation_and_pending.md) to test the ISO in a disposable VM. In particular, native ZRAM probing/conversion, first-boot writeback and installer completion behavior have **not** been validated end to end.

Source code is retained under [my-cdd/](my-cdd/) for reproducibility, with build input in [profiles](my-cdd/profiles/), [installer modules](my-cdd/installer/) and [staged files](my-cdd/scripts/). Those files implement the **steps documented in the guides**, rather than being a substitute for the guide.

Previous detailed plans, superseded fixes and observed failures are preserved in [history](history/).
