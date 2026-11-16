# Netinst — Native Debian Installer screens

**Ordinary base-install guide:** [01 — Base Debian](../01_base_debian/README.md).

The customized image should preserve the ordinary Debian Installer **manual disk selection and partitioning**, editable locale/keyboard/time/network/account fields, and tasksel. Installer suggestions come from [profile_defaults.conf](my-cdd/profile_defaults.conf), not from the Debian tweaks profile. No disk or partition is automatically selected for conversion.

The desired target is Debian 13 amd64, minimal/headless, SSH server and standard system utilities, without GNOME or a desktop. **Tasksel's current defaults remain editable and may need manual correction** in GTK/text installer. The standard installer asks about firmware, mirrors, users, passwords and reboot; do not create duplicate screens.

The custom late-stage dispatcher checks local root emergency/recovery access before optional operations. If a selected profile fails, the finish-install status guard must avoid reporting misleading success.

Historical disk/layout decisions and observed VM failures: [history/05_base_installation.md](history/05_base_installation.md). Installer test requirements: [08 validation](08_validation_and_pending.md).
