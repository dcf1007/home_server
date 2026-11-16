# 05 — ZSTD ZRAM swap with raw-partition writeback

**Prerequisites:** a working Debian 13 server with a boot-tested **Linux 7.x kernel** (see [03](../03_kernel_7x/README.md)), a usable local root recovery password and one **explicitly selected GPT partition** to dedicate to backing. This is **destructive to that partition**. Do not run it against your root disk, a mounted filesystem, an in-use swap device, LVM, RAID or another system's data.

Unlike [custom Debian Installer](../99_custom_netintst/03_zram_writeback.md), an installed Debian system already has the full `lsblk`, `swapon`, `wipefs`, `sgdisk` and systemd tools. No udebs, `in-target` or low-level `dd` workaround is needed.

## 1. Inspect and select exactly one partition

~~~sh
sudo apt-get update
sudo apt-get install gdisk systemd-zram-generator
uname -r
sudo passwd -S root
lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,PARTTYPE,PARTLABEL,PARTUUID,MOUNTPOINTS
sudo swapon --show
findmnt -no SOURCE,FSTYPE,OPTIONS /
~~~

The example design suggested **16 GiB** of backing, but this is not a hard requirement. If the chosen backing is currently active swap, inspect `free -h` and `swapon --show`; run `sudo swapoff <exact-partition>` **only when sufficient RAM is available and you have approved deactivation**. Recheck that this *exact* device is absent from `swapon --show`. Do not use `swapoff -a`.

From a regular Bash shell, enter the repository's `05_zram_writeback` directory first. Keep that same shell for the later `PART`/`UUID` variables. Replace the prompt value with the **partition path** you inspected—**never the whole disk**:

~~~bash
cd /path/to/home_server/05_zram_writeback  # change to your actual clone path
read -r -p 'Confirmed backing PARTITION path (e.g. /dev/nvme0n1p3): ' PART
PART=$(readlink -f -- "$PART")
test -b "$PART" && test "$(lsblk -dnro TYPE "$PART")" = part || exit 1
DISK="/dev/$(lsblk -dnro PKNAME "$PART")"
NUM=$(lsblk -dnro PARTN "$PART")
test -b "$DISK" && test "$(lsblk -dnro PTTYPE "$DISK")" = gpt || exit 1
lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,PARTTYPE,PARTUUID,MOUNTPOINTS "$DISK"
sudo wipefs "$PART"
sudo swapon --show
findmnt -S "$PART" || true
~~~

Verify manually that `PART` really is the correct GPT swap or previously dedicated raw backing, has **no mounts or block-device holders**, and is inactive as conventional swap. Do not proceed merely because the shell tests succeeded. **Check `lsblk -no PKNAME,PARTN "$PART"` again before a write.**

## 2. Convert only the approved partition

First remove the chosen partition's conventional-swap entry (by UUID, PARTUUID or exact device) from `/etc/fstab` using a text editor, leaving all unrelated entries intact. Keep a copy of the original file for recovery:

~~~sh
sudo cp -a /etc/fstab /etc/fstab.before-zram
sudoedit /etc/fstab
~~~

Make a final explicit decision to destroy the old contents/signatures on **only `$PART`**. On the same root shell:

~~~bash
# Review detected signatures and precise scope before confirming:
sudo wipefs --no-act "$PART"
# After explicit approval:
sudo wipefs --all "$PART"
sudo sgdisk --typecode="$NUM":8300 --change-name="$NUM":zram-writeback "$DISK"
sudo partprobe "$DISK"
sudo udevadm settle
lsblk -no PARTTYPE,PARTLABEL,PARTUUID,FSTYPE "$PART"
sudo blkid -p "$PART" || true
swapon --show
~~~

Here `8300` is the standard Linux filesystem **GPT type code**, **not an instruction to format a filesystem**. `sgdisk` modifies only the chosen partition's GPT entry; `wipefs` operates only on `$PART`, removing detected signatures. Do **not** run `sgdisk --zap-all`, `mklabel`, `mkfs` or `mkswap` on backing. If `partprobe` fails, **stop** and resolve the device reread before proceeding.

