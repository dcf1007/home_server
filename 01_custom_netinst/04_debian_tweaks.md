# 04 — Selectable **Debian tweaks** profile

**Status:** approved settings and implementation requirements; no installed scripts/ISO are claimed. **Recorded:** 2026-11-14. **Provenance:** all Debian customizations outside regular installer menus as requested by the user.

**Boundary:** This profile contains **non-GUI customizations only**, such as GRUB settings, kernel-independent filesystem/recovery and journaling policies, SSH hardening, and APT unattended-update suppression. Do **not** include ZRAM, Linux 7.x installation, microcode, proactive firmware, initramfs driver coverage, or SSD TRIM verification. Those belong to [03 ZRAM](03_zram_writeback.md), [09 Ensure 7.x](09_ensure_7x_kernel.md), and the separately selectable [10 Extended device support](10_extended_device_support.md). **All settings entered in the normal Debian Installer GUI** (language, locale, keyboard, timezone/RTC, hostname, username, domain, DHCP and task selection) are sourced as **editable suggestions** from [profile_defaults.conf](profile_defaults.conf) and handled by [05 base installation](05_base_installation.md), independently of whether Debian tweaks is selected.

**Approved independence:** Debian tweaks does **not require Ensure 7.x kernel branch** and applies all of its approved settings on Debian's ordinary installed kernel, including when Ensure 7.x is unchecked. It neither installs nor checks a mandatory 7.x kernel. Backports and ZRAM also remain separately selectable; do not implicitly check another profile. **Profile menu order:** Backports → Ensure 7.x → Debian tweaks → Extended device support → ZRAM → OMV → Docker (skip unchecked entries).

## APT sources, boot configuration and access

- Retain official signed stable, updates and security sources. **Do not enable `trixie-backports` or create an APT pin in Debian tweaks.** Backports uses Debian's **default priority 100** and is enabled only through the explicitly selected [Backports profile](02_backports_apt.md).
- **Kernel independence:** do not require Linux 7.x, install Linux kernel image/headers, add Backports, or prompt for Ensure 7.x from this profile. **GRUB menu, five-second timeout and normal kernel cleanup settings apply to whichever kernel(s) were separately installed.** Only the [Ensure 7.x kernel](09_ensure_7x_kernel.md) profile owns optional 7.x installation.
- Update GRUB: `GRUB_TIMEOUT_STYLE=menu`, `GRUB_TIMEOUT=5`, `GRUB_DEFAULT=0`; remove `quiet` but do not enable debug logging.
- Preserve root SSH prohibition `PermitRootLogin no`; preserve initial SSH password access for the installer-confirmed administrator account. Validate after OMV installation if OMV selected.

## Filesystem, failure recovery and journaling

- ext4 root: 5% reserved blocks; `noatime,errors=panic`; default `data=ordered`; do not enable continuous discard.
- **Do not alter native disk-layout choices here.** The decisions not to use encryption, LVM, a separate `/boot`, or a separate application partition belong to [05 — Base installation](05_base_installation.md) and are confirmed through normal partitioning screens.
- `kernel.panic=0`: do **not** automatically reboot after kernel panic.
- `fsck.mode=auto` (default) and **`fsck.repair=no`** (explicit): check if needed, never repair automatically.
- Persistent `systemd-journald` storage, with **Debian's default size limits**; do **not** explicitly install `rsyslog`.
- Mount the root and EFI using filesystem UUIDs; do not depend on changing `/dev/sdX` device names.

## Debian updates and privacy

Microcode, broad firmware coverage, initramfs driver policy and SSD TRIM validation are handled by the [Extended device support profile](10_extended_device_support.md). They are **not** installed or modified by Debian tweaks. Ordinary Debian Installer hardware detection remains available with either profile selection.

- **No unattended upgrades, including security upgrades.** Explicit effective APT setting:
  
  ```text
  APT::Periodic::Unattended-Upgrade "0";
  ```
  
  Verify `apt-config dump` and effective service/timer behavior; if `unattended-upgrades` is absent, ensure it does not become active from other profile dependencies. Scheduled package-index checks are distinct from installations and were not exhaustively configured.
- All package upgrades and reboots remain manual.
- Do not install/enable Debian `popularity-contest`.

## Installer GUI settings are not Debian tweaks

- **Do not set or override the installer-facing timezone, RTC, language, locale, keyboard, hostname, administrator username, DNS domain, DHCP method or software-selection defaults here.** Their canonical suggested values are in [profile_defaults.conf](profile_defaults.conf), must be editable/confirmed in normal setup screens, and apply even when Debian tweaks is unchecked.
- Keep `systemd-timesyncd` available for time synchronization as previously approved, but do not use this profile to silently override the GUI-selected timezone or UTC RTC setting.
- The desired **YYYY/MM/DD**, 24-hour, decimal-dot and space-grouping formats require a separately validated implementation; these are **not equivalent to installer timezone/locale GUI choices** and must not be assumed to follow automatically from `en_US.UTF-8`.
- The graphical installer's account/password questions, separate root credential after sudo setup, and default task selections are documented in [05 base installation](05_base_installation.md). Debian tweaks must **preserve**, not re-answer, the confirmed values and must not embed secrets.
- No firewall filtering during installer setup.
- Display a review/confirmation before non-GUI customization where practical; log applied changes.

## Conditional profile semantics

If Debian tweaks is not selected, do not silently apply its unique configuration or claim the installation includes the complete Debian tweaks design. **Extended device support, ZRAM, Ensure 7.x, Backports, OMV and Docker remain independently selectable**, and the ZRAM profile provides its own technical prerequisites if selected alone. Never silently enable another profile. Compatibility checks still apply. See [08_validation_and_pending.md](08_validation_and_pending.md).

## Acceptance checks (examples)

```sh
apt-cache policy
apt-config dump | grep -E 'Periodic|Unattended'
journalctl --list-boots
findmnt -no FSTYPE,OPTIONS /
sysctl kernel.panic
cat /proc/cmdline
ADMIN_USER="<confirmed-administrator-username>"
sudo -l -U "$ADMIN_USER"
sudo sshd -T | grep -i permitrootlogin
```

These checks alone are **not** proof that every proposed integration succeeds. Do not run or assume results until the corresponding profile is actually installed.
