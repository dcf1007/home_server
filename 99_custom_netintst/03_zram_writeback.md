# Netinst — ZRAM writeback adaptation

**Simple full-Debian procedure:** [05 — ZRAM writeback](../05_zram_writeback/README.md). Use that guide on an already installed system; it relies on normal `lsblk`, `wipefs` and `sgdisk`.

The minimal Debian Installer environment **does not provide the full util-linux toolkit**. Its selected ZRAM module uses:

- `parted-udeb` for the standard GPT type GUID `8300` and PARTLABEL `zram-writeback`;
- `util-linux-udeb` for native `blkid` partition probing, plus installer `/sys/class/block`, `/proc/swaps` and `/proc/self/mountinfo`;
- BusyBox `swapoff` for the approved, exact active partition;
- BusyBox `dd` to zero only the first 1 MiB of that confirmed partition, instead of needing a target `wipefs` binary;
- `/target/etc/fstab` and a dynamically verified PARTUUID for the generator.

The selected partition is not deleted, resized or formatted. No disk-specific PARTUUID is hardcoded. The code keeps user confirmation, duplicate-PARTUUID checks, mount/holder rejection and memory reserve before swapoff. An unselected ZRAM profile must never touch the partition.

**Integration-only requirements:** an explicitly completed 7.x kernel profile, native GTK/text selection and default-No destructive consent, packaging both official udebs into the ISO, and carrying the original generator/monitor files into `/target`.

Sources: [profile-zram.sh](my-cdd/installer/profile-zram.sh), [zram-selection.sh](my-cdd/installer/zram-selection.sh), [scripts](my-cdd/scripts/). The entire original design is preserved as [historical ZRAM design](history/03_zram_writeback.md#original-design--complete-source).

**Not tested:** actual installer `blkid -p` metadata, `dd` options, partition changes, first boot, writeback and emergency recovery. Use a disposable VM disk.
