# 04 — Selectable **Debian tweaks** profile

**Status:** approved settings and implementation requirements; no installed scripts/ISO are claimed. **Recorded:** 2026-11-14. **Provenance:** all Debian customizations outside regular installer menus as requested by the user.

**Boundary:** This profile contains **non-GUI customizations only**, such as GRUB settings, kernel-independent boot/filesystem/journaling options, firmware packages, SSH hardening and APT unattended-update suppression. Do **not** include ZRAM or Linux 7.x kernel installation; those belong to [03 ZRAM](03_zram_writeback.md) and [09 Ensure 7.x](09_ensure_7x_kernel.md). **All settings entered in the normal Debian Installer GUI** (language, locale, keyboard, timezone/RTC, hostname, username, domain, DHCP and task selection) are sourced as **editable suggestions** from [profile_defaults.conf](profile_defaults.conf) and handled by [05 base installation](05_base_installation.md), independently of whether Debian tweaks is selected.

**Approved independence:** Debian tweaks does **not require Ensure 7.x kernel branch** and applies all of its approved settings on Debian's ordinary installed kernel, including when Ensure 7.x is unchecked. It neither installs nor checks a mandatory 7.x kernel. Backports and ZRAM also remain separately selectable; do not implicitly check another profile. **Profile menu order:** Backports → Ensure 7.x → Debian tweaks → ZRAM → OMV → Docker (skip unchecked entries).

## APT, kernel and firmware

- Retain official signed stable, updates and security sources. **Do not enable `trixie-backports` or create an APT pin in Debian tweaks.** Backports uses Debian's **default priority 100** and is enabled only through the explicitly selected [Backports profile](02_backports_apt.md).
- **Kernel independence:** do not require Linux 7.x, install Linux kernel image/headers, add Backports, or prompt for Ensure 7.x from this profile. **GRUB menu, five-second timeout and normal kernel cleanup settings apply to whichever kernel(s) were separately installed.** Only the [Ensure 7.x kernel](09_ensure_7x_kernel.md) profile owns optional 7.x installation.
- Automatically detect CPU vendor and install `intel-microcode` or `amd64-microcode` from the Debian firmware component.
- Preserve Debian Installer's automatic firmware lookup and install **broad additional firmware coverage**, including wired networking, storage/HBA controllers, Wi-Fi, Bluetooth, graphics, audio and miscellaneous common hardware families. The user specifically selected broad coverage, **not just detected hardware**. The following is a **provisional package-name inventory**, checked against published Debian 13 (Trixie) package listings, **not yet an approved or simulated install transaction**.

### Provisional broad firmware candidate list

Package names below exist in Debian 13 package listings for firmware. Exact version/candidate, dependency conflicts, available architecture, repository selection with **Debian-default Backports priority 100, only if its profile is selected**, overlaps/metapackages and license/interactive debconf effects still require validation. Do not silently omit selected broad coverage or force an unvalidated installation.

| Coverage | Candidate Debian binary packages |
|---|---|
| Common kernel + miscellaneous | `firmware-linux`, `firmware-linux-nonfree`, `firmware-misc-nonfree`, `firmware-intel-misc` |
| Ethernet/NICs and storage/HBAs | `firmware-realtek`, `firmware-bnx2`, `firmware-bnx2x`, `firmware-cavium`, `firmware-marvell-prestera`, `firmware-myricom`, `firmware-netronome`, `firmware-netxen`, `firmware-qlogic` |
| Wireless / Wi-Fi | `firmware-atheros`, `firmware-brcm80211`, `firmware-iwlwifi`, `firmware-ipw2x00`, `firmware-libertas`, `firmware-mediatek`, `firmware-ti-connectivity`, `firmware-ath9k-htc`, `firmware-carl9170`, `firmware-zd1211` |
| Graphics / GPU / media | `firmware-amd-graphics`, `firmware-intel-graphics`, `firmware-nvidia-graphics`, `firmware-ast`, `firmware-qcom-soc`, `firmware-samsung`, `firmware-siano`, `firmware-ivtv` |
| Audio / Bluetooth / peripheral | `firmware-cirrus`, `firmware-intel-sound`, `firmware-sof-signed`, `bluez-firmware` |

