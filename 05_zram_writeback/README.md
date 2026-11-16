# 05 — Set up ZSTD ZRAM with SSD writeback

**What this does:** creates compressed swap in RAM (`/dev/zram0`) and gives it a dedicated disk partition for writing older pages out when needed. The physical partition is **not** mounted or used as ordinary swap.

**Important:** This is the project's experimental ZRAM writeback design. Its actual Linux 7.x compatibility, monitor behavior and emergency recovery still need a **disposable VM test**. Do not use the first attempt on a disk containing important data.

Before starting, complete [03 — Linux 7.x](../03_kernel_7x/README.md) and make sure you have a working **local root recovery password**. You need a **separate GPT partition** that you are willing to dedicate completely to ZRAM. The example size is 16 GiB, but it is not fixed.

## Step 1 — Install the ordinary Debian tools

~~~sh
sudo apt update
~~~

~~~sh
sudo apt install gdisk systemd-zram-generator
~~~

Unlike the custom installer, a normal Debian system already has `lsblk`, `wipefs` and `swapon`. There is no need for udebs, `in-target` or a custom `dd` command.

## Step 2 — Identify the backing partition

~~~sh
lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,PARTTYPE,PARTLABEL,PARTUUID,MOUNTPOINTS
~~~

Read the output carefully. Identify **one partition**, not a whole disk.

For example, if a partition is named `/dev/nvme0n1p3`:

- Its **partition device** is `/dev/nvme0n1p3`.
- Its **parent disk** is `/dev/nvme0n1`.
- Its **partition number** is `3`.

**Those names are examples only. Your system will be different.** Never copy the example disk name without checking the actual output. The target must be a GPT partition, not your root filesystem, an EFI partition, a mounted filesystem, an LVM/RAID member or another system's data.

Check which swap devices are active:

~~~sh
sudo swapon --show
~~~

If your chosen partition appears here, check current RAM and swap use:

~~~sh
free -h
~~~

Only if there is sufficient available RAM **and you approve deactivating this exact swap partition**, turn it off. Replace the example with your selected partition:

~~~sh
sudo swapoff /dev/YOUR_PARTITION
~~~

Run `sudo swapon --show` again. **Do not continue if the partition is still active.** Never use `swapoff -a` for this task.

Also confirm the partition has **no mount point or device-mapper/RAID holders** in the `lsblk` device tree. If its purpose is uncertain, stop here.

## Step 3 — Remove only its old swap entry

Back up the existing mount configuration:

~~~sh
sudo cp -a /etc/fstab /etc/fstab.before-zram
~~~

Open it:

~~~sh
sudo nano /etc/fstab
~~~

Find the **one entry for your selected swap partition**. Its source may be shown as a filesystem UUID rather than a device name. Compare that UUID with the selected partition in `lsblk` before removing the entry.

Remove or comment out **only that swap entry**. Leave root, EFI and all other mounts unchanged. Save the file.

If another tool or service separately activates the same swap partition, disable that activation too. This disk partition must never be activated as ordinary swap again.

## Step 4 — Prepare the chosen partition

**This step permanently makes the selected partition unsuitable for its old purpose.** Confirm the partition name, parent disk and number one final time.

You can see the current signatures without changing anything:

~~~sh
sudo wipefs /dev/YOUR_PARTITION
~~~

Replace `YOUR_PARTITION` with the real name. If you see a filesystem you did **not** intend to destroy, stop.

When you have explicitly approved destroying the selected partition's previous contents, erase its signatures:

~~~sh
sudo wipefs --all /dev/YOUR_PARTITION
~~~

Now set its GPT partition type to **Linux data (8300)** and give it the name **zram-writeback**:

~~~sh
sudo sgdisk --typecode=YOUR_NUMBER:8300 --change-name=YOUR_NUMBER:zram-writeback /dev/YOUR_DISK
~~~

Replace **both** `YOUR_NUMBER` entries with the selected partition number and `YOUR_DISK` with its parent disk, as identified in Step 2.

This changes only that partition's GPT type and name. It does **not** format a filesystem. Do not use `sgdisk --zap-all`, `mklabel`, `mkfs` or `mkswap` here. If the partition table cannot be refreshed because the disk is in use, reboot and recheck the partition before proceeding.

## Step 5 — Record the real PARTUUID

~~~sh
lsblk -o NAME,PATH,SIZE,FSTYPE,PARTTYPE,PARTLABEL,PARTUUID,MOUNTPOINTS
~~~

Check that the chosen partition now:

