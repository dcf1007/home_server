# Netinst — Debian tweaks adaptation

**Normal procedure:** [06 — Debian tweaks](../06_debian_tweaks/README.md).

The installer must not duplicate ordinary localization, user, account, SSH-tasksel or network configuration dialogs. The independently selected [profile-tweaks.sh](my-cdd/installer/profile-tweaks.sh) edits the installed root's `/target/etc/default/grub` and `/target/etc/fstab` to remove `quiet`, add `fsck.repair=no`, and set only the approved root-ext4 `noatime,errors=panic` values.

When OpenSSH exists in the target, the profile adds `PermitRootLogin no` and verifies `sshd -T`. It checks the manual-only package update policy, without installing a redundant override if the defaults already satisfy it. If unselected, Debian's existing settings are left alone.

The installer-specific complexity is file staging under `/target`, native Debconf policy approval and `in-target` verification; none is needed when following the ordinary installed-system chapter.

Historical decisions: [history/04_debian_tweaks.md](history/04_debian_tweaks.md).