**Notes:** `firmware-linux`/`firmware-linux-nonfree` are metapackages and may already pull `firmware-misc-nonfree`; avoid duplicated intent. `firmware-qcom-media` is a dummy transitional package and intentionally not a useful additional firmware candidate. The list may be trimmed **only after** exact package availability/compatibility verification and review, not merely because hardware is currently absent. CPU microcode (`intel-microcode` or `amd64-microcode`) remains chosen according to detected CPU family, not both indiscriminately.

**Mandatory pre-implementation evidence:** refresh signed APT metadata, run `apt-cache policy` and `apt-get -s install` for the exact final package set under the **actual selected APT policy** (Backports priority **100**, if explicitly selected) and other selected profiles (especially OMV), inspect removals and dependency changes, verify that no extra proprietary drivers or DKMS modules are implicitly installed, document packages excluded with reasons, and present the final effective package list for user confirmation. Auto-detection continues even if this extra-package step is unready.

**Upstream package references:** [Debian 13 firmware-nonfree source package](https://packages.debian.org/source/trixie/firmware-nonfree), [Debian 13 firmware package search](https://packages.debian.org/search?keywords=firmware&searchon=names&suite=trixie), [Debian firmware installer behavior](https://wiki.debian.org/Firmware/), [Intel SOF package](https://packages.debian.org/trixie/firmware-sof-signed).

- Retain Debian's `initramfs-tools`, `MODULES=most` and default Zstandard initramfs compression.
- Update GRUB: `GRUB_TIMEOUT_STYLE=menu`, `GRUB_TIMEOUT=5`, `GRUB_DEFAULT=0`; remove `quiet` but do not enable debug logging.
- Preserve root SSH prohibition `PermitRootLogin no`; preserve initial SSH password access for the installer-confirmed administrator account. Validate after OMV installation if OMV selected.

## Filesystem, boot, journaling and SSD

- ext4 root: 5% reserved blocks; `noatime,errors=panic`; default `data=ordered`; do not enable continuous discard.
- No filesystem encryption, LVM, separate `/boot` or application partition.
- `kernel.panic=0`: do **not** automatically reboot after kernel panic.
- `fsck.mode=auto` (default) and **`fsck.repair=no`** (explicit): check if needed, never repair automatically.
- Persistent `systemd-journald` storage, with **Debian's default size limits**; do **not** explicitly install `rsyslog`.
- Keep weekly `fstrim.timer`, and verify enabled after installation.
- Mount the root and EFI using filesystem UUIDs; do not depend on changing `/dev/sdX` device names.

## Debian updates and privacy

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

If Debian tweaks is not selected, do not silently apply its unique configuration or claim the installation includes the complete Debian tweaks design. **ZRAM, Ensure 7.x, Backports, OMV and Docker remain independently selectable**, and the ZRAM profile provides its own technical prerequisites if selected alone. Never silently enable another profile. Compatibility checks still apply. See [08_validation_and_pending.md](08_validation_and_pending.md).

## Acceptance checks (examples)

```sh
uname -r
dpkg -l linux-image-amd64 linux-headers-amd64
apt-cache policy
apt-config dump | grep -E 'Periodic|Unattended'
systemctl is-enabled fstrim.timer
journalctl --list-boots
findmnt -no FSTYPE,OPTIONS /
sysctl kernel.panic
cat /proc/cmdline
ADMIN_USER="<confirmed-administrator-username>"
sudo -l -U "$ADMIN_USER"
sudo sshd -T | grep -i permitrootlogin
```

These checks alone are **not** proof that every proposed integration succeeds. Do not run or assume results until the corresponding profile is actually installed.
