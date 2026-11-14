# 03 — Base Debian 13 installation: normal installer screens

**Status:** agreed choices, to be entered or confirmed in the interactive installer. **Recorded:** 2026-11-14. **Provenance:** DCF1007 installation-planning decisions.

The base installation is Debian 13 Trixie **amd64**, minimal/headless, with **SSH server** and **Standard system utilities**, **without** a desktop environment. The USB boots graphical installer by default, waits for Enter, and retains text/rescue. The target server is UEFI/GPT, Secure Boot disabled. No custom BIOS boot check.

## Disk layout

Target is the **dedicated 256 GB SSD/NVMe**, separate from **nine NAS HDDs**. Select disk and confirm partition writes **manually**; do not preselect a device by name. Whether to physically disconnect NAS HDDs remains deferred. The SSD is not encrypted and does not use LVM.

| Partition | Purpose |
|---|---|
| EFI System Partition | 1 GiB, FAT32, mount `/boot/efi` |
| ext4 root | The rest of the SSD after other approved partitions; mount `/`; includes all application data |
| Raw backing partition | **16 GB only when the optional ZRAM profile is selected**; no filesystem or independent swap. Use PARTUUID. |

There is **no separate `/boot`** or application partition. Use filesystem UUIDs for root and ESP; ZRAM raw backing uses PARTUUID. If the ZRAM profile is **not selected**, the SSD's former 16 GB swap allocation has **not been redefined**. Its treatment is an unresolved conditional layout question; do not make an automatic choice.

Root ext4: 5% reserved blocks, `noatime`, `errors=panic`, ordinary `data=ordered` journaling, continuous discard disabled, weekly `fstrim.timer` retained. Some are applied by [Debian tweaks](04_debian_tweaks.md) rather than installer menus.

## Identity, credentials and networking

- Hostname **`dcf1007-server`**, no local DNS domain.
- Wired Ethernet, online install, DHCP, router-side IP reservation.
- User **`david`**: enter password interactively, configure `sudo` access.
- **After** setting `david` and sudo, enter a **separate root password** interactively **before first reboot**. No password or hash embedded in USB.
- Initial SSH password authentication for `david`. Root SSH login disabled (`PermitRootLogin no`).
- No firewall filtering policy during installation; any selected Docker daemon remains disabled.

## Localization / time

- English US: `en_US.UTF-8`.
- Keyboard: Spanish (Spain).
- Time zone: `Europe/Berlin`; RTC in UTC.
- Time synchronization: `systemd-timesyncd`.
- Desired display: **YYYY/MM/DD**, 24-hour, decimal **.**, thousands separator **space**. This requires validation because the ordinary `en_US.UTF-8` locale does not provide all those details exactly.

## Repositories and ordinary package options

- Debian repositories: `trixie`, `trixie-updates`, `trixie-security` and `trixie-backports`; `main contrib non-free non-free-firmware`; binary package sources only.
- Official HTTPS mirrors, no APT proxy. See the exact activation and pinning policy in [02_backports_apt.md](02_backports_apt.md).
- Standard APT package policy: install `Recommends`, not `Suggests`.
- No `popularity-contest`.
- Install automatic firmware identified by Debian plus a broader set; exact extra package list deferred.
- Never automatically install package upgrades or reboot for updates.

## Finish

Use Debian's normal completion screen, **wait for manual Continue** before reboot. Installed GRUB is a separate five-second menu. Important installer acceptance checks are in [08_validation_and_pending.md](08_validation_and_pending.md).
