# 01 — Customized netinst / Simple-CDD preparation

**Status:** installation design, **not** a built or tested ISO. **Recorded:** 2026-11-14. **Provenance:** custom server Debian 13 server planning conversation and the request to document custom netinst preparation.

## Purpose

Build an amd64 Debian 13 (Trixie) installer USB using **Simple-CDD** (customized Debian installer). The installer is interactive wherever a native screen exists. Package installation is interactive wherever possible and automated otherwise; substantive custom configuration needs an appropriate review/confirmation mechanism.

The USB **supports UEFI and legacy BIOS**, but the server is intended to install in **UEFI/GPT** mode. Do **not** add an unsolicited BIOS-mode safeguard. The USB bootloader highlights **Graphical install** and waits indefinitely until Enter. Preserve text installer and rescue alternatives. The *installed* GRUB timeout is five seconds.

## Installer profile architecture

Simple-CDD supports selectable profiles, typically expressed using files such as `profiles/<name>.description`, `.packages`, `.preseed` and `.postinst`. The obligatory `default` profile contains common configuration; optional profiles should be independently selectable.

| Selectable profile | Guide | Scope |
|---|---|---|
| **ZSTD ZRAM writeback** | [03_zram_writeback.md](03_zram_writeback.md) | ZRAM, dedicated raw SSD backing and monitor |
| **Debian tweaks** | [04_debian_tweaks.md](04_debian_tweaks.md) | Non-menu Debian settings; **does not contain ZRAM** |
| **OpenMediaVault 8** | [06_openmediavault.md](06_openmediavault.md) | Optional OMV installation, approved cron-apt shutdown |
| **Docker** | [07_docker.md](07_docker.md) | Official Docker packages, daemon and socket inactive |

The backports activation and preference policy has its own guide: [02_backports_apt.md](02_backports_apt.md). It is a **Debian tweaks** implementation step, not a fifth optional profile. Normal Debian installer choices are in [05_base_installation.md](05_base_installation.md).

**No defaults for profile checkboxes have been authorized yet.** Profile selection must not be substituted by automatic choice.

## Editable installation identity defaults

The initial hostname and administrator username are defined in [profile_defaults.conf.example](profile_defaults.conf.example) as **suggestions**, not fixed values. The installer must present each in an editable question, allow changes, and require explicit confirmation. Changed values must propagate consistently into the hostname, user account, sudo and SSH configurations.

No passwords or password hashes may be embedded in installation media.

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
    debian-tweaks.description
    debian-tweaks.packages
    debian-tweaks.postinst
    openmediavault.description
    openmediavault.postinst
    docker.description
    docker.postinst
    zram-writeback.description
    zram-writeback.packages
    zram-writeback.postinst
```

Verify actual Simple-CDD syntax and how profile questions are presented in this release before producing the installer. It is not safe to assume profile selection happens before disk partitioning; **the ZRAM profile changes the disk layout**, so either arrange a compatible early selection step or explicitly confirm the partition choice manually in the installer. Never silently repartition afterward.

## Non-negotiable safeguards

1. **No unattended disk actions:** present target SSD identification, partition creation, filesystem operations and final commit for manual confirmation. Never hard-code `/dev/sda` or touch the nine NAS HDDs.
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
- Test with extra dummy disks to verify **zero writes to NAS disks**.
- Install Linux 7.x **in the target OS**, not necessarily in the running installer. Test the ZRAM kernel interfaces on the installed system.
- Do not call the image ready until [08_validation_and_pending.md](08_validation_and_pending.md) has been resolved.

## References

- [Simple-CDD package](https://packages.debian.org/trixie/simple-cdd)
- [Simple-CDD profiles explained](https://www.debian.org/doc/manuals/debian-handbook/sect.automated-installation.en.html)
- [Debian 13 installation manual](https://www.debian.org/releases/trixie/installmanual)
