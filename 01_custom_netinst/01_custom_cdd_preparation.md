# 01 — Customized netinst / Simple-CDD preparation

**Status:** installation design, **not** a built or tested ISO. **Recorded:** 2026-11-14. **Provenance:** custom server Debian 13 server planning conversation and the request to document custom netinst preparation.

## Purpose

Build an amd64 Debian 13 (Trixie) installer USB using **Simple-CDD** (customized Debian installer). The installer is interactive wherever a native screen exists. Package installation is interactive wherever possible and automated otherwise; substantive custom configuration needs an appropriate review/confirmation mechanism.

The USB **supports UEFI and legacy BIOS**, but the server is intended to install in **UEFI/GPT** mode. Do **not** add an unsolicited BIOS-mode safeguard. The USB bootloader highlights **Graphical install** and waits indefinitely until Enter. Preserve text installer and rescue alternatives. The *installed* GRUB timeout is five seconds.

## Installer profile architecture

Simple-CDD supports selectable profiles, typically expressed using files such as `profiles/<name>.description`, `.packages`, `.preseed` and `.postinst`. The obligatory `default` profile contains common configuration; optional profiles should be independently selectable.

| Selectable profile | Guide | Scope |
|---|---|---|
| **Backports** | [02_backports_apt.md](02_backports_apt.md) | Enable Backports at **Debian default priority 100**; perform user-reviewed eligible-package upgrade and autoremove/purge cleanup |
| **Ensure 7.x kernel branch** | [09_ensure_7x_kernel.md](09_ensure_7x_kernel.md) | Use newest suitable Linux 7.x from standard repos, or request selective backported kernel packages when approved |
| **Debian tweaks** | [04_debian_tweaks.md](04_debian_tweaks.md) | Non-GUI Debian operating-system configuration, without hardware support or ZRAM |
| **Extended device support** | [10_extended_device_support.md](10_extended_device_support.md) | CPU microcode, additional device firmware, initramfs driver policy and weekly SSD TRIM validation |
| **ZSTD ZRAM writeback** | [03_zram_writeback.md](03_zram_writeback.md) | ZRAM, dedicated raw SSD backing and monitor; explicitly requires Ensure 7.x |
| **OpenMediaVault 8** | [06_openmediavault.md](06_openmediavault.md) | Optional OMV installation, approved cron-apt shutdown |
| **Docker** | [07_docker.md](07_docker.md) | Official Docker packages, daemon and socket inactive |

**Backports** is an independently selectable profile described in [02_backports_apt.md](02_backports_apt.md). It enables the repo at default priority **100** and owns the explicitly confirmed upgrade of eligible installed packages followed by reviewed autoremove/purge cleanup. **Ensure 7.x kernel branch** is a separate profile described in [09_ensure_7x_kernel.md](09_ensure_7x_kernel.md), and installs only kernel-related backported packages when stable repos lack eligible Linux 7.x. Normal installer choices are in [05_base_installation.md](05_base_installation.md).

**Approved default profile selection:** all **seven** optional profiles (**Backports**, **Ensure 7.x kernel branch**, **Debian tweaks**, **Extended device support**, **ZSTD ZRAM writeback**, **OpenMediaVault 8**, **Docker**) start **unchecked**. The installer must show all options and require the user to explicitly select and confirm each desired profile. Selecting none means base Debian only; no profile is silently added.

**Exact optional profile menu/execution order:** **Backports → Ensure 7.x kernel branch → Debian tweaks → Extended device support → ZRAM → OMV 8 → Docker**, skipping profiles not selected. This is an intentional installer-menu order; existing numbered documentation filenames are historical and need not indicate the menu order. **Debian tweaks is independent of Ensure 7.x**: it must configure the selected tweaks on Debian's default kernel when Ensure 7.x is unchecked. No kernel-package installation is performed by Debian tweaks.

**ZRAM is independent of Debian tweaks but depends on Ensure 7.x kernel branch:** if ZRAM is selected without Ensure 7.x, offer to **select Ensure 7.x** or **deselect ZRAM**. Ensure 7.x checks the newest eligible kernel from standard repositories; if none is suitable, offer to **select Backports** or stop/deselect the requesting profile. Never silently enable any profile. Backports is kept at priority 100; it performs the reviewed full-upgrade and cleanup, and the kernel profile requests only necessary backported kernel-related packages. Validate all transitions before producing the ISO.

## Canonical editable installer GUI defaults

The normal Debian Installer questions use **[profile_defaults.conf](profile_defaults.conf)** as the planning source of suggested defaults. It now contains:

- Editable example **hostname** and administrator **username**; an empty DNS domain.
- **English** installer language, **`en_US.UTF-8`** locale and **Spanish (Spain)** keyboard.
- **`Europe/Berlin`** time zone with the hardware real-time clock in **UTC**.
- Wired **DHCP** networking and the minimal/headless software selection: **SSH server + Standard system utilities**, no desktop.

