# 01 — Base Debian 13 installation

**Starting point:** a normal, freshly installed Debian 13 (Trixie) amd64 system. No customized ISO or Simple-CDD is required.

## Install a minimal headless system

Use Debian Installer's normal, interactive partitioning and setup questions. The example home server uses UEFI/GPT, a 256 GB SSD, no LVM or disk encryption, with these manually chosen partitions:

| Partition | Example |
| --- | --- |
| EFI system | 1 GiB FAT32, mounted at `/boot/efi` |
| Root | ext4 on the rest of the SSD, mounted at `/` |
| Optional swap | 16 GiB as a suggestion, new or reused; ordinary swap unless later converted for [ZRAM](../05_zram_writeback/README.md) |

**Always verify the actual disk model and capacity.** Never infer the install target from a fixed `/dev/sdX` path. With no ZRAM, Debian can use ordinary swap. For this project's optional ZRAM writeback, reserve a separate GPT partition and convert it later after explicit approval.

The project's editable example preferences are English, `en_US.UTF-8`, German country, Spanish keyboard, `Europe/Berlin`, DHCP and a router-side address reservation. Hostname, domain and admin username are chosen in the normal installer UI.

At Software selection, enable **SSH server** and **standard system utilities**, and disable desktop/GNOME. A minimal installation with no desktop is required for OMV.

## Confirm the first boot

~~~sh
cat /etc/os-release
uname -m
lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,PARTUUID,MOUNTPOINTS
findmnt -no SOURCE,FSTYPE,OPTIONS /
timedatectl
ip -brief address
sudo apt-get update
sudo dpkg --audit
~~~

Expect Debian `trixie`, x86_64 architecture, the correct disk layout and working network. If SSH is wanted but not installed:

~~~sh
sudo apt-get install openssh-server
sudo systemctl status ssh
~~~

Use the installer-created administrative account; if it lacks sudo, use the authorized root account to grant it deliberately. To support the project's ZRAM emergency recovery, verify local root access with `sudo passwd -S root` and set a password with `sudo passwd root` when necessary. This does **not** enable root SSH.

Next, select only the chapters relevant to your server. Do not apply the optional tweaks or services by default.

References: [Debian 13 installation guide](https://www.debian.org/releases/trixie/amd64/) · [OpenMediaVault installation on Debian](https://docs.openmediavault.org/en/stable/installation/on_debian.html).
