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
| **Extended device support** | [10_extended_device_support.md](10_extended_device_support.md) | CPU microcode and additional proactively installed device firmware |
| **ZSTD ZRAM writeback** | [03_zram_writeback.md](03_zram_writeback.md) | ZRAM with raw writeback backing and monitor; explicitly requires Ensure 7.x |
| **Debian tweaks** | [04_debian_tweaks.md](04_debian_tweaks.md) | Only non-default Debian operating-system adjustments; independent of Ensure 7.x |
| **OpenMediaVault 8** | [06_openmediavault.md](06_openmediavault.md) | Optional OMV installation, approved cron-apt shutdown |
| **Docker** | [07_docker.md](07_docker.md) | Official Docker packages, daemon and socket inactive |

**Backports** is an independently selectable profile described in [02_backports_apt.md](02_backports_apt.md). It enables the repo at default priority **100** and owns the explicitly confirmed upgrade of eligible installed packages followed by reviewed autoremove/purge cleanup. **Ensure 7.x kernel branch** is a separate profile described in [09_ensure_7x_kernel.md](09_ensure_7x_kernel.md), and installs only kernel-related backported packages when stable repos lack eligible Linux 7.x. Normal installer choices are in [05_base_installation.md](05_base_installation.md).

**Approved default profile selection:** all **seven** optional profiles (**Backports**, **Ensure 7.x kernel branch**, **Extended device support**, **ZSTD ZRAM writeback**, **Debian tweaks**, **OpenMediaVault 8**, **Docker**) start **unchecked**. The installer must show all options and require the user to explicitly select and confirm each desired profile. Selecting none means base Debian only; no profile is silently added.

**Exact optional profile menu/execution order:** **Backports → Ensure 7.x kernel branch → Extended device support → ZRAM → Debian tweaks → OMV 8 → Docker**, skipping profiles not selected. This is an intentional installer-menu order; existing numbered documentation filenames are historical and need not indicate the menu order. **Debian tweaks is independent of Ensure 7.x**: it must configure the selected tweaks on Debian's default kernel when Ensure 7.x is unchecked. No kernel-package installation is performed by Debian tweaks.

**ZRAM is independent of Debian tweaks but depends on Ensure 7.x kernel branch:** if ZRAM is selected without Ensure 7.x, offer to **select Ensure 7.x** or **deselect ZRAM**. Ensure 7.x checks the newest eligible kernel from standard repositories; if none is suitable, offer to **select Backports** or stop/deselect the requesting profile. Never silently enable any profile. Backports is kept at priority 100; it performs the reviewed full-upgrade and cleanup, and the kernel profile requests only necessary backported kernel-related packages. Validate all transitions before producing the ISO.

## Canonical editable installer GUI defaults

The normal Debian Installer questions use **[profile_defaults.conf](profile_defaults.conf)** as the planning source of suggested defaults. It now contains:

- Editable example **hostname** and administrator **username**; an empty DNS domain.
- **English** installer language, **`en_US.UTF-8`** locale and **Spanish (Spain)** keyboard.
- **`Europe/Berlin`** time zone with the hardware real-time clock in **UTC**.
- Wired **DHCP** networking and the minimal/headless software selection: **SSH server + Standard system utilities**, no desktop.

The matching [`profile_defaults.conf.example`](profile_defaults.conf.example) is a reference example, not a second source of truth. No GUI-editable setting should be implemented only inside Debian tweaks. Prompt the user on the normal installer screens, allow edits, require confirmation, and propagate the confirmed values throughout the installed system. **Do not silently preseed answers, bypass installer screens or freeze values in profile post-install scripts**; the exact mapping from these symbolic config names to Debian Installer questions requires engineering validation.

**Do not store passwords, hashes, disk targets or selected-profile flags** in either defaults file. Only non-default boot, filesystem, recovery, SSH and update-policy settings remain in the optional Debian tweaks profile. CPU microcode and additional proactive firmware belong to the separate optional [Extended device support](10_extended_device_support.md) profile.

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

