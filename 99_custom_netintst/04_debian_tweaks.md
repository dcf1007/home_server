# Netinst — Apply Debian tweaks during the installation

**Purpose:** describe the **optional non-default** Debian settings that the custom installer applies to the new system. These are independent of Backports, kernel, firmware, ZRAM, OMV and Docker.

For an already installed Debian server, use [06 — Debian tweaks](../06_debian_tweaks/README.md) and edit the files with a normal text editor. The installer does the following **only if Debian tweaks was selected**.

## Step 1 — Change GRUB's default boot arguments

The profile opens `/target/etc/default/grub`, preserving the existing kernel arguments while:

1. Removing the optional `quiet` argument so boot messages remain visible.
2. Adding `fsck.repair=no` if absent, to request **no automatic filesystem repair**.

It then regenerates the target's GRUB configuration. It does **not** reconfigure installer locale/timezone/networking or set passwords: those belong to Debian's standard prompts.

**Why this matters:** manual-only repair is a deliberate recovery policy and can require physical-console intervention after filesystem damage.

## Step 2 — Change only the ext4 root mount options

The profile reads the installed `/target/etc/fstab`. It requires **exactly one** root entry with mount point `/` and type `ext4`; otherwise it stops instead of guessing.

On that one entry it keeps unrelated options, removes conflicting access-time and old `errors=...` values, and sets:

- `noatime` — avoid updating file access times on ordinary reads;
- `errors=panic` — instruct ext4 to panic on detected filesystem errors.

It does **not** change EFI, data drives or any other mount entry. Confirm the resulting options after the first reboot.

## Step 3 — Deny root SSH, only when OpenSSH is installed

The profile does **not** silently install OpenSSH. If Debian's native tasksel selection included SSH, it writes a small target `sshd_config.d` drop-in containing:

~~~text
PermitRootLogin no
~~~

It checks the resulting **effective** SSH daemon configuration and stops if the value is not `no`. If OpenSSH was not selected, it skips this change rather than adding a new service.

This leaves local root-password recovery possible while prohibiting root SSH.

## Step 4 — Maintain the manual-only update policy

The installer inspects target APT's effective periodic-update settings. If unattended upgrades are already disabled, it does not create a redundant file.

If unattended upgrades are enabled, it writes a small APT override to turn them off. Manual `apt-get update` and explicitly approved upgrades remain available. **Disabling automatic upgrades includes security updates**, so regular manual maintenance is necessary.

If OMV 8 is also selected, the later OMV profile applies its own OMV-specific scheduled-update and notification settings as well.

## Step 5 — Validate the actual installed system

After reboot, check that:

- `/proc/cmdline` includes `fsck.repair=no` and does not include `quiet`;
- root is ext4 with `noatime,errors=panic`, if you selected this tweak;
- non-root SSH works and root SSH is denied, when SSH was installed;
- the effective APT periodic-update policy matches your intended manual schedule.

**Installer adaptation:** the exact operations are performed on files under `/target` and commands run through Debian Installer's target environment. The normal guide needs none of that staging.

**Runtime validation remains open.** Implementation: [profile-tweaks.sh](my-cdd/installer/profile-tweaks.sh).