- Has GPT type `0FC63DAF-8483-4772-8E79-3D69D8477DE4` (type code **8300**).
- Has partition name `zram-writeback`.
- Has **no filesystem/swap type** and is **not mounted**.
- Is absent from `sudo swapon --show`.

Copy its **PARTUUID** somewhere safe temporarily. That is the real identifier to use below. **Do not copy the example PARTUUID of another machine.**

## Step 6 — Copy the ZRAM configuration files

If you cloned this repository into your home directory, open the ZRAM chapter folder:

~~~sh
cd ~/home_server/05_zram_writeback
~~~

If you cloned it elsewhere, use your actual directory.

Copy the project's generator configuration:

~~~sh
sudo cp files/zram-generator.conf.template /etc/systemd/zram-generator.conf
~~~

Edit the copy:

~~~sh
sudo nano /etc/systemd/zram-generator.conf
~~~

Replace **both occurrences** of `YOUR_PARTUUID` with the PARTUUID you recorded in Step 5. Leave the rest of the file unchanged. This template describes the project's intended ZSTD compression, RAM limits and backing device.

Install the pressure-monitor and swappiness files:

~~~sh
sudo cp files/90-zram-swappiness.conf /etc/sysctl.d/
~~~

~~~sh
sudo cp files/zram-pressure.service /etc/systemd/system/
~~~

~~~sh
sudo cp files/zram-pressure.sh /usr/local/sbin/
~~~

~~~sh
sudo chmod 755 /usr/local/sbin/zram-pressure.sh
~~~

Create the service override directory:

~~~sh
sudo mkdir -p /etc/systemd/system/systemd-zram-setup@zram0.service.d
~~~

Copy the writeback setting:

~~~sh
sudo cp files/10-compressed-writeback.conf /etc/systemd/system/systemd-zram-setup@zram0.service.d/
~~~

## Step 7 — Configure the project's failure behavior

The project's policy is to attempt **emergency mode if ZRAM initialization fails**, but to **restart** the pressure monitor if only the monitor fails.

Open a service override file:

~~~sh
sudo nano /etc/systemd/system/systemd-zram-setup@zram0.service.d/20-failure-emergency.conf
~~~

Paste the following **file contents** and save:

~~~ini
[Unit]
OnFailure=emergency.target
OnFailureJobMode=replace-irreversibly
~~~

This is an intended policy, **not a verified emergency-mode guarantee**. Test the actual behavior in a VM before relying on it.

Open GRUB's existing configuration:

~~~sh
sudo nano /etc/default/grub
~~~

Find `GRUB_CMDLINE_LINUX_DEFAULT` and add `zswap.enabled=0` **inside the existing quotation marks**, preserving other options. That disables the separate kernel zswap feature so it does not compete with this ZRAM design.

~~~sh
sudo update-grub
~~~

## Step 8 — Enable the monitor and reboot

~~~sh
sudo systemctl daemon-reload
~~~

~~~sh
sudo systemctl enable zram-pressure.service
~~~

~~~sh
sudo reboot
~~~

## Step 9 — Verify the running system

After reboot:

~~~sh
uname -r
~~~

The running kernel must still be 7.x.

~~~sh
swapon --show
~~~

You should see `/dev/zram0`, **not** the original disk partition as ordinary swap.

~~~sh
zramctl
~~~

Check that ZRAM is using ZSTD compression.

~~~sh
sudo systemctl status systemd-zram-setup@zram0.service
~~~

~~~sh
sudo systemctl status zram-pressure.service
~~~

~~~sh
cat /sys/block/zram0/compressed_writeback
~~~

For the intended compressed writeback design, the setting should show **1**.

~~~sh
cat /sys/block/zram0/bd_stat
~~~

This shows backing-device activity counters. It is normal for them to be zero immediately after startup.

~~~sh
sysctl vm.swappiness
~~~

The expected value for this optional ZRAM profile is **100**.

If anything fails, inspect the readable service logs:

~~~sh
sudo journalctl -b -u systemd-zram-setup@zram0.service
~~~

~~~sh
sudo journalctl -b -u zram-pressure.service
~~~

**Do not declare this production-ready solely because the units started.** Confirm actual writeback under controlled pressure and test the emergency/restart behavior on a disposable system.

**References:** [Kernel ZRAM documentation](https://www.kernel.org/doc/html/latest/admin-guide/blockdev/zram.html) · [zram-generator settings](https://github.com/systemd/zram-generator/blob/main/man/zram-generator.conf.md).
