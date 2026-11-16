# 06 — Apply optional Debian tweaks

These are **deliberate changes to Debian's defaults**, not necessary steps for every server. You can apply them independently of Backports, ZRAM, OMV and Docker.

**Before starting:** you have a working administrator account and console or SSH access. Keep a recovery route available when changing boot or SSH settings.

## Step 1 — Show boot messages and disable automatic filesystem repairs

Open GRUB's configuration:

This opens GRUB’s boot-parameter configuration. You are editing the existing line so Linux shows more boot messages and does not automatically repair a damaged filesystem; **do not replace the other parameters**.

~~~sh
sudo nano /etc/default/grub
~~~

Find the line beginning with `GRUB_CMDLINE_LINUX_DEFAULT=`.

1. Remove the word `quiet`, if present.
2. Add `fsck.repair=no` inside the existing quotation marks.
3. Leave all other kernel parameters intact (including `zswap.enabled=0` if you configured [ZRAM]( ../06_zram_writeback/README.md)).

Save the file, then update GRUB:

This regenerates GRUB’s boot menu configuration from your edited defaults. Check for errors; the new kernel arguments will apply **after reboot**, not immediately.

~~~sh
sudo update-grub
~~~

The new settings take effect after the next reboot. **Manual-only filesystem repair means the system may refuse to boot normally when the filesystem is damaged; plan for local recovery access.**

## Step 2 — Set the root filesystem mount options

First look at the root filesystem:

This shows which device supplies `/`, its filesystem type and current mount options. **Check the FSTYPE column**: the planned `noatime,errors=panic` edit applies only if the root filesystem is ext4.

~~~sh
findmnt /
~~~

Proceed only if the root filesystem is **ext4**. If it is another filesystem, skip this step.

Back up the mount table:

This makes a backup of `/etc/fstab`, which defines boot-time mounts. It preserves your working root and EFI entries in case the manual edit needs to be reversed.

~~~sh
sudo cp -a /etc/fstab /etc/fstab.before-tweaks
~~~

Open it:

This opens `/etc/fstab` for a **manual change to only the root ext4 entry**. Adjust just its comma-separated options; an incorrect device, UUID or mount point could stop the system booting.

~~~sh
sudo nano /etc/fstab
~~~

Find the line whose mount point is `/` and filesystem type is `ext4`. In its comma-separated options field:

1. Add `noatime` (reduces access-time writes).
2. Add `errors=panic` (causes a kernel panic on detected ext4 errors).
3. Remove conflicting `atime` or `errors=...` options **from that root entry only**.
4. Preserve other options and every other mount.

Save the file. Do not change the root filesystem's device or UUID.

## Step 3 — Deny root login over SSH

Skip this step if you did **not** install OpenSSH. Make sure you can already log in remotely using a normal administrator account.

Create the SSH configuration directory if necessary:

This creates the SSH drop-in configuration directory if necessary. It does **not** change SSH permissions or reload the server on its own.

~~~sh
sudo mkdir -p /etc/ssh/sshd_config.d
~~~

Open a separate configuration file:

This opens a new SSH settings file. Its only intended setting is the `PermitRootLogin no` line shown below; it blocks **remote root SSH**, not local root recovery.

~~~sh
sudo nano /etc/ssh/sshd_config.d/01-home-server-root.conf
~~~

Put **one line** in it:

~~~text
PermitRootLogin no
~~~

Save and check for configuration errors:

This checks SSH configuration syntax without reloading the service. **No output and a successful return normally mean the syntax is valid.** If errors appear, correct them before continuing.

~~~sh
sudo /usr/sbin/sshd -t
~~~

If the command reports an error, fix it **before** reloading SSH.

Show the effective SSH settings:

This displays SSH’s effective configuration, including options from other configuration files. Find **`permitrootlogin no`**; if you instead see `yes`, `prohibit-password` or another value, investigate why your change is not effective.

~~~sh
sudo /usr/sbin/sshd -T
~~~

Find `permitrootlogin no`. If another rule overrides it, investigate before moving on.

Finally, reload SSH:

This tells an already-running SSH service to reload its configuration without stopping current sessions. Confirm a **new login as the normal administrator** works before closing the existing one.

~~~sh
sudo systemctl reload ssh
~~~

Open a **second** SSH login as your normal administrator to verify you will not be locked out.

## Step 4 — Keep package updates manual

Look at the current APT settings:

This displays APT’s effective configuration, including periodic update settings. Locate `APT::Periodic::Update-Package-Lists` and `APT::Periodic::Unattended-Upgrade`; if they are already off, you do not need to add a duplicate override.

~~~sh
apt-config dump
~~~

If automatic upgrades and periodic package-list refreshes are already disabled, no new file is needed.

Otherwise, edit a dedicated APT configuration file:

This opens a new APT configuration override. The two lines shown below disable **automatic package-list refreshes and unattended upgrades**, including automatic security updates; they do not prevent manual APT use.

~~~sh
sudo nano /etc/apt/apt.conf.d/99-home-server-manual-updates
~~~

Paste these **file contents**:

~~~text
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
~~~

Save, then check `apt-config dump` again. This deliberately disables automatic updates, **including security upgrades**. Remember to run `sudo apt update` and `sudo apt upgrade` yourself regularly.

## Step 5 — Reboot and check

This reboots to apply the new boot arguments and root mount options. Save your work and ensure console recovery access, because a wrong `/etc/fstab` entry can prevent normal startup.

~~~sh
sudo reboot
~~~

Then verify the boot parameters:

This prints the kernel command line used for the **current** boot. Check for `fsck.repair=no` and absence of `quiet`; it also lets you see whether earlier ZRAM parameters were preserved.

~~~sh
cat /proc/cmdline
~~~

You should see `fsck.repair=no` and no `quiet` parameter.

Check the actual root mount options:

This displays the root filesystem’s **effective mounted options** after reboot. If root is ext4, verify `noatime` and `errors=panic`; if they are absent, check the root entry you edited.

~~~sh
findmnt /
~~~

When the root filesystem is ext4, look for `noatime` and `errors=panic`.

**Done when:** only the changes you deliberately selected are active, SSH administration still works and you have a working recovery route.