The matching [`profile_defaults.conf.example`](profile_defaults.conf.example) is a reference example, not a second source of truth. No GUI-editable setting should be implemented only inside Debian tweaks. Prompt the user on the normal installer screens, allow edits, require confirmation, and propagate the confirmed values throughout the installed system. **Do not silently preseed answers, bypass installer screens or freeze values in profile post-install scripts**; the exact mapping from these symbolic config names to Debian Installer questions requires engineering validation.

**Do not store passwords, hashes, disk targets or selected-profile flags** in either defaults file. Separate non-GUI policies such as GRUB, journald and fsck remain in the optional Debian tweaks profile. CPU microcode, proactive firmware, initramfs driver support and weekly TRIM verification belong to the separate optional [Extended device support](10_extended_device_support.md) profile. The requested custom date/number display formats are **not** native locale/timezone GUI questions; they remain a documented, unverified implementation requirement.

## Planned build-host setup

On a compatible Debian build machine, check the installed tools and their versions before use:

```sh
sudo apt update
sudo apt install simple-cdd
build-simple-cdd --help
```

Provisional *source* layout (do not regard as already created):

```text
simple-cdd/
  simple-cdd.conf
  profiles/
    default.description
    default.preseed
    backports.description
    backports.postinst
    ensure-7x-kernel.description
    ensure-7x-kernel.postinst
    debian-tweaks.description
    debian-tweaks.packages
    debian-tweaks.postinst
    extended-device-support.description
    extended-device-support.packages
    extended-device-support.postinst
    openmediavault.description
    openmediavault.postinst
    docker.description
    docker.postinst
    zram-writeback.description
    zram-writeback.packages
    zram-writeback.postinst
```

Verify actual Simple-CDD syntax and how profile questions are presented in this release before producing the installer. **The user creates any swap partition manually in ordinary Debian Installer partitioning.** The selected ZRAM profile must later identify and re-purpose that same partition as **exclusive raw writeback backing**, preventing conventional swap initialization/activation; when ZRAM is not selected, the partition remains ordinary swap. The target example is 16 GB, but use the actual user-confirmed capacity and PARTUUID rather than requiring an automatically created partition. If ZRAM is selected and **no** swap partition exists, the ZRAM profile must require an explicit choice: **go back to partitioning to create one, or deselect ZRAM**. Never silently add/repartition a disk or proceed with ZRAM using no backing partition. Validate the menu navigation, partman formatting/activation timing, fstab treatment and explicit consent before implementation.

## Non-negotiable safeguards

1. **No unattended disk actions:** present OS installation target identification, partition creation, filesystem operations and final commit for manual confirmation. Never hard-code a device path such as `/dev/sda`.
2. **Interactive passwords:** prompt for the installer-confirmed administrator account's password; configure and verify sudo; then prompt for a **separate root password before first reboot**. No password or hash stored in the media.
3. **Repository trust:** official Debian binary repositories use signed Release metadata. Third-party sources must use verified, narrowly scoped signing keys. Do not bypass signature checks.
4. **Fail closed on selected profile errors:** a critical dependency, OMV, ZRAM, SSH/network or validation failure stops completion, preserves installer logs, and requests manual intervention; no silent fallback or false success.
5. **No unexpected configuration:** the user will manage OMV itself after first boot, except for the explicitly approved disabling of OMV's scheduled cron-apt job and preserving agreed SSH access controls.
6. **Reboot:** show Debian's standard completion screen, require manual **Continue** before first reboot.

## Build and release gates

- Verify original Debian source artifact and signatures/checksums; the exact overall verification workflow is **deferred**.
- Generate and verify output ISO and USB image; preserve UEFI, BIOS, graphical, text and rescue boot paths.
- Test each optional profile alone and in permitted combinations, including errors/rollback conditions.
- Test offline/failed repository behavior, third-party key checks, package resolution, root and sudo login, GRUB settings and correct target-disk selection.
- Confirm OMV does not reinstate root SSH access and does not block the installer-confirmed administrator account access.
- Test target-disk selection and destructive-operation confirmation in disposable virtual machines.
- Install Linux 7.x **in the target OS**, not necessarily in the running installer. Test the ZRAM kernel interfaces on the installed system.
- Do not call the image ready until [08_validation_and_pending.md](08_validation_and_pending.md) has been resolved.

## References

- [Simple-CDD package](https://packages.debian.org/trixie/simple-cdd)
- [Simple-CDD profiles explained](https://www.debian.org/doc/manuals/debian-handbook/sect.automated-installation.en.html)
- [Debian 13 installation manual](https://www.debian.org/releases/trixie/installmanual)
