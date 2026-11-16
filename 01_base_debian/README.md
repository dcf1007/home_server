# 01 — Install a minimal Debian 13 server

This guide starts with a **normal Debian installation**. You do not need the custom ISO or any scripts from this repository.

**Result:** Debian 13 (Trixie), a headless server with a working network connection, SSH access and standard system utilities.

## Step 1 — Boot the Debian installer

1. Download the official Debian 13 **amd64 netinst** image from the [Debian website](https://www.debian.org/distrib/netinst).
2. Write it to a USB drive and boot the computer.
3. Choose **Graphical install** or **Install**.
4. Answer the normal questions about language, keyboard, network, hostname, accounts and time zone.

For this project's example server, the suggested settings are English, the `en_US.UTF-8` locale, Spanish keyboard, Germany, `Europe/Berlin` time zone and DHCP. **These are examples, not hardcoded requirements.**

Keep a working local administrator or root password. It is useful if a later ZRAM problem requires emergency-mode recovery.

## Step 2 — Choose the disks yourself

At **Partition disks**, choose **Manual**. Review the actual disk model and capacity before selecting anything.

The example setup uses a 256 GB SSD, UEFI boot, GPT, and no LVM or encryption:

| Partition | What to select |
| --- | --- |
| EFI System Partition | 1 GiB, FAT32, mount point `/boot/efi` |
| Root | ext4, mount point `/`, using the remaining space |
| Optional swap partition | Around 16 GiB as an example; change this size to suit your system |

If you plan to use the optional [ZRAM writeback guide]( ../06_zram_writeback/README.md), reserve a separate swap partition now. It will be converted later, **only after you approve that destructive change**. Otherwise, a normal swap partition can stay as swap.

**Before accepting the installer's partition changes**, check the selected disk and every partition again. Do not copy device names from an example.

## Step 3 — Select the installed software

At **Software selection**:

1. Select **SSH server**.
2. Select **standard system utilities**.
3. Deselect **Debian desktop environment**, **GNOME** and any other desktop.

Finish the installer and reboot into Debian.

## Step 4 — Check the new system

Sign in with the account you created. Run these commands one at a time.

Check the Debian version:

This reads Debian’s release information without changing anything. Look for `PRETTY_NAME` or `VERSION_ID` identifying **Debian 13 (Trixie)**; if it is another release, these instructions may not apply.

~~~sh
cat /etc/os-release
~~~

Look for `Debian GNU/Linux 13` and `trixie`.

Check that the machine is 64-bit:

This prints the CPU architecture of the running system. Look for `x86_64`, which confirms the amd64 system expected by these guides.

~~~sh
uname -m
~~~

The expected result for this project is `x86_64`.

Review the disks and mount points:

This lists disks and partitions, their sizes, filesystem types and where they are mounted. Identify the root mount `/` and any swap partition; **this is inspection only** and does not modify the disks.

~~~sh
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
~~~

Confirm that the expected disk contains your root filesystem and, if selected, the optional swap partition.

Check network addresses and the clock:

This displays each network interface and its IP address in a compact form. Find the address of your active wired or wireless interface; if it has no usable address, investigate network setup before continuing.

~~~sh
ip -brief address
~~~

This shows the system clock, time zone and synchronization status. Confirm the time zone matches your choice and that the clock is correct before downloading packages.

~~~sh
timedatectl
~~~

Finally, refresh package information:

This downloads the latest package **indexes** from your configured repositories. It does **not** install or upgrade packages. Look for successful repository refreshes and stop if APT reports signature or download errors.

~~~sh
sudo apt update
~~~

If your administrator account does not have `sudo`, use the root account created during installation (`su -`) and run the administrative commands without `sudo`. Do not grant privileges to an unknown account.

## Step 5 — Check SSH and recovery access

If you selected SSH server in the installer, check its status:

This asks systemd whether the SSH server is running. Look for `active (running)`; if it is inactive, inspect the reported error before relying on remote access.

~~~sh
sudo systemctl status ssh
~~~

It should be running. If you did not select SSH but now want it, install it explicitly:

This installs OpenSSH Server from Debian only if you have chosen to make the server accessible over SSH. APT will show the packages and ask for approval; afterwards check the SSH service status.

~~~sh
sudo apt install openssh-server
~~~

Test logging in as your normal user from another computer before depending on SSH for administration.

For the optional ZRAM emergency-recovery policy, check local root password status:

This shows the *status* of the local root account password without revealing it. In Debian’s output, `P` means a usable password and `L` means locked; confirm your planned emergency login is actually possible.

~~~sh
sudo passwd -S root
~~~

If root is locked or has no usable password, and you want local emergency recovery, set one interactively:

This interactively **sets or changes the local root password**. You will be asked to type it twice; use this only if you decided you need emergency recovery, and store the password securely.

~~~sh
sudo passwd root
~~~

This does **not** allow root SSH logins.

**Done when:** Debian boots from the correct disk, you can administer it, the network works and the required packages can be retrieved. Continue with whichever optional guide you want; none is mandatory.

**Reference:** [Debian 13 installation guide](https://www.debian.org/releases/trixie/amd64/).
