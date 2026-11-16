# 01 — Install a minimal Debian 13 server

**Goal:** install headless Debian 13 (Trixie), create a regular user with **sudo** privileges, and establish a separate **local root password for recovery and emergency mode**. Root SSH access will be disabled in [02 — Debian tweaks](../02_debian_tweaks/README.md).

You do not need the custom ISO or any repository scripts for this chapter.

## Step 1 — Boot the ordinary Debian installer

1. Download the official **Debian 13 amd64 netinst** image from the [Debian website](https://www.debian.org/distrib/netinst).
2. Write the image to USB media, boot the server and choose **Graphical install** or **Install**.
3. Answer the ordinary language, keyboard, network, hostname and time-zone questions.

Example preferences for this project are English / `en_US.UTF-8`, a Spanish keyboard, Germany / `Europe/Berlin`, and DHCP. These are examples **you can change**.

## Step 2 — Leave the initial root password empty

When Debian Installer asks you to configure the **root (administrator) password**:

1. Leave the **root password** field completely empty.
2. Leave its **confirmation** field completely empty.
3. Continue and acknowledge Debian's explanation of sudo administration.

**Why:** Debian Installer disables direct root login at this stage and arranges for the **first normal user** to use `sudo`. This lets you do everyday administration with your personal account, without logging in as root.

Next, let Debian Installer create a **regular user**. Enter that person's name, a chosen username and a strong **user password**. This regular account is the one you will log in with after installation.

**Do not set the root password in the installer at this stage.** We will establish it separately, *after confirming sudo works*, in Step 6. The root password and the user's own password are distinct credentials.

## Step 3 — Partition the correct disk

At **Partition disks**, choose **Manual**. Identify the intended disk from its device name, model and capacity before making changes.

An example layout for a 256 GB SSD uses UEFI/GPT, no LVM or encryption:

| Partition | Example purpose |
| --- | --- |
| EFI system partition | 1 GiB FAT32 mounted at `/boot/efi` |
| Root partition | ext4 mounted at `/` |
| Optional separate swap partition | Around 16 GiB reserved if you plan to follow [06 — ZRAM writeback](../06_zram_writeback/README.md) |

These are **not** fixed device names or required sizes. If you do not plan to use ZRAM writeback, you can keep ordinary Debian swap. Do not modify another operating system's partitions without understanding the consequences.

**Before approving writes**, confirm the exact disk and each mount point in Debian Installer's own summary.

## Step 4 — Install a headless system

At Debian's **Software selection**, select:

- **SSH server**;
- **standard system utilities**.

Deselect **Debian desktop environment**, **GNOME** and other desktops. Finish the installer and boot the installed Debian system.

## Step 5 — Verify the first user can administer Debian

Log in as your **regular user**. These commands are for **inspection only** unless otherwise stated.

~~~sh
cat /etc/os-release
~~~

This shows the installed operating system. Confirm it says Debian GNU/Linux **13** and `trixie`.

~~~sh
uname -m
~~~

This reports the machine architecture. Expect `x86_64` for the amd64 build.

~~~sh
id
~~~

This shows the account you're using and its group memberships. Confirm your regular account is listed and that its groups include **`sudo`**. If not, **stop** and investigate the account setup instead of attempting administrative changes blindly.

~~~sh
sudo id -u
~~~

This asks `sudo` to run the identity check as the administrator. Type **your regular user's password** when prompted. The expected result is **`0`**, the numeric ID of root. If this command fails, resolve the sudo issue before moving on.

## Step 6 — Create a local root password for recovery

Debian's normal rescue/emergency shell may use `sulogin`, which requires a usable **local root password**. Because you deliberately left it empty in Step 2, set one **now**, once you know `sudo` works.

~~~sh
sudo passwd root
~~~

This starts the system's interactive password-change command for **root**. It requests your regular account's sudo password (if necessary), then the **new root password twice**. Choose a separate strong password and keep it in a secure recovery location.

It changes the local root account password; **it does not enable root login over SSH**.

Verify the account state:

~~~sh
sudo passwd -S root
~~~

This displays root's password **status**, not the password itself. In Debian's output, `root P ...` indicates a usable password; `L` indicates a locked account. If root is still locked, stop and resolve it before relying on rescue or emergency mode.

**Why not skip this step?** A server can work normally with sudo while its root account remains locked, but an emergency login requiring a root password could then be inaccessible. Setting the password after sudo validation provides both everyday least-privilege administration and emergency recovery.

## Step 7 — Check network, storage, time and SSH

~~~sh
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
~~~

This displays the disks, partitions, filesystem types and mount points. Check that `/` and `/boot/efi` belong to the intended disk and any reserved ZRAM swap is the one you created.

~~~sh
ip -brief address
~~~

This shows network-interface addresses. Identify the assigned IP address on the active interface; there should be one if you intend to administer the machine remotely.

~~~sh
timedatectl
~~~

This displays the time, time zone and synchronization status. Confirm they match your choices.

~~~sh
sudo systemctl status ssh
~~~

This checks whether the installed OpenSSH service is running. Look for `active (running)`. If you intentionally omitted SSH during installation, this check does not apply.

~~~sh
sudo apt update
~~~

This **downloads current package indexes** from the configured Debian repositories; it does not install or upgrade packages. Check for signature or network errors. If APT fails, investigate the repository setup before the next optional chapter.

**Done when:** your regular user can use sudo, root has a usable **local recovery password**, Debian boots from the correct disk, and the intended network and SSH access work.

**Next:** [02 — Debian tweaks](../02_debian_tweaks/README.md). That guide makes root SSH inaccessible while preserving the local root password.

**Reference:** [Debian 13 amd64 installation guide](https://www.debian.org/releases/trixie/amd64/).
