# 05 — Set up ZSTD ZRAM with SSD writeback

**What this does:** creates compressed swap in RAM (`/dev/zram0`) and gives it a dedicated disk partition for writing older pages out when needed. The physical partition is **not** mounted or used as ordinary swap.

**Important:** This is the project's experimental ZRAM writeback design. Its actual Linux 7.x compatibility, monitor behavior and emergency recovery still need a **disposable VM test**. Do not use the first attempt on a disk containing important data.

Before starting, complete [03 — Linux 7.x]( ../04_kernel_7x/README.md) and make sure you have a working **local root recovery password**. You need a **separate GPT partition** that you are willing to dedicate completely to ZRAM. The example size is 16 GiB, but it is not fixed.

## Step 1 — Install the ordinary Debian tools

This refreshes package indexes so Debian can find the two tools needed below. It **does not install anything**; check for repository errors before continuing.

~~~sh
sudo apt update
~~~

This installs **`gdisk`** (which provides `sgdisk` for editing GPT partition metadata) and **`systemd-zram-generator`** (which configures ZRAM swap). Review APT’s package list before accepting. Installing the generator alone does not activate this project's writeback setup.

~~~sh
sudo apt install gdisk systemd-zram-generator
~~~

Unlike the custom installer, a normal Debian system already has `lsblk`, `wipefs` and `swapon`. There is no need for udebs, `in-target` or a custom `dd` command.

## Step 2 — Identify the backing partition

This displays block devices and their filesystem UUIDs, partition UUIDs, filesystem types, sizes and mounts. **Use the PATH and TYPE columns to distinguish the whole disk from individual partitions.** Record the chosen partition, its parent disk, its number and its existing swap UUID; this command changes nothing.

~~~sh
lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,UUID,PARTUUID,MOUNTPOINTS
~~~

Read the output carefully. Identify **one partition**, not a whole disk.

For example, if a partition is named `/dev/nvme0n1p3`:

- Its **partition device** is `/dev/nvme0n1p3`.
- Its **parent disk** is `/dev/nvme0n1`.
- Its **partition number** is `3`.

**Those names are examples only. Your system will be different.** Never copy the example disk name without checking the actual output. The target must be a GPT partition, not your root filesystem, an EFI partition, a mounted filesystem, an LVM/RAID member or another system's data.

Check which swap devices are active:

This lists swap devices currently enabled by the kernel. If the intended backing partition is listed, it must be **safely deactivated** before conversion; do not mistake a different swap device for the chosen one.

~~~sh
sudo swapon --show
~~~

If your chosen partition appears here, check current RAM and swap use:

This shows total RAM, available RAM, and used swap. It helps you judge whether the system can survive moving any used swap pages into RAM. **It cannot guarantee swapoff will succeed**; if the system is low on memory, do not attempt conversion.

~~~sh
free -h
~~~

Only if there is sufficient available RAM **and you approve deactivating this exact swap partition**, turn it off. Replace the example with your selected partition:

This disables swap **only on the named partition**; replace `/dev/YOUR_PARTITION` with the real device you approved. This can exhaust memory if the swap contains pages that cannot fit in RAM. It should succeed and the partition should disappear from `swapon --show`; if it fails, **stop**.

~~~sh
sudo swapoff /dev/YOUR_PARTITION
~~~

Run `sudo swapon --show` again. **Do not continue if the partition is still active.** Never use `swapoff -a` for this task.

Also confirm the partition has **no mount point or device-mapper/RAID holders** in the `lsblk` device tree. If its purpose is uncertain, stop here.

## Step 3 — Remove only its old swap entry

Back up the existing mount configuration:

This makes a backup of `/etc/fstab`, the file that tells Debian which filesystems and swap devices to activate on boot. The `.before-zram` copy lets you restore the original configuration if you make a mistake; it does not alter the active swap state.

~~~sh
sudo cp -a /etc/fstab /etc/fstab.before-zram
~~~

Open it:

This opens the boot-time mount/swap list for manual editing. **Find the exact selected swap device by its original filesystem UUID**, then remove or comment out only its swap line. A different swap, the root filesystem and the EFI mount must stay untouched.

~~~sh
sudo nano /etc/fstab
~~~

Find the **one entry for your selected swap partition**. Its source may be shown as a filesystem UUID rather than a device name. Compare that UUID with the selected partition in `lsblk` before removing the entry.

Remove or comment out **only that swap entry**. Leave root, EFI and all other mounts unchanged. Save the file.

If another tool or service separately activates the same swap partition, disable that activation too. This disk partition must never be activated as ordinary swap again.

## Step 4 — Prepare the chosen partition

**This step permanently makes the selected partition unsuitable for its old purpose.** Confirm the partition name, parent disk and number one final time. `wipefs` removes recognizable signatures; it does **not securely erase all previous data**.

You can see the current signatures without changing anything:

