# 05 — Base Debian 13 installation: normal installer screens

**Status:** agreed choices, to be entered or confirmed in the interactive installer. **Recorded:** 2026-11-14. **Provenance:** custom server installation-planning decisions.

The base installation is Debian 13 Trixie **amd64**, minimal/headless, with **SSH server** and **Standard system utilities**, **without** a desktop environment. Native GUI suggestions for installer language, localization, identities, networking, time and task selection come from [profile_defaults.conf](profile_defaults.conf) regardless of optional profile selections. The USB boots graphical installer by default, waits for Enter, and retains text/rescue. The target server is UEFI/GPT, Secure Boot disabled. No custom BIOS boot check.

## Disk layout

The reference design uses a **256 GB SSD/NVMe** for the OS. This is an example capacity, not a requirement for reuse. Select the intended OS installation disk and confirm partition writes **manually**; do not preselect a device by name. The OS installation does not use encryption or LVM.

| Partition | Purpose |
|---|---|
| EFI System Partition | 1 GiB, FAT32, mount `/boot/efi` |
| ext4 root | The rest of the SSD after other approved partitions; mount `/`; includes all application data |
| User-created swap partition (optional) | Suggested size **16 GB**, chosen and confirmed manually. **Without ZRAM:** ordinary swap. **With ZRAM:** the same confirmed partition becomes **raw/unformatted ZRAM writeback backing**, GPT Linux filesystem type **8300**, GPT partition name **`zram-writeback`**, referenced by **PARTUUID**; no conventional swap activation. |

There is **no separate `/boot`** or application partition. Use filesystem UUIDs for root and ESP, and PARTUUID for the optional ZRAM raw backing. **The user decides in the normal manual partitioner whether to create a swap partition.** Debian Installer normally warns if no swap partition is assigned, and can continue without it after confirmation. If a swap partition exists it becomes ordinary swap **unless** the user selects ZRAM; then **at the very start of ZRAM profile execution**, first detect and positively identify the partition, require explicit confirmation of the exact identity and destructive conversion, and **immediately** convert only that partition to GPT type **8300**, assigning **`zram-writeback`** as GPT name (**PARTLABEL**, not filesystem LABEL), and removing old swap signatures before any other ZRAM provisioning. If the partition was activated as conventional swap, the user must separately approve a **targeted `swapoff`** after memory safety checks; if unsafe or unsuccessful, stop without changing the partition type or signatures. Do not create a filesystem or mkswap-format the backing partition. **`/dev/zram0`** is separately formatted as swap by the generator. If ZRAM is selected but no swap partition exists, the ZRAM profile must offer **return to partitioning and create swap** or **deselect ZRAM**; it must not proceed silently. The exact transition through partman and any swap signature removal must be tested before deployment.

Root ext4 uses Debian's ordinary filesystem defaults, except for the **optional [Debian tweaks](04_debian_tweaks.md)** profile's non-default `noatime` and `errors=panic` mount options. Disk formatting and partition confirmation remain in Debian Installer; no default-setting override is needed.

## Identity, credentials and networking

- The **hostname, administrator username, DNS domain and wired DHCP suggestions** come from [profile_defaults.conf](profile_defaults.conf) and must be displayed in editable Debian Installer questions with explicit confirmation. The default local DNS domain is empty; the network uses router-side IP reservation. **None** of these GUI choices belongs to the Debian tweaks profile.
- Prompt for the administrator password interactively and configure `sudo` access for the **actual confirmed username**, regardless of whether Debian tweaks or Ensure 7.x was selected.
- **After** setting the installer-confirmed administrator account and sudo, enter a **separate root password** interactively **before first reboot**. No password or hash embedded in USB.
- Initial SSH password authentication for the installer-confirmed administrator account. Root SSH login disabled (`PermitRootLogin no`).
- No firewall filtering policy during installation; any selected Docker daemon remains disabled.

## Localization / time — normal installer GUI

**[profile_defaults.conf](profile_defaults.conf) is the single canonical source for suggested GUI choices**, including English installer language, locale, Spanish (Spain) keyboard, `Europe/Berlin` timezone and a UTC hardware clock. Every shown value remains editable and must be confirmed on the standard setup screens, **whether or not Debian tweaks is selected**. The original example values are recorded in the config file rather than duplicated as fixed choices here.

Retain `systemd-timesyncd` for time synchronization; use the user-confirmed timezone and locale from the ordinary installer GUI.

## Repositories and ordinary package options

- Base Debian repositories: `trixie`, `trixie-updates` and `trixie-security`; components `main contrib non-free non-free-firmware`; binary package sources only. **`trixie-backports` is enabled only if the user explicitly selects the separate Backports profile**.
- Official HTTPS mirrors, no APT proxy. [02 — Backports](02_backports_apt.md) documents optional repository enablement at **Debian default priority 100**, with explicit approval for package upgrades and subsequent autoremove/purge. The independently selectable [Ensure 7.x kernel branch](09_ensure_7x_kernel.md) profile requests only kernel-related packages from Backports if ordinary repositories lack a suitable Linux 7.x kernel.
- Standard APT package policy: install `Recommends`, not `Suggests`.
- Installer software-selection suggestions (**SSH server**, **Standard system utilities**, **no desktop**) live in [profile_defaults.conf](profile_defaults.conf) and must be confirmed via the normal installation GUI; symbolic tasksel identifiers require validation before automation.
- No `popularity-contest`.
- Always retain Debian Installer's normal automatic firmware detection. The optional [Extended device support](10_extended_device_support.md) profile attempts **both Intel and AMD microcode packages** (without filtering by actual CPU vendor), plus broad additional firmware. It must simulate the combined transaction, and any unavailable/conflicting microcode or firmware package may be omitted **only after its reason is shown and the user explicitly approves that individual omission**.
- Do not run unattended upgrades or automatically reboot for updates. The **separately selected Backports profile** owns the reviewed full-upgrade and post-upgrade cleanup steps, including explicit approval for proposed removals and purges.

## Finish

Use Debian's normal completion screen, **wait for manual Continue** before reboot. Installed GRUB is a separate five-second menu. Important installer acceptance checks are in [08_validation_and_pending.md](08_validation_and_pending.md).
