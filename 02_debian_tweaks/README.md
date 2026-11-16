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

## Step 2 — Configure the ext4 root filesystem

First identify the filesystem mounted as `/`:

~~~sh
findmnt /
~~~

This reports its source, type and currently active mount options. **Only proceed if the filesystem type is `ext4`.** If you installed a different filesystem, skip this step.

Back up the mount table before editing it:

~~~sh
sudo cp -a /etc/fstab /etc/fstab.before-tweaks
~~~

This saves the existing mount instructions to a separate file. It does not change active mounts.

Open `/etc/fstab` in a text editor **with administrator privileges**. Find the entry whose mount point is `/` and filesystem type is `ext4`. In **that entry's option field only**:

1. Add `noatime`, reducing filesystem access-time writes.
2. Add `errors=panic`, instructing ext4 to panic when it detects a filesystem error.
3. Remove conflicting access-time settings and previous `errors=...` options.
4. Preserve every unrelated option, the root filesystem's identity and all other entries.

Save the file. Incorrect `fstab` entries can prevent booting; do not change the EFI or NAS data-drive entries.

## Step 3 — Disable root SSH, but keep normal-user SSH

Make sure you can already sign in over SSH using the regular sudo administrator from Chapter 01. **Keep that existing session open** while changing SSH configuration.

Ensure the dedicated SSH configuration directory exists:

~~~sh
sudo mkdir -p /etc/ssh/sshd_config.d
~~~

This creates a directory only if needed; it does not change the running SSH daemon.

Open `/etc/ssh/sshd_config.d/01-home-server-root.conf` in a text editor **with administrator privileges**, enter this single configuration line, and save:

~~~text
PermitRootLogin no
~~~

This denies **SSH connections directly as root** while preserving the local root password for physical-console and emergency recovery.

Check the configuration syntax **without reloading SSH**:

~~~sh
sudo /usr/sbin/sshd -t
~~~

No output and a successful return normally mean the syntax is valid. If an error appears, fix it before continuing.

Now display the daemon's effective options:

~~~sh
sudo /usr/sbin/sshd -T
~~~

Find `permitrootlogin no`. If another value appears, investigate other SSH configuration files before reloading.

Apply the change to the running SSH daemon:

~~~sh
sudo systemctl reload ssh
~~~

This rereads SSH configuration. **Open a second SSH session as your normal user**, confirm it works, and only then close the first.

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

The custom netinst implementation makes this same check **inside the installed target** and creates an override **only if the package exists and automatic installations are enabled**. OMV's own update and notification settings remain user-controlled; the OMV CDD profile does not change them.

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