This displays recognized signatures (such as `swap`) on the **single specified partition** without erasing them. Compare the result with the identity you recorded; an unexpected filesystem or signature means you should **stop and investigate**.

~~~sh
sudo wipefs /dev/YOUR_PARTITION
~~~

Replace `YOUR_PARTITION` with the real name. If you see a filesystem you did **not** intend to destroy, stop.

When you have explicitly approved destroying the selected partition's previous contents, erase its signatures:

This **destructively erases recognizable on-disk signatures** from the single specified partition, so it will no longer be recognized as conventional swap. It does not securely erase all data. Execute this only after confirming the exact partition and approving the loss of its old contents; do not target the whole disk.

~~~sh
sudo wipefs --all /dev/YOUR_PARTITION
~~~

Now set its GPT partition type to **Linux data (8300)** and give it the name **zram-writeback**:

This changes the chosen GPT partition’s **type** to Linux data (`8300`) and its **name** to `zram-writeback` in the parent disk’s partition table. Replace `YOUR_NUMBER` and `/dev/YOUR_DISK` with the confirmed values, **not the example names**. It does not create a filesystem or delete other partitions; stop on any error.

~~~sh
sudo sgdisk --typecode=YOUR_NUMBER:8300 --change-name=YOUR_NUMBER:zram-writeback /dev/YOUR_DISK
~~~

Replace **both** `YOUR_NUMBER` entries with the selected partition number and `YOUR_DISK` with its parent disk, as identified in Step 2.

This changes only that partition's GPT type and name. It does **not** format a filesystem. Do not use `sgdisk --zap-all`, `mklabel`, `mkfs` or `mkswap` here. If the partition table cannot be refreshed because the disk is in use, reboot and recheck the partition before proceeding.

## Step 5 — Record the real PARTUUID

This re-lists the live partition table, including GPT type, label and PARTUUID, after conversion. Check **the selected partition only** for type `8300`, name `zram-writeback`, no filesystem signature and no mount point. Record its current PARTUUID; this is inspection, not a formatting command.

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

This changes your shell’s working folder to the repository’s ZRAM guide so subsequent `files/...` paths refer to the correct source assets. If you cloned the repo elsewhere, adjust the path; nothing on the system is configured by changing directories.

~~~sh
cd ~/home_server/05_zram_writeback
~~~

If you cloned it elsewhere, use your actual directory.

Copy the project's generator configuration. **If `/etc/systemd/zram-generator.conf` already exists, inspect and back it up first** rather than overwriting another ZRAM setup without review:

This copies the provided generator template into systemd’s configuration location. The file tells ZRAM how large to be and which disk partition supplies writeback. **It overwrites an existing file at that destination**, so inspect and back up any existing configuration first.

~~~sh
sudo cp files/zram-generator.conf.template /etc/systemd/zram-generator.conf
~~~

Edit the copy:

This opens the **installed copy** of the generator configuration. Replace the two `YOUR_PARTUUID` placeholders with the actual identifier recorded earlier; if the two values differ or still contain placeholders, the device will not be configured as intended.

~~~sh
sudo nano /etc/systemd/zram-generator.conf
~~~

Replace **both occurrences** of `YOUR_PARTUUID` with the PARTUUID you recorded in Step 5. Leave the rest of the file unchanged. This template describes the project's intended ZSTD compression, RAM limits and backing device.

Install the pressure-monitor and swappiness files:

This copies the project’s `vm.swappiness=100` setting into `/etc/sysctl.d`, where system settings can be applied at startup. It is a deliberate swap-policy change, not a prerequisite for unrelated Debian installations.

~~~sh
sudo cp files/90-zram-swappiness.conf /etc/sysctl.d/
~~~

This copies the systemd service definition for the pressure-triggered ZRAM writeback monitor. The service file describes how the monitor starts and restarts; copying it alone does **not** start the monitor.

~~~sh
sudo cp files/zram-pressure.service /etc/systemd/system/
~~~

This installs the monitoring script under `/usr/local/sbin`, the path referenced by its systemd service. It is the project's planned pressure/writeback policy, and **has not been runtime-validated** against your selected kernel.

~~~sh
sudo cp files/zram-pressure.sh /usr/local/sbin/
~~~

This makes the copied monitoring script executable, so systemd can run it when the service starts. Without this permission the service may fail even if the script file exists.

~~~sh
sudo chmod 755 /usr/local/sbin/zram-pressure.sh
~~~

Create the service override directory:

This creates the systemd override directory for ZRAM device setup. The directory lets you add the writeback setting and emergency failure policy without replacing the package’s main service file.

~~~sh
sudo mkdir -p /etc/systemd/system/systemd-zram-setup@zram0.service.d
~~~

Copy the writeback setting:

This copies a short systemd override that enables the kernel’s **compressed writeback** interface before ZRAM setup. It depends on the running kernel exposing that interface; if it does not, setup may fail.

