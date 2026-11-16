# Netinst — Follow the Debian Installer screens

**Purpose:** explain the actual experience of booting the custom ISO, choosing optional profiles, installing a minimal Debian base system, and letting the installer safely execute those profiles before first boot.

## Step 1 — Boot the custom ISO in a disposable VM

After [building the image](01_custom_cdd_preparation.md), boot it using Debian Installer's **Graphical install** or **Install** option.

The ordinary Debian Installer still controls network, keyboard, language, storage, user accounts and software selection. The project does **not** automate disk selection or bypass native confirmation dialogs. ISO boot menus and both graphical/text Debconf behavior remain subjects of the test plan.

## Step 2 — Select your optional profiles

The image should show the normal Simple-CDD profile multiselect. There are seven available options:

1. Backports.
2. Ensure Linux 7.x kernel.
3. Extended device support (firmware and both CPU microcode packages).
4. ZSTD ZRAM writeback.
5. Debian tweaks.
6. OpenMediaVault 8.
7. Docker.

**All should start unchecked.** Select only what you want. **ZRAM requires you to select Ensure Linux 7.x separately**; the installer will not add it automatically. The order in the menu does not change the actual execution order.

The next screen shows **Selected** or **Not selected** for all seven items. Examine the entire summary. The default answer to **Proceed?** is **No**. Select **No** to return to the list, or **Yes** only when it matches your intention. This approval **does not** approve packages, firmware omissions, swap deactivation or partition conversion.

The early hook registers a completion guard and retains the exact approved selection. If the screen cannot be shown or the set is invalid, installation should stop rather than silently continue.

## Step 3 — Complete Debian's normal configuration

Follow the native installer questions. [`profile_defaults.conf`](my-cdd/profile_defaults.conf) proposes, but should not force:

- English, `en_US.UTF-8`, country Germany, Spanish keyboard and Europe/Berlin;
- DHCP, an example hostname/domain, and an editable initial administrator name;
- SSH server and standard utilities, **without GNOME**.

At partitioning, choose **Manual** and explicitly select the real target disk. The sample server uses UEFI/GPT, an EFI partition, ext4 root and an optional swap partition. **No disk/device path is predetermined.** If you selected ZRAM, provide a suitable separate swap partition for later conversion; the partition is ordinary swap until the selected ZRAM stage runs.

At tasksel's **Software selection**, manually confirm SSH server + standard utilities and **deselect desktop/GNOME**. Current Debian tasksel may show unexpected defaults; the intended checkbox state has **not** been proven automatically.

## Step 4 — Finish base installation and reach the custom late stage

Debian first prepares `/target`: the new Debian system mounted under the installer's root. The custom late-stage dispatcher executes before the normal final "Installation complete" dialog.

It checks the original approved list has not changed. Before executing any optional profile, it checks whether the new system's **root account has a usable local password**. If locked/passwordless, it uses the **normal Debian Installer password questions** to set and confirm one without saving the secret in project files/logs. Local recovery is required even for a base-only run.

If selected profiles require APT, the dispatcher checks Debian Installer's native **service-start suppression** for target package installation, rather than masking services at first boot. It also disables only active installer `cdrom:` entries in the target APT source lists so network package updates will work; it does not remove network sources.

## Step 5 — Review each selected action

The dispatcher runs the profiles in the fixed order listed in Step 2, **skipping unchecked profiles entirely**. For package operations, it performs an APT simulation in `/target`, displays the complete plan and requests a **default-No** approval before running target `apt-get` through Debian Installer progress reporting. Removal or omission decisions may have additional individual prompts.

Read the corresponding detailed page **before** selecting a profile:

- [Backports](02_backports_apt.md), [Linux 7.x](09_ensure_7x_kernel.md), [extended firmware](10_extended_device_support.md);
- [ZRAM partition conversion](03_zram_writeback.md);
- [Debian tweaks](04_debian_tweaks.md), [OMV](06_openmediavault.md), [Docker](07_docker.md).

The confirmation and removal dialogs are **part of the installer**, not commands you type on the target system.

## Step 6 — Confirm completion, logs and first boot

Each successful selected stage writes a completion record. The custom finish-install guard should block a misleading normal-success screen if status is incomplete or a selected profile did not finish.

Installed-target logs are written to:

- `/var/log/installer/my-cdd.log` — ordered operation log;
- `/var/log/installer/my-cdd-status` — `INCOMPLETE`, `FAILED` or `COMPLETE`;
- `/var/log/installer/my-cdd-completed/` — a record for each completed selected profile.

If any step fails, **do not interpret Debian's ordinary success message alone as confirmation**. Preserve logs for troubleshooting. The success guard itself has not passed full VM validation.

After reboot, verify normal SSH/recovery access and the effects of every selected profile, especially the **actual running 7.x kernel and ZRAM writeback**. The new ISO remains experimental until [08 — Validation](08_validation_and_pending.md) is complete.
