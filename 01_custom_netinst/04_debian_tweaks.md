# 04 — Selectable **Debian tweaks** profile

**Status:** approved settings and implementation requirements; no installed scripts/ISO are claimed. **Recorded:** 2026-11-14. **Provenance:** all Debian customizations outside regular installer menus as requested by the user.

**Boundary:** This profile includes non-menu Debian configuration only. **Do not include ZRAM**: it belongs to [07_zram_writeback.md](07_zram_writeback.md). Standard installer questions remain interactive, see [03_base_installation.md](03_base_installation.md).

## APT, kernel and firmware

- Configure official repositories and the **provisional backports priority 900**, with stable/security/updates normally at 500, **only after passing compatibility checks** in [02_backports_apt.md](02_backports_apt.md).
- Install `linux-image-amd64` and `linux-headers-amd64` from `trixie-backports` **before first reboot**. Keep a stable kernel available initially. Retain Debian's default kernel cleanup; no extra holds or special retention.
- Automatically detect CPU vendor and install `intel-microcode` or `amd64-microcode` from the Debian firmware component.
- Apply Debian's normal firmware detection **plus additional proactive firmware packages**. The actual package list remains undecided, so the installation cannot claim this requirement complete until it is approved.
- Retain Debian's `initramfs-tools`, `MODULES=most` and default Zstandard initramfs compression.
- Update GRUB: `GRUB_TIMEOUT_STYLE=menu`, `GRUB_TIMEOUT=5`, `GRUB_DEFAULT=0`; remove `quiet` but do not enable debug logging.
- Preserve root SSH prohibition `PermitRootLogin no`; preserve initial SSH password access for `david`. Validate after OMV installation if OMV selected.

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
- Ensure `david` has sudo, prompt for a separate root password **after** creating `david` and **before** first reboot, without passwords/hashes on the USB.
- No firewall filtering during installer setup.
- Display a meaningful configuration review/confirmation before non-menu customization where practical; log what was applied.

## Conditional profile semantics

If Debian tweaks is not selected, do not silently apply its unique configuration and do not claim the installation matches the full DCF1007 server design. OMV, Docker and ZRAM profiles remain independently selectable, but compatibility tests may rule out unsafe combinations. See [08_validation_and_pending.md](08_validation_and_pending.md).

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
sudo -l -U david
sudo sshd -T | grep -i permitrootlogin
```

These checks alone are **not** proof that every proposed integration succeeds. Do not run or assume results until the corresponding profile is actually installed.
