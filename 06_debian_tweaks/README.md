# 06 — Apply optional Debian tweaks

These are **deliberate changes to Debian's defaults**, not necessary steps for every server. You can apply them independently of Backports, ZRAM, OMV and Docker.

**Before starting:** you have a working administrator account and console or SSH access. Keep a recovery route available when changing boot or SSH settings.

## Step 1 — Show boot messages and disable automatic filesystem repairs

Open GRUB's configuration:

~~~sh
sudo nano /etc/default/grub
~~~

Find the line beginning with `GRUB_CMDLINE_LINUX_DEFAULT=`.

1. Remove the word `quiet`, if present.
2. Add `fsck.repair=no` inside the existing quotation marks.
3. Leave all other kernel parameters intact (including `zswap.enabled=0` if you configured [ZRAM](../05_zram_writeback/README.md)).

Save the file, then update GRUB:

~~~sh
sudo update-grub
~~~

The new settings take effect after the next reboot. **Manual-only filesystem repair means the system may refuse to boot normally when the filesystem is damaged; plan for local recovery access.**

## Step 2 — Set the root filesystem mount options

First look at the root filesystem:

~~~sh
findmnt /
~~~

Proceed only if the root filesystem is **ext4**. If it is another filesystem, skip this step.

Back up the mount table:

~~~sh
sudo cp -a /etc/fstab /etc/fstab.before-tweaks
~~~

Open it:

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

~~~sh
sudo mkdir -p /etc/ssh/sshd_config.d
~~~

Open a separate configuration file:

~~~sh
sudo nano /etc/ssh/sshd_config.d/01-home-server-root.conf
~~~

Put **one line** in it:

~~~text
PermitRootLogin no
~~~

Save and check for configuration errors:

~~~sh
sudo /usr/sbin/sshd -t
~~~

If the command reports an error, fix it **before** reloading SSH.

Show the effective SSH settings:

~~~sh
sudo /usr/sbin/sshd -T
~~~

Find `permitrootlogin no`. If another rule overrides it, investigate before moving on.

Finally, reload SSH:

~~~sh
sudo systemctl reload ssh
~~~

Open a **second** SSH login as your normal administrator to verify you will not be locked out.

## Step 4 — Keep package updates manual

Look at the current APT settings:

~~~sh
apt-config dump
~~~

If automatic upgrades and periodic package-list refreshes are already disabled, no new file is needed.

Otherwise, edit a dedicated APT configuration file:

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

~~~sh
sudo reboot
~~~

Then verify the boot parameters:

~~~sh
cat /proc/cmdline
~~~

You should see `fsck.repair=no` and no `quiet` parameter.

Check the actual root mount options:

~~~sh
findmnt /
~~~

When the root filesystem is ext4, look for `noatime` and `errors=panic`.

**Done when:** only the changes you deliberately selected are active, SSH administration still works and you have a working recovery route.