Verify actual Simple-CDD syntax and how profile questions are presented in this release before producing the installer. **The user creates any swap partition manually in ordinary Debian Installer partitioning.** **At the start of the selected ZRAM profile execution**, its first task is to discover and positively identify the user-created swap partition; **immediately after explicit confirmation**, convert only that partition to GPT **8300**, PARTLABEL **`zram-writeback`**, raw/unformatted writeback backing, with no independent swap activation. **If the selected partition is already active as swap, request explicit consent for a targeted `swapoff` after checking memory safety and proceed only upon successful, verified deactivation; otherwise stop before changing the partition.** Do this before other ZRAM provisioning or first boot, not in the normal partitioner. When ZRAM is not selected, the partition remains ordinary swap. The target example is 16 GB, but use the actual user-confirmed capacity and PARTUUID rather than requiring an automatically created partition. If ZRAM is selected and **no** swap partition exists, the ZRAM profile must require an explicit choice: **go back to partitioning to create one, or deselect ZRAM**. Never silently add/repartition a disk or proceed with ZRAM using no backing partition. Validate the menu navigation, partman formatting/activation timing, fstab treatment and explicit consent before implementation.

## Non-negotiable safeguards

1. **No unattended disk actions:** present OS installation target identification, partition creation, filesystem operations and final commit for manual confirmation. Never hard-code a device path such as `/dev/sda`.
2. **Interactive passwords:** prompt for the installer-confirmed administrator account's password; configure and verify sudo; then prompt for a **separate root password before first reboot**. No password or hash stored in the media.
3. **Repository trust:** official Debian binary repositories use signed Release metadata. Third-party sources must use verified, narrowly scoped signing keys. Do not bypass signature checks.
4. **Fail closed on selected profile errors:** a critical dependency, OMV, ZRAM, SSH/network or validation failure stops completion, preserves installer logs, and requests manual intervention; no silent fallback or false success. **No installer-managed snapshots, backup images, automatic rollback or automatic restoration.** Recovery is explicitly manual, including repair or reinstallation.
5. **No unexpected configuration:** the user will manage OMV itself after first boot, except for the explicitly approved disabling of OMV's scheduled cron-apt job and preserving agreed SSH access controls.
6. **Reboot:** show Debian's standard completion screen, require manual **Continue** before first reboot.

## Installation failure and recovery boundary

- **Approved policy:** installer does not create snapshots, full-system backups, restore points or automatic rollback logic before, during or after optional-profile installation. It must not request backup destinations or secretly allocate rollback storage.
- On critical failure, **stop with an unambiguous failure message**, retain available installer logs and diagnostics, and allow the user to choose manual recovery or reinstall. A partially installed target is **not** represented as a successful or automatically recoverable installation.
- Preserve existing special-case behavior: failure of **ZRAM initialization on first boot** must enter emergency mode; failure of the running ZRAM monitor should be logged/restarted without emergency mode. Neither exception constitutes automatic rollback.
- **Implementation gate:** determine where diagnostic logs survive interruptions, hard reboots, failed disks and reinstallations; do not promise persistence when only the installer's temporary filesystem holds logs.

## Build and release gates

- **No installer-media verification:** as explicitly requested, do not require source-image checksum/signature checks, generated-ISO hashing, USB read-back/comparison, or a verification-only boot test. This does not change signed APT repository enforcement or the separate functional requirements of the installer.
- Generate the customized ISO and write it to the USB. Preserve the specified UEFI, BIOS, graphical, text and rescue functionality; do not add a separate media-integrity verification procedure.
- Test each optional profile alone and in permitted combinations, including **fail-stop behavior**, diagnostic availability and manual recovery paths. **Do not build or imply rollback functionality**.
- Test offline/failed repository behavior, third-party key checks, package resolution, root and sudo login, GRUB settings and correct target-disk selection.
- Confirm OMV does not reinstate root SSH access and does not block the installer-confirmed administrator account access.
- Test target-disk selection and destructive-operation confirmation in disposable virtual machines.
- Install Linux 7.x **in the target OS**, not necessarily in the running installer. Test the ZRAM kernel interfaces on the installed system.
- Do not call the image ready until [08_validation_and_pending.md](08_validation_and_pending.md) has been resolved.

## References

- [Simple-CDD package](https://packages.debian.org/trixie/simple-cdd)
- [Simple-CDD profiles explained](https://www.debian.org/doc/manuals/debian-handbook/sect.automated-installation.en.html)
- [Debian 13 installation manual](https://www.debian.org/releases/trixie/installmanual)
