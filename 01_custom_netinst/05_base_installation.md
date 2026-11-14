# 05 — Base Debian 13 installation: normal installer screens

**Status:** agreed choices, to be entered or confirmed in the interactive installer. **Recorded:** 2026-11-14. **Provenance:** custom server installation-planning decisions.

The base installation is Debian 13 Trixie **amd64**, minimal/headless, with **SSH server** and **Standard system utilities**, **without** a desktop environment. Native GUI suggestions for installer language, localization, identities, networking, time and task selection come from [profile_defaults.conf](profile_defaults.conf) regardless of optional profile selections. The USB boots graphical installer by default, waits for Enter, and retains text/rescue. The target server is UEFI/GPT, Secure Boot disabled. No custom BIOS boot check.

## Disk layout

The reference design uses a **256 GB SSD/NVMe** for the OS. This is an example capacity, not a requirement for reuse. Select the intended OS installation disk and confirm partition writes **manually**; do not preselect a device by name. The OS installation does not use encryption or LVM.

| Partition | Purpose |
|---|---|
| EFI System Partition | 1 GiB, FAT32, mount `/boot/efi` |
| ext4 root | The rest of the SSD after other approved partitions; mount `/`; includes all application data |
| User-created swap partition (optional) | Suggested size **16 GB**, chosen and confirmed manually. **Without ZRAM:** ordinary swap. **With ZRAM:** the same partition is reserved as **raw writeback backing**, identified via PARTUUID and never used as independent swap. |

There is **no separate `/boot`** or application partition. Use filesystem UUIDs for root and ESP, and PARTUUID for the optional ZRAM raw backing. **The user decides in the normal manual partitioner whether to create a swap partition.** Debian Installer normally warns if no swap partition is assigned, and can continue without it after confirmation. If a swap partition exists it becomes ordinary swap **unless** the user selects ZRAM, in which case it must be safely re-purposed into raw backing instead of formatted/activated swap. If ZRAM is selected but no swap partition exists, the ZRAM profile must offer **return to partitioning and create swap** or **deselect ZRAM**; it must not proceed silently. The exact transition through partman and any swap signature removal must be tested before deployment.

Root ext4: 5% reserved blocks, `noatime`, `errors=panic`, ordinary `data=ordered` journaling, continuous discard disabled. Filesystem-specific changes belong to [Debian tweaks](04_debian_tweaks.md); **weekly `fstrim.timer` verification** belongs to the optional [Extended device support](10_extended_device_support.md) profile. Debian's ordinary timer defaults remain otherwise unchanged.

## Identity, credentials and networking

- The **hostname, administrator username, DNS domain and wired DHCP suggestions** come from [profile_defaults.conf](profile_defaults.conf) and must be displayed in editable Debian Installer questions with explicit confirmation. The default local DNS domain is empty; the network uses router-side IP reservation. **None** of these GUI choices belongs to the Debian tweaks profile.
- Prompt for the administrator password interactively and configure `sudo` access for the **actual confirmed username**, regardless of whether Debian tweaks or Ensure 7.x was selected.
- **After** setting the installer-confirmed administrator account and sudo, enter a **separate root password** interactively **before first reboot**. No password or hash embedded in USB.
- Initial SSH password authentication for the installer-confirmed administrator account. Root SSH login disabled (`PermitRootLogin no`).
- No firewall filtering policy during installation; any selected Docker daemon remains disabled.

## Localization / time — normal installer GUI

**[profile_defaults.conf](profile_defaults.conf) is the single canonical source for suggested GUI choices**, including English installer language, locale, Spanish (Spain) keyboard, `Europe/Berlin` timezone and a UTC hardware clock. Every shown value remains editable and must be confirmed on the standard setup screens, **whether or not Debian tweaks is selected**. The original example values are recorded in the config file rather than duplicated as fixed choices here.

Retain `systemd-timesyncd`. The separate desired date/number formats (**YYYY/MM/DD**, 24-hour, decimal `.`, grouping space) remain subject to engineering validation; they are **not ordinary installer GUI fields** and cannot be guaranteed by choosing `en_US.UTF-8`.

## Repositories and ordinary package options

- Base Debian repositories: `trixie`, `trixie-updates` and `trixie-security`; components `main contrib non-free non-free-firmware`; binary package sources only. **`trixie-backports` is enabled only if the user explicitly selects the separate Backports profile**.
- Official HTTPS mirrors, no APT proxy. [02 — Backports](02_backports_apt.md) documents optional repository enablement at **Debian default priority 100**, with explicit approval for package upgrades and subsequent autoremove/purge. The independently selectable [Ensure 7.x kernel branch](09_ensure_7x_kernel.md) profile requests only kernel-related packages from Backports if ordinary repositories lack a suitable Linux 7.x kernel.
- Standard APT package policy: install `Recommends`, not `Suggests`.
- Installer software-selection suggestions (**SSH server**, **Standard system utilities**, **no desktop**) live in [profile_defaults.conf](profile_defaults.conf) and must be confirmed via the normal installation GUI; symbolic tasksel identifiers require validation before automation.
- No `popularity-contest`.
- Always retain Debian Installer's normal automatic firmware detection. **CPU microcode selection, broad additional device firmware and hardware-related verification** belong only to the optional [Extended device support](10_extended_device_support.md) profile and remain subject to validated package transactions.
- Do not run unattended upgrades or automatically reboot for updates. The **separately selected Backports profile** owns the reviewed full-upgrade and post-upgrade cleanup steps, including explicit approval for proposed removals and purges.

## Finish

Use Debian's normal completion screen, **wait for manual Continue** before reboot. Installed GRUB is a separate five-second menu. Important installer acceptance checks are in [08_validation_and_pending.md](08_validation_and_pending.md).
