# 06 — Set up ZSTD ZRAM with SSD writeback

**What this does:** creates compressed swap in RAM (`/dev/zram0`) and gives it a dedicated disk partition for writing older pages out when needed. The physical partition is **not** mounted or used as ordinary swap.

**Important:** This is the project's experimental ZRAM writeback design. Its actual Linux 7.x compatibility, monitor behavior and emergency recovery still need a **disposable VM test**. Do not use the first attempt on a disk containing important data.

Before starting, complete [04 — Linux 7.x](../04_kernel_7x/README.md) and make sure you have a working **local root recovery password**. You need a **separate GPT partition** that you are willing to dedicate completely to ZRAM. The example size is 16 GiB, but it is not fixed.

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

Open `/etc/fstab` in a text editor with administrator privileges; review the existing content, make the described change and save the file.

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
cd ~/home_server/06_zram_writeback
~~~

If you cloned it elsewhere, use your actual directory.

Copy the project's generator configuration. **If `/etc/systemd/zram-generator.conf` already exists, inspect and back it up first** rather than overwriting another ZRAM setup without review:

This copies the provided generator template into systemd’s configuration location. The file tells ZRAM how large to be and which disk partition supplies writeback. **It overwrites an existing file at that destination**, so inspect and back up any existing configuration first.

~~~sh
sudo cp files/zram-generator.conf.template /etc/systemd/zram-generator.conf
~~~

Edit the copy:

This opens the **installed copy** of the generator configuration. Replace the two `YOUR_PARTUUID` placeholders with the actual identifier recorded earlier; if the two values differ or still contain placeholders, the device will not be configured as intended.

Open `/etc/systemd/zram-generator.conf` in a text editor with administrator privileges; review the existing content, make the described change and save the file.

Replace **both occurrences** of `YOUR_PARTUUID` with the PARTUUID you recorded in Step 5. Leave the rest of the file unchanged. This template describes the project's intended ZSTD compression, RAM limits and backing device.

Install the pressure-monitor and swappiness files:

This copies the project’s `vm.swappiness=100` setting into `/etc/sysctl.d`, where system settings can be applied at startup. It is a deliberate swap-policy change, not a prerequisite for unrelated Debian installations.

~~~sh
sudo cp files/90-zram.conf /etc/sysctl.d/
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

This installs the **single** setup override: it enables compressed writeback before ZRAM initialization and requests emergency mode if ZRAM setup itself fails. The monitor has its own restart policy and must not force emergency mode. Both failure paths still require testing in a disposable VM.

~~~sh
sudo cp files/override.conf /etc/systemd/system/systemd-zram-setup@zram0.service.d/
~~~

If you previously installed this project's older `10-compressed-writeback.conf` and `20-failure-emergency.conf` drop-ins, review and remove those superseded files so the setting is applied only once. Preserve any unrelated local overrides.

## Step 7 — Disable zswap and understand the failure policy

Open GRUB's existing configuration:

This opens GRUB’s configuration for editing boot options. Add `zswap.enabled=0` inside the existing parameter quotes to disable the separate zswap mechanism. Preserve other options and keep a working fallback kernel.

Open `/etc/default/grub` in a text editor with administrator privileges; review the existing content, make the described change and save the file.

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

## Step 10 — Run the standalone writeback diagnostic (disposable VM only)

After Step 9 succeeds, run [`files/test_zram.py`](files/test_zram.py) on a quiet disposable VM with console recovery available. This is a manual diagnostic of the running system, not an installer profile, persistent service or production workload. It deliberately generates memory pressure and backing-device writes; the first run of a new version is not appropriate on a production server. It requires Python 3 (standard library only), systemd, cgroup v2 with the memory controller, and the configured ZRAM device and active pressure service. No dependencies are installed automatically.

Download the current version into a working directory where the test logs can be saved:

~~~sh
wget -O test_zram.py https://raw.githubusercontent.com/dcf1007/home_server/main/06_zram_writeback/files/test_zram.py
sudo python3 test_zram.py
~~~