Confirm PARTLABEL `zram-writeback`, type GUID `0FC63DAF-8483-4772-8E79-3D69D8477DE4`, no filesystem/swap signature, and no conventional swap activity. The **actual PARTUUID** is read dynamically:

~~~bash
UUID=$(lsblk -dnro PARTUUID "$PART")
test -n "$UUID" || exit 1
printf 'Confirmed ZRAM backing PARTUUID: %s\n' "$UUID"
~~~

## 3. Install the existing ZRAM configuration and monitor

From the same repository directory and shell, copy the source assets. **They are the same planned generator/pressure-monitor assets as the custom installer; first-boot behavior is not yet established.**

~~~sh
sudo install -d -m 755 /etc/systemd/system/systemd-zram-setup@zram0.service.d /etc/sysctl.d /usr/local/sbin
sudo install -m 644 files/10-compressed-writeback.conf /etc/systemd/system/systemd-zram-setup@zram0.service.d/
sudo install -m 644 files/zram-pressure.service /etc/systemd/system/
sudo install -m 755 files/zram-pressure.sh /usr/local/sbin/zram-pressure.sh
sudo install -m 644 files/90-zram-swappiness.conf /etc/sysctl.d/
~~~

Set `UUID` in that shell to the **verified current** PARTUUID from step 2 (do not copy a sample UUID). Generate the config:

~~~bash
test -n "$UUID" || { echo 'Set the confirmed PARTUUID first' >&2; exit 1; }
sed "s/YOUR_PARTUUID/$UUID/g" files/zram-generator.conf.template |
    sudo tee /etc/systemd/zram-generator.conf >/dev/null
sudo grep -F "$UUID" /etc/systemd/zram-generator.conf
~~~

For the project's fail-closed initialization policy (distinct from monitor restarts), add:

~~~sh
sudo tee /etc/systemd/system/systemd-zram-setup@zram0.service.d/20-failure-emergency.conf >/dev/null <<'EOF'
[Unit]
OnFailure=emergency.target
OnFailureJobMode=replace-irreversibly
EOF
~~~

Ensure `zswap.enabled=0` is present in the existing `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` (preserve its other parameters), then `sudo update-grub`. Enable the monitor with `sudo systemctl daemon-reload` and `sudo systemctl enable zram-pressure.service`.

## 4. Reboot and validate, before production use

~~~sh
sudo reboot
~~~

After the system boots on the chosen kernel:

~~~sh
uname -r
swapon --show
lsblk -o NAME,TYPE,FSTYPE,PARTTYPE,PARTLABEL,PARTUUID,MOUNTPOINTS
systemctl status 'systemd-zram-setup@zram0.service' zram-pressure.service
cat /sys/block/zram0/comp_algorithm
cat /sys/block/zram0/compressed_writeback
cat /sys/block/zram0/writeback_limit_enable
cat /sys/block/zram0/bd_stat
sysctl vm.swappiness
journalctl -b -u 'systemd-zram-setup@zram0.service' -u zram-pressure.service
~~~

Expected: `/dev/zram0` is active swap, the physical backing is **not** independently active as swap or mounted, the generator uses the correct PARTUUID, compression/writeback sysfs features are present, and `vm.swappiness=100`. The ZRAM setup's emergency behavior and monitor's restart-on-failure behavior must be tested on a disposable system before relying on them.

**References:** [Linux kernel ZRAM documentation](https://www.kernel.org/doc/html/latest/admin-guide/blockdev/zram.html) · [zram-generator config](https://github.com/systemd/zram-generator/blob/main/man/zram-generator.conf.md) · [wipefs](https://manpages.debian.org/trixie/util-linux/wipefs.8.en.html) · [sgdisk](https://manpages.debian.org/trixie/gdisk/sgdisk.8.en.html).
