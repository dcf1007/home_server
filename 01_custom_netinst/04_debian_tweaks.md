# 04 — Optional Debian tweaks profile

**Status:** requirements only; profile scripts and installation have not been built or tested. **Updated:** 2026-11-14. **Provenance:** installation choices, updated to omit settings already implemented by Debian's normal defaults. All optional profiles remain unchecked unless explicitly selected.

## Scope

Apply only the **non-default operating-system changes** below. Do **not** duplicate ordinary Debian Installer answers in this profile. Normal GUI questions and editable suggested values are in [profile_defaults.conf](profile_defaults.conf); disk layout is in [05 — Base installation](05_base_installation.md).

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
- The earlier requirement for a **visible GRUB menu, five-second timeout and first (newest) kernel** remains an installation acceptance condition. **Do not rewrite `GRUB_DEFAULT=0`, `GRUB_TIMEOUT=5` or `GRUB_TIMEOUT_STYLE=menu` if Debian already provides that behavior.** If the installed GRUB configuration differs, show the necessary change for confirmation rather than silently altering it.

### Filesystem mount and repair policy

- Add **`noatime`** for the ext4 root filesystem and **`errors=panic`** for detected ext4 filesystem errors. Review the actual generated `/etc/fstab` and apply only these non-default mount options; keep ordinary ext4 defaults otherwise.
- Require **`fsck.repair=no`** instead of systemd's normal `preen` (which automatically fixes errors considered safe). This preserves the approved **manual-only filesystem repair** policy. Do **not** redundantly set `fsck.mode=auto`, which is already systemd's default. Test the selected bootloader/kernel-command-line integration before implementation.

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

### Custom date/number presentation (unvalidated)

- Preserve the user's requested **YYYY/MM/DD** date display, **24-hour** time, decimal separator **`.`**, and thousands grouping **a space**. These are not automatically produced by the GUI-selected `en_US.UTF-8` locale.
- Do not claim this is implemented without determining which locale/application settings can produce the combination, then obtaining any necessary confirmation. Do not override the selected timezone, keyboard or locale without approval.

## Default behaviors deliberately left untouched

The profile makes **no** changes for Debian's ordinary filesystem layout, reserved ext4 blocks, ext4 ordered journaling, GRUB default-entry selection, normal kernel panic timeout, default filesystem-check scheduling, journal-size defaults, default package recommendations, normal NTP behavior, standard hardware detection or baseline privacy/firewall choices. Those do not justify new settings in this optional profile.

All disk targeting/formatting remains in the normal Debian Installer. No automatic kernel selection, Backports activation, unrelated hardware packages or other optional profiles.

## Acceptance (illustrative, not completed)

```sh
cat /proc/cmdline
findmnt -no FSTYPE,OPTIONS /
grep -E '^GRUB_(TIMEOUT|TIMEOUT_STYLE|DEFAULT)=' /etc/default/grub
sudo sshd -T | grep -i permitrootlogin
apt-config dump | grep -E 'Periodic|Unattended'
journalctl --list-boots
```

Verify `fsck.repair=no` is effective in the booted target system, and that the GRUB menu behavior is correct without unnecessary overrides. If the custom date/number display requirement is unsatisfied, retain it as an open implementation checkpoint.

**No implementation claim:** documentation is updated, but no resulting ISO, profile, booted kernel or service state has been tested.