~~~sh
sudo cp files/10-compressed-writeback.conf /etc/systemd/system/systemd-zram-setup@zram0.service.d/
~~~

## Step 7 — Configure the project's failure behavior

The project's policy is to attempt **emergency mode if ZRAM initialization fails**, but to **restart** the pressure monitor if only the monitor fails.

Open a service override file:

This opens a new systemd override file for your chosen failure policy. The following `[Unit]` text belongs **inside that file**; it asks systemd to enter emergency mode if ZRAM setup fails. The actual emergency behavior is not yet verified.

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

This opens GRUB’s configuration for editing boot options. Add `zswap.enabled=0` inside the existing parameter quotes to disable the separate zswap mechanism. Preserve other options and keep a working fallback kernel.

~~~sh
sudo nano /etc/default/grub
~~~

Find `GRUB_CMDLINE_LINUX_DEFAULT` and add `zswap.enabled=0` **inside the existing quotation marks**, preserving other options. That disables the separate kernel zswap feature so it does not compete with this ZRAM design.

This regenerates the GRUB configuration after the change above. Check the output for errors and detection of the expected kernels; the modified boot parameter applies after reboot.

~~~sh
sudo update-grub
~~~

## Step 8 — Enable the monitor and reboot

This instructs systemd to re-read the new service definitions and overrides. It does not start ZRAM or reboot the machine.

~~~sh
sudo systemctl daemon-reload
~~~

This enables the ZRAM pressure-monitor service **for future boots**. It does not itself prove the monitor can run or that compressed writeback works; verify after reboot.

~~~sh
sudo systemctl enable zram-pressure.service
~~~

This reboots the server to apply the kernel, GRUB, generator and service changes. **Save work and ensure console recovery access first**, because the experimental ZRAM setup may affect boot and swap behavior.

~~~sh
sudo reboot
~~~

## Step 9 — Verify the running system

After reboot:

This reports the **running** kernel after reboot. Confirm it is still the previously tested 7.x kernel; if it is a different branch, stop before evaluating ZRAM.

~~~sh
uname -r
~~~

The running kernel must still be 7.x.

This lists active swap devices after boot. You want `/dev/zram0` to appear and the former physical backing **not** to appear as ordinary swap. If the physical partition is active, do not run writeback tests.

~~~sh
swapon --show
~~~

You should see `/dev/zram0`, **not** the original disk partition as ordinary swap.

This describes configured ZRAM devices, their compression algorithms and disk usage. Look for `zram0` using the expected compressor; it is a **read-only check**, not a writeback trigger.

~~~sh
zramctl
~~~

Check that ZRAM is using ZSTD compression.

This asks systemd whether the ZRAM setup unit succeeded. Look for a successful/active or completed setup state and no failed result. If it failed, inspect its journal before changing anything else.

~~~sh
sudo systemctl status systemd-zram-setup@zram0.service
~~~

This shows whether the ZRAM **pressure monitor** is running. A working setup unit does not imply this monitor works; check for repeated failures and diagnose its own logs if necessary.

~~~sh
sudo systemctl status zram-pressure.service
~~~

This reads the kernel’s compressed-writeback capability/state flag. For this design the output should be **`1`**; a missing file or a different value means you must not claim compressed writeback works.

~~~sh
cat /sys/block/zram0/compressed_writeback
~~~

For the intended compressed writeback design, the setting should show **1**.

This displays raw ZRAM backing-device counters. They may all be zero immediately after boot; this command **does not cause writes**. Only controlled testing can demonstrate that pages actually reach backing storage.

~~~sh
cat /sys/block/zram0/bd_stat
~~~

This shows backing-device activity counters. It is normal for them to be zero immediately after startup.

This reads the kernel’s current swappiness preference. The intended value is **`100`**. If it differs, check the installed sysctl file and whether settings were applied.

~~~sh
sysctl vm.swappiness
~~~

The expected value for this optional ZRAM profile is **100**.

If anything fails, inspect the readable service logs:

This displays systemd journal entries from the **current boot** for the ZRAM setup unit. Use errors here to diagnose missing devices, generator configuration and kernel interfaces; this command changes nothing.

~~~sh
sudo journalctl -b -u systemd-zram-setup@zram0.service
~~~

This displays journal entries from the current boot for the pressure-monitor service. Look for initialization errors, rejected sysfs operations or repeated restarts; reading the log does not activate writeback.

~~~sh
sudo journalctl -b -u zram-pressure.service
~~~

**Do not declare this production-ready solely because the units started.** Confirm actual writeback under controlled pressure and test the emergency/restart behavior on a disposable system.

**References:** [Kernel ZRAM documentation](https://www.kernel.org/doc/html/latest/admin-guide/blockdev/zram.html) · [zram-generator settings](https://github.com/systemd/zram-generator/blob/main/man/zram-generator.conf.md).