No command-line arguments are needed. The test runs the following phases in order, using temporary bounded worker units. It does not change the production service, sysctl configuration, swap priorities or backing partition, directly write to ZRAM's idle/writeback sysfs interfaces, or execute global swapoff.

| Phase | Test procedure and evidence |
| --- | --- |
| Normal | Prefill toward 76% resident-limit occupancy, age the cold pages for 65 seconds, then apply hot memory pressure. Require a journal-confirmed normal trigger (80–94% occupancy, PSI some avg10 at least 5%), an age-based cycle with positive backing-write delta, and increased backing writes. Phase timeout: 360 seconds. |
| Emergency | Stop the hot workload, allow 35 seconds for cooldown, and refill toward 97%. Require a trigger at 95% or above, the explicit emergency-branch journal message and positive cycle writes. Phase timeout: 240 seconds. |
| Readback | Work through retained allocations oldest first. Read and verify each page against its individual SHA-256 digest, flip and check its first bit, restore and check that bit, and immediately discard the verified anonymous page using MADV_DONTNEED. Require all allocated bytes to be verified and discarded and a positive backing-read delta. There is no overall readback deadline or cold-worker runtime limit; 300 seconds without reported page progress is inconclusive. |

The cold workload is split into **exact thirds by page count and logical bytes**: repeated non-uniform 64-byte patterns (highly compressible), independently generated random data (typically incompressible), and nonzero repeated-byte pages (to exercise ZRAM's same-element optimization rather than anonymous zero-page sharing). Each allocation is rounded to a multiple of three pages; the separate hot pressure worker is not included in these proportions.

The terminal shows phase-specific live tables, progress and service journal messages, followed by phase results and per-population allocated/discarded totals. Both timestamped `test_zram_*.log` and `test_zram_*.csv` files are created automatically in the working directory (UTC timestamp and process ID; existing logs are not overwritten). Preserve both for subsequent analysis. The CSV includes original data, compressed payload, actual resident memory, same-element and incompressible-page counters, backing activity and progress. Version 5 retains the no-backing compression sample and additionally estimates resident logical volume as original logical bytes minus occupied backing bytes (4 KiB per bd_stat unit), with resident payload and RAM savings calculated against that volume. It reports the largest consistent resident sample. Backing counters are read around mm_stat; visibly changing or inconsistent samples are suppressed. These reads are not atomic, so the estimates are diagnostic rather than exact. It also reports the same-element logical volume/share and the payload ratio excluding same-element logical pages, when available. These are **device-wide** measurements, not per-class compression benchmarks. Same-element entries need no separate compressed payload but still require metadata; backing-device reads/writes and logical allocation sizes are not interchangeable.

Exit status: 0 = all three pass; 1 = failure; 2 = inconclusive; 130 = interrupted. Ctrl+C requests cleanup of the transient test units. An inconclusive result means the required evidence or test conditions were not obtained; it is not sufficient to identify a service defect. Version 5 removes the fixed three-times-resident-limit allocation multiplier. Before each allocation it checks actual free logical swap and usable backing capacity (blockdev size rounded to full pages, excluding slot zero). Pending eligible backing bytes are estimated as original logical bytes minus same-element logical bytes and occupied backing bytes. Existing occupied and pending slots are counted once. The controller reserves 15% of initially free logical swap and backing capacity, conservatively charges current cold-worker cgroup resident memory and reserves hot-worker capacity during normal pressure. Every additional cold triplet requires three logical swap page slots and at most two full backing page slots under the inspected full-page backing model. The lesser available triplet count determines the next allocation allowance, with the existing bounded batch size and system RAM checks. A cold-worker cgroup swap ceiling remains based on initial logical swap availability. If a sample is inconsistent, allocation waits for a fresh sample; if capacity is exhausted, the diagnostic can still be inconclusive. CSV records the capacity estimates, reserves and resident ratios. The model assumes the kernel's full-page backing slots and exclusion of same-element pages from writeback; verify those assumptions on the running kernel. The estimates can conservatively overreserve due to swap-cache overlap. Readback duration is workload- and device-dependent; use the measured progress/ETA rather than a fixed completion-time promise.

### Parallel readback and timing (v6)

The cold worker detects its allowed logical CPUs with `os.sched_getaffinity(0)` and configures four readback threads per available CPU. For example, four allowed vCPUs give 16 threads. There is no adaptive thread-count benchmark or arbitrary concurrency cap. An allocation containing fewer pages than threads uses only as many page-processing lanes as it has pages; the thread pool is created on demand for readback. Each block is processed in oldest-first order, with independent pages within that block assigned to disjoint lanes. Completion within a block can be out of order; progress and per-population counters use actual completed pages. Native `ctypes.CDLL` memcpy and madvise operations release the Python GIL; SHA-256, bit modification/restoration, and immediate per-page discard remain required. Worker memory limits, watchdog and capacity-based allocation remain in effect. Native thread stacks are set to 256 KiB; thread creation failure is reported rather than silently reducing the requested concurrency.

The readback table displays configured processing lanes for the current/recent block, not an instantaneous count of simultaneously executing threads. The final timing table and CSV report summed per-thread wall and CPU times for retrieval, SHA-256, bit modification/restoration and discard, mean wall time per completed page, and major/minor page faults. When available, the CSV also records interval read latency and average queue depth from the backing block device's sysfs stat file, and system-wide CPU steal from /proc/stat. These aggregate counters include activity outside the worker and block-layer measurements may include VM storage overhead. Retrieval timing includes page faults, scheduling, kernel processing and native copying; it does not independently measure physical NVMe I/O or decompression. Summed thread times can exceed elapsed phase time. Actual speedup is not yet measured; there is no sequential speed baseline within the v6 test.

### Diagnostic revision history — 2026-11-20

| Revision | Changes |
| --- | --- |
| [v1](https://github.com/dcf1007/home_server/commit/b01976e5b0923c5e939e261eb07ebca0d0e88853) | Sequential normal/emergency/readback test, 75% random/25% zero bytes per cold page, fixed 180-second readback timeout. |
| [v2](https://github.com/dcf1007/home_server/commit/c9356e6d39e4e7f62d46537eff54841419bd77bb) | Compact tables, timestamped text and CSV logs, explicit oldest-first bit modification/restoration; allocation-dependent readback deadline and 120-second inactivity watchdog (superseded). |
| [v3](https://github.com/dcf1007/home_server/commit/aa7639974c8c1f6eac1962f9a0047d38203435ec) | Equal repeated-pattern/random page populations, per-page checksums and immediate discard, no overall readback deadline, 300-second inactivity watchdog, compression statistics. |
| [v4](https://github.com/dcf1007/home_server/commit/2a6862f9325f00f0e846b28f55311bfc205144df) | Exact thirds including nonzero same-element pages, per-population accounting, same-element raw counters and comparable compression metrics. |
| [v5](https://github.com/dcf1007/home_server/commit/1f8b89c5c0cb91d54b7ad779631a7d70a2fb3cb6) | Adaptive capacity-based allocation replacing the resident-limit multiplier; separate logical swap, backing-slot and resident compression accounting. |
| [v6](https://github.com/dcf1007/home_server/commit/c226e0d38a52c17ec1eb57f9784e5adc34a122ed) | Four readback threads per available logical CPU, native GIL-releasing page operations, actual per-type completion counts and timing/fault/storage telemetry. Current version. |

**Validation boundary:** The user's v1 VM screenshot reported PASS for normal and emergency writeback, INCONCLUSIVE for readback after the 180-second timeout, 2,290.4 MiB backing writes, 396.8 MiB backing reads, 395.7 MiB verified, and successful cleanup. This is evidence of that run, not proof of completed readback integrity. Versions 2–4 were locally checked for Python syntax and their respective anonymous-memory worker, accounting and reporting behavior; Version 5 source was checked against the approved allocation model and retrieved from its commit; actual ZRAM and transient systemd behavior for the revised script still require a VM run. No production-source or installer changes are included in these diagnostic revisions.

**References:** [Kernel ZRAM documentation](https://www.kernel.org/doc/html/latest/admin-guide/blockdev/zram.html) · [zram-generator settings](https://github.com/systemd/zram-generator/blob/main/man/zram-generator.conf.md).
