# 04 — Optional Debian tweaks profile

**Status:** Debian tweaks installer-stage routine is now written in `my-cdd/installer/profile-actions.sh`, with its separate completion checker. **Not installed, executed or verified on Debian 13.** **Updated:** 2026-11-14. **Provenance:** installation choices, updated to omit settings already implemented by Debian's normal defaults. All optional profiles remain unchecked unless explicitly selected.

## Scope

Apply only the **non-default operating-system changes** below. Do **not** duplicate ordinary Debian Installer answers in this profile. Normal GUI questions and editable suggested values are in [profile_defaults.conf](my-cdd/profile_defaults.conf); disk layout is in [05 — Base installation](05_base_installation.md).

The following are **independently selected** and never activated by Debian tweaks:

- [02 — Backports](02_backports_apt.md): optional repository, priority 100 and reviewed package upgrade/cleanup.
- [09 — Ensure 7.x kernel branch](09_ensure_7x_kernel.md): optional Linux 7.x kernel and matching headers.
- [10 — Extended device support](10_extended_device_support.md): additional CPU microcode and firmware.
- [03 — ZRAM](03_zram_writeback.md): compressed swap/writeback with its own explicit kernel-profile dependency.
- [06 — OpenMediaVault](06_openmediavault.md) and [07 — Docker](07_docker.md).

**Menu order:** Backports → Ensure 7.x kernel branch → Extended device support → ZRAM → Debian tweaks → OMV → Docker.

## Deliberate changes beyond Debian's defaults

### Boot messages

- **Remove the `quiet` kernel command-line parameter** to retain normal boot messages; do not enable extra debug logging.
- The previously approved **visible GRUB menu with a five-second timeout**, booting the newest installed kernel by default, remains a **validation requirement**, not a reason to rewrite settings already supplied by Debian. Only propose corrections if actual installed behavior differs, with explicit approval.

### Filesystem mount and repair policy

- Add **`noatime`** for the ext4 root filesystem and **`errors=panic`** for detected ext4 filesystem errors. Review the actual generated `/etc/fstab` and apply only these non-default mount options; keep ordinary ext4 defaults otherwise.
- Require **`fsck.repair=no`** instead of systemd's default `preen`, which can automatically repair errors considered safe. This preserves the explicit **manual-only filesystem repair** policy. Validate the effective kernel-command-line setting before implementation.

### SSH access

- Explicitly enforce **`PermitRootLogin no`**, stronger than the common Debian/OpenSSH default `prohibit-password`; verify effective `sshd -T` after installation and, if selected, after OMV.
- Administrator identity, sudo permissions and initial password-based SSH access are decided in the base installation; **preserve** those confirmed values rather than overriding them here.

### Package-update guard

- Enforce the approved **manual-only update policy**: no unattended package installation, including security upgrades, and no automatic reboot for updates.
- Debian's baseline normally does not mandate unattended upgrades. **Do not install a redundant override merely to restate that default.** If another selected package enables unattended upgrades, explicitly disable the effective behavior, using a dedicated APT setting where necessary:

  ```text
  APT::Periodic::Unattended-Upgrade "0";
  ```

- Check `apt-config dump` and relevant timers/services after selected profiles run. The explicitly approved **one-time, user-confirmed Backports upgrade** is separate and remains permitted.

## Acceptance (illustrative, not completed)

```sh
cat /proc/cmdline
findmnt -no FSTYPE,OPTIONS /
grep -E '^GRUB_(TIMEOUT|TIMEOUT_STYLE|DEFAULT)=' /etc/default/grub
sudo sshd -T | grep -i permitrootlogin
apt-config dump | grep -E 'Periodic|Unattended'
```

Verify `fsck.repair=no` is effective in the booted target system, and that the GRUB menu behavior is correct without unnecessary overrides.

**No implementation claim:** documentation is updated, but no resulting ISO, profile, booted kernel or service state has been tested.
