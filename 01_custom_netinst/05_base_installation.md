# 05 — Base Debian 13 installation: normal installer screens

**Status:** agreed choices, to be entered or confirmed in the interactive installer. **Recorded:** 2026-11-14. **Provenance:** custom server installation-planning decisions.

The base installation is Debian 13 Trixie **amd64**, minimal/headless, with **SSH server** and **Standard system utilities**, **without** a desktop environment. The USB boots graphical installer by default, waits for Enter, and retains text/rescue. The target server is UEFI/GPT, Secure Boot disabled. No custom BIOS boot check.

## Disk layout

The reference design uses a **256 GB SSD/NVMe** for the OS. This is an example capacity, not a requirement for reuse. Select the intended OS installation disk and confirm partition writes **manually**; do not preselect a device by name. The OS installation does not use encryption or LVM.

| Partition | Purpose |
|---|---|
| EFI System Partition | 1 GiB, FAT32, mount `/boot/efi` |
| ext4 root | The rest of the SSD after other approved partitions; mount `/`; includes all application data |
| User-created swap partition (optional) | Suggested size **16 GB**, chosen and confirmed manually. **Without ZRAM:** ordinary swap. **With ZRAM:** the same partition is reserved as **raw writeback backing**, identified via PARTUUID and never used as independent swap. |

There is **no separate `/boot`** or application partition. Use filesystem UUIDs for root and ESP, and PARTUUID for the optional ZRAM raw backing. **The user decides in the normal manual partitioner whether to create a swap partition.** Debian Installer normally warns if no swap partition is assigned, and can continue without it after confirmation. If a swap partition exists it becomes ordinary swap **unless** the user selects ZRAM, in which case it must be safely re-purposed into raw backing instead of formatted/activated swap. If ZRAM is selected but no swap partition exists, the ZRAM profile must offer **return to partitioning and create swap** or **deselect ZRAM**; it must not proceed silently. The exact transition through partman and any swap signature removal must be tested before deployment.

Root ext4: 5% reserved blocks, `noatime`, `errors=panic`, ordinary `data=ordered` journaling, continuous discard disabled, weekly `fstrim.timer` retained. Some are applied by [Debian tweaks](04_debian_tweaks.md) rather than installer menus.

## Identity, credentials and networking

- Hostname: show an **editable initial default** and require user confirmation; leave the local DNS domain unset by default.
- Wired Ethernet, online install, DHCP, router-side IP reservation.
- Administrator username: show an **editable initial default**, require confirmation, enter the password interactively, and configure `sudo` access.
- **After** setting the installer-confirmed administrator account and sudo, enter a **separate root password** interactively **before first reboot**. No password or hash embedded in USB.
- Initial SSH password authentication for the installer-confirmed administrator account. Root SSH login disabled (`PermitRootLogin no`).
- No firewall filtering policy during installation; any selected Docker daemon remains disabled.

## Localization / time

- English US: `en_US.UTF-8`.
- Keyboard: Spanish (Spain).
- Time zone: `Europe/Berlin`; RTC in UTC.
- Time synchronization: `systemd-timesyncd`.
- Desired display: **YYYY/MM/DD**, 24-hour, decimal **.**, thousands separator **space**. This requires validation because the ordinary `en_US.UTF-8` locale does not provide all those details exactly.

## Repositories and ordinary package options

- Base Debian repositories: `trixie`, `trixie-updates` and `trixie-security`; components `main contrib non-free non-free-firmware`; binary package sources only. **`trixie-backports` is enabled only if the user explicitly selects the separate Backports profile**.
- Official HTTPS mirrors, no APT proxy. [02 — Backports](02_backports_apt.md) documents optional repository enablement at **Debian default priority 100**, with explicit approval for package upgrades and subsequent autoremove/purge. The independently selectable [Ensure 7.x kernel branch](09_ensure_7x_kernel.md) profile requests only kernel-related packages from Backports if ordinary repositories lack a suitable Linux 7.x kernel.
- Standard APT package policy: install `Recommends`, not `Suggests`.
- No `popularity-contest`.
- Install automatic firmware identified by Debian plus a broader set; exact extra package list deferred.
- Do not run unattended upgrades or automatically reboot for updates. The **separately selected Backports profile** owns the reviewed full-upgrade and post-upgrade cleanup steps, including explicit approval for proposed removals and purges.

## Finish

Use Debian's normal completion screen, **wait for manual Continue** before reboot. Installed GRUB is a separate five-second menu. Important installer acceptance checks are in [08_validation_and_pending.md](08_validation_and_pending.md).
