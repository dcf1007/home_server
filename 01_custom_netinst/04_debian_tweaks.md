# 04 — Selectable **Debian tweaks** profile

**Status:** approved settings and implementation requirements; no installed scripts/ISO are claimed. **Recorded:** 2026-11-14. **Provenance:** all Debian customizations outside regular installer menus as requested by the user.

**Boundary:** This profile includes non-menu Debian configuration only. **Do not include ZRAM**: it belongs to [03_zram_writeback.md](03_zram_writeback.md). Standard installer questions remain interactive, see [05_base_installation.md](05_base_installation.md).

**Independent optional profiles:** ZRAM can be selected and installed **without** Debian tweaks. Its kernel 7.x, generator, repository and upgrade prerequisites are checked by the ZRAM profile itself. This profile contains no ZRAM software or tuning and is never selected automatically.

## APT, kernel and firmware

- Configure official repositories and the **provisional backports priority 900**, with stable/security/updates normally at 500, **only after passing compatibility checks** in [02_backports_apt.md](02_backports_apt.md).
- Install the **newest eligible Linux 7.x kernel and corresponding headers** before the first reboot. Verify ordinary Debian repositories first and require explicit user approval to enable `trixie-backports` if 7.x is unavailable there. Use the moving `linux-image-amd64` and `linux-headers-amd64` metapackages without fixed-version locking; confirm their resolved candidates are 7.x and match. When backports is newly enabled, require a **user-reviewed, successfully completed upgrade of all eligible installed packages** before proceeding. Retain an available stable kernel initially, and keep Debian's normal kernel cleanup policy without custom holds. Never silently enable another installer profile. See [02 APT backports](02_backports_apt.md) and [03 ZRAM kernel requirements](03_zram_writeback.md).
- Automatically detect CPU vendor and install `intel-microcode` or `amd64-microcode` from the Debian firmware component.
- Preserve Debian Installer's automatic firmware lookup and install **broad additional firmware coverage**, including wired networking, storage/HBA controllers, Wi-Fi, Bluetooth, graphics, audio and miscellaneous common hardware families. The user specifically selected broad coverage, **not just detected hardware**. The following is a **provisional package-name inventory**, checked against published Debian 13 (Trixie) package listings, **not yet an approved or simulated install transaction**.

### Provisional broad firmware candidate list

Package names below exist in Debian 13 package listings for firmware. Exact version/candidate, dependency conflicts, available architecture, repository selection with backports at priority 900, overlaps/metapackages and license/interactive debconf effects still require validation. Do not silently omit selected broad coverage or force an unvalidated installation.

| Coverage | Candidate Debian binary packages |
|---|---|
| Common kernel + miscellaneous | `firmware-linux`, `firmware-linux-nonfree`, `firmware-misc-nonfree`, `firmware-intel-misc` |
| Ethernet/NICs and storage/HBAs | `firmware-realtek`, `firmware-bnx2`, `firmware-bnx2x`, `firmware-cavium`, `firmware-marvell-prestera`, `firmware-myricom`, `firmware-netronome`, `firmware-netxen`, `firmware-qlogic` |
| Wireless / Wi-Fi | `firmware-atheros`, `firmware-brcm80211`, `firmware-iwlwifi`, `firmware-ipw2x00`, `firmware-libertas`, `firmware-mediatek`, `firmware-ti-connectivity`, `firmware-ath9k-htc`, `firmware-carl9170`, `firmware-zd1211` |
| Graphics / GPU / media | `firmware-amd-graphics`, `firmware-intel-graphics`, `firmware-nvidia-graphics`, `firmware-ast`, `firmware-qcom-soc`, `firmware-samsung`, `firmware-siano`, `firmware-ivtv` |
| Audio / Bluetooth / peripheral | `firmware-cirrus`, `firmware-intel-sound`, `firmware-sof-signed`, `bluez-firmware` |

**Notes:** `firmware-linux`/`firmware-linux-nonfree` are metapackages and may already pull `firmware-misc-nonfree`; avoid duplicated intent. `firmware-qcom-media` is a dummy transitional package and intentionally not a useful additional firmware candidate. The list may be trimmed **only after** exact package availability/compatibility verification and review, not merely because hardware is currently absent. CPU microcode (`intel-microcode` or `amd64-microcode`) remains chosen according to detected CPU family, not both indiscriminately.

**Mandatory pre-implementation evidence:** refresh signed APT metadata, run `apt-cache policy` and `apt-get -s install` for the exact final package set with the approved backports pin and other selected profiles (especially OMV), inspect removals and dependency changes, verify that no extra proprietary drivers or DKMS modules are implicitly installed, document packages excluded with reasons, and present the final effective package list for user confirmation. Auto-detection continues even if this extra-package step is unready.

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

If Debian tweaks is not selected, do not silently apply its unique configuration or claim the installation includes the complete Debian tweaks design. **ZRAM, OMV and Docker remain independently selectable**, and the ZRAM profile provides its own technical prerequisites if selected alone. Never silently enable another profile. Compatibility checks still apply. See [08_validation_and_pending.md](08_validation_and_pending.md).

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
