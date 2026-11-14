# 04 — Selectable **Debian tweaks** profile

**Status:** approved settings and implementation requirements; no installed scripts/ISO are claimed. **Recorded:** 2026-11-14. **Provenance:** all Debian customizations outside regular installer menus as requested by the user.

**Boundary:** This profile includes non-menu Debian configuration only. **Do not include ZRAM**: it belongs to [03_zram_writeback.md](03_zram_writeback.md). Standard installer questions remain interactive, see [05_base_installation.md](05_base_installation.md).

**Independent optional profiles:** ZRAM can be selected without Debian tweaks; this profile contains no ZRAM software or tuning. **Backports is also a separate optional profile**, not implicitly selected by Debian tweaks or ZRAM. If Linux 7.x is unavailable in ordinary Debian repositories, the requesting profile prompts the user to **select Backports explicitly or deselect/stop that profile**; only Backports performs activation, global pinning and the reviewed package upgrade.

## APT, kernel and firmware

- Retain official Debian signed stable, updates and security sources. **Do not enable `trixie-backports` or configure priority 900 from Debian tweaks.** Those operations belong solely to the explicitly selected [Backports profile](02_backports_apt.md).
- Require the **newest eligible Linux 7.x kernel** and matching headers before first reboot, initially checking standard Debian 13 repositories. If 7.x is unavailable there, prompt to **select Backports explicitly or deselect/stop Debian tweaks**. Only the selected Backports profile enables the repository, pins it to priority 900 and **completes the reviewed upgrade of eligible installed packages before proceeding**. After that, install the moving `linux-image-amd64`/`linux-headers-amd64` metapackages when their actual candidates resolve to Linux 7.x and matching headers. Do not lock kernel versions. Keep an available stable fallback kernel initially; retain Debian's default kernel-cleanup policy. Never silently select other profiles.
- Automatically detect CPU vendor and install `intel-microcode` or `amd64-microcode` from the Debian firmware component.
- Preserve Debian Installer's automatic firmware lookup and install **broad additional firmware coverage**, including wired networking, storage/HBA controllers, Wi-Fi, Bluetooth, graphics, audio and miscellaneous common hardware families. The user specifically selected broad coverage, **not just detected hardware**. The following is a **provisional package-name inventory**, checked against published Debian 13 (Trixie) package listings, **not yet an approved or simulated install transaction**.

### Provisional broad firmware candidate list

Package names below exist in Debian 13 package listings for firmware. Exact version/candidate, dependency conflicts, available architecture, repository selection with Backports priority 900 **only if the Backports profile is selected**, overlaps/metapackages and license/interactive debconf effects still require validation. Do not silently omit selected broad coverage or force an unvalidated installation.

| Coverage | Candidate Debian binary packages |
|---|---|
| Common kernel + miscellaneous | `firmware-linux`, `firmware-linux-nonfree`, `firmware-misc-nonfree`, `firmware-intel-misc` |
| Ethernet/NICs and storage/HBAs | `firmware-realtek`, `firmware-bnx2`, `firmware-bnx2x`, `firmware-cavium`, `firmware-marvell-prestera`, `firmware-myricom`, `firmware-netronome`, `firmware-netxen`, `firmware-qlogic` |
| Wireless / Wi-Fi | `firmware-atheros`, `firmware-brcm80211`, `firmware-iwlwifi`, `firmware-ipw2x00`, `firmware-libertas`, `firmware-mediatek`, `firmware-ti-connectivity`, `firmware-ath9k-htc`, `firmware-carl9170`, `firmware-zd1211` |
| Graphics / GPU / media | `firmware-amd-graphics`, `firmware-intel-graphics`, `firmware-nvidia-graphics`, `firmware-ast`, `firmware-qcom-soc`, `firmware-samsung`, `firmware-siano`, `firmware-ivtv` |
| Audio / Bluetooth / peripheral | `firmware-cirrus`, `firmware-intel-sound`, `firmware-sof-signed`, `bluez-firmware` |

**Notes:** `firmware-linux`/`firmware-linux-nonfree` are metapackages and may already pull `firmware-misc-nonfree`; avoid duplicated intent. `firmware-qcom-media` is a dummy transitional package and intentionally not a useful additional firmware candidate. The list may be trimmed **only after** exact package availability/compatibility verification and review, not merely because hardware is currently absent. CPU microcode (`intel-microcode` or `amd64-microcode`) remains chosen according to detected CPU family, not both indiscriminately.

**Mandatory pre-implementation evidence:** refresh signed APT metadata, run `apt-cache policy` and `apt-get -s install` for the exact final package set under the **actual selected APT policy** (Backports priority 900 **only if explicitly selected**) and other selected profiles (especially OMV), inspect removals and dependency changes, verify that no extra proprietary drivers or DKMS modules are implicitly installed, document packages excluded with reasons, and present the final effective package list for user confirmation. Auto-detection continues even if this extra-package step is unready.

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

## Time, account ordering, and review

- Retain `systemd-timesyncd`, UTC RTC and `Europe/Berlin` time zone.
- Validate the requested date/number formatting (YYYY/MM/DD, 24-hour, decimal dot, grouping space) against locale mechanisms and application behavior; do not assume `en_US.UTF-8` produces all requested formats.
- Ensure the installer-confirmed administrator account has sudo, prompt for a separate root password **after** creating the installer-confirmed administrator account and **before** first reboot, without passwords/hashes on the USB.
- No firewall filtering during installer setup.
- Display a meaningful configuration review/confirmation before non-menu customization where practical; log what was applied.

## Conditional profile semantics

If Debian tweaks is not selected, do not silently apply its unique configuration or claim the installation includes the complete Debian tweaks design. **ZRAM, Backports, OMV and Docker remain independently selectable**, and the ZRAM profile provides its own technical prerequisites if selected alone. Never silently enable another profile. Compatibility checks still apply. See [08_validation_and_pending.md](08_validation_and_pending.md).

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
