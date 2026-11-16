# 02 — Apply the optional foundational Debian tweaks

**Goal:** configure clear boot messages, a deliberate ext4 root-failure policy, **no root login over SSH**, and a **conditional** check for automatic package upgrades.

Apply this chapter after [01 — Base Debian](../01_base_debian/README.md), before adding Backports, a newer kernel or ZRAM. You should already have a working normal **sudo** account and a separate **local root recovery password**.

The boot and filesystem changes are **opt-in, non-default policies**. They can complicate recovery after hardware or filesystem errors; make them only if you want those behaviors.

## Step 1 — Make boot messages visible and stop automatic filesystem repair

Open `/etc/default/grub` **in a text editor with administrator privileges**. Find the `GRUB_CMDLINE_LINUX_DEFAULT` line:

1. Remove the standalone option `quiet`, if it is present, to show more kernel boot messages.
2. Add `fsck.repair=no` **within the existing quotation marks** so Debian does not automatically repair a damaged filesystem during boot.
3. Preserve every other option. If you later configure [ZRAM](../06_zram_writeback/README.md), its separate `zswap.enabled=0` argument must also be preserved.

Save the file, then regenerate GRUB:

~~~sh
sudo update-grub
~~~

**What this does:** rebuilds GRUB's boot configuration using your edited defaults. Check that it reports no errors and still detects the installed Debian kernels. The argument changes apply after reboot.

**Recovery consequence:** the server may require hands-on intervention when a filesystem needs repair. Confirm the root recovery password from Chapter 01 is usable before continuing.

## Step 2 — Configure only the root filesystem

Identify the filesystem currently mounted as `/`:

~~~sh
findmnt /
~~~

This shows the root source, filesystem type and current mount options. The settings below apply **only** to the root entry in `/etc/fstab`; do not alter other partitions or mount points.

Back up the existing mount instructions:

~~~sh
sudo cp -a /etc/fstab /etc/fstab.before-tweaks
~~~

Open `/etc/fstab` with administrator privileges. Find the single entry whose mount point is `/`. Keep its device identity and every unrelated option, then:

1. Remove any existing `atime`, `relatime`, `strictatime` or duplicate `noatime` option; add **`noatime`** once, regardless of filesystem type.
2. On **ext2, ext3 or ext4**, replace any existing `errors=...` option with **`errors=panic`**.
3. On **Btrfs**, replace any existing `fatal_errors=...` option with **`fatal_errors=panic`**.
4. On **XFS or another filesystem**, retain its own error handling settings. Do **not** insert an unsupported panic mount option.

These options are filesystem-specific: Btrfs's `fatal_errors=panic` is not identical in scope to the ext-family `errors=panic`. See [Linux ext4 documentation](https://docs.kernel.org/admin-guide/ext4.html) and [Btrfs mount options](https://btrfs.readthedocs.io/en/latest/ch-mount-options.html).

Save the file. Invalid root options can prevent normal boot; preserve the backup and your local recovery access.

## Step 3 — Disable root SSH, but keep normal-user SSH

Confirm that your ordinary sudo account can log in via SSH, and keep its existing session open while editing.

Open the **existing** `/etc/ssh/sshd_config` with administrator privileges. Set the following directive **in the global section, before `Include` and `Match` statements**, so it takes precedence over later entries:

~~~text
PermitRootLogin no
~~~

Edit an existing global occurrence instead of adding duplicate active settings where feasible. Do not create a project-specific `sshd_config.d` file. This disables direct root SSH login while retaining the separate local root recovery password.

Because this is a **running** Debian system, validate syntax before reloading SSH:

~~~sh
sudo /usr/sbin/sshd -t
~~~

If this reports an error, correct it before applying the configuration. Otherwise reload SSH without restarting the machine:

~~~sh
sudo systemctl reload ssh
~~~

Open a second SSH session as your ordinary sudo user and confirm access before closing the first.

## Step 4 — Check the actual automatic-update policy

Debian's **`unattended-upgrades` package** is responsible for automatic package installation. The Debian Installer may install and enable it depending on the chosen update policy. **Do not assume it is always present or always absent.** Downloading APT package lists is not the same as installing upgrades automatically.

Check whether this package is actually installed:

~~~sh
dpkg -s unattended-upgrades
~~~

This displays the package's status and description. Look for **`Status: install ok installed`**. If the package is not installed, the command may report it as unknown; **no unattended-upgrades configuration change is necessary**.

If the package **is** installed, inspect the current APT periodic settings:

~~~sh
apt-config dump
~~~

This displays effective APT configuration. Look for the line `APT::Periodic::Unattended-Upgrade`. The value **`"1"`** (or another nonzero value) enables periodic automatic installation; **`"0"`** or no enabled setting means unattended upgrades are not currently requested by this option.

For this project's **manual-only update policy**, **only if automatic upgrades are enabled**, use the package's interactive configuration:

~~~sh
sudo dpkg-reconfigure unattended-upgrades
~~~

This opens Debian's own configuration question. Choose **No** when asked whether to automatically download and install updates. Review any additional prompt before accepting. No custom script or unexplained APT override is needed for this normal Debian workflow.

Recheck the effective configuration using `apt-config dump`. Confirm automatic installation is disabled. If it still shows a nonzero value, an additional local setting may override your choice; review the files in `/etc/apt/apt.conf.d/` before proceeding.

**Important:** choosing manual-only updates means **security updates will not install themselves**. Maintain a routine to run `sudo apt update` and review `sudo apt upgrade`. These operations remain available.

The custom netinst implementation performs this policy step **once, inside the selected Debian tweaks profile**. It edits Debian's existing `20auto-upgrades` setting when present, using a single local override only if necessary. No later installation profile rechecks or changes this update policy. OMV's own update and notification settings remain user-controlled; the OMV CDD profile does not change them.

## Step 5 — Reboot and confirm the changes

Save your work and make sure you have console or recovery access. Reboot to apply the root mount and boot-argument changes:

~~~sh
sudo reboot
~~~

After boot, inspect the actual kernel command line:

~~~sh
cat /proc/cmdline
~~~

Look for `fsck.repair=no` and no standalone `quiet` option; this confirms which parameters the **running kernel** received.

Check the active root mount again:

~~~sh
findmnt /
~~~

For ext4, verify `noatime` and `errors=panic` are present. Confirm you can still use sudo over SSH and that the root account remains usable **locally**, not over SSH.

**Done when:** the selected changes are active and you have not lost administration or local recovery access.

**Next:** [03 — Backports](../03_backports/README.md) if you want newer Debian packages.
