# Netinst — Integration and release checks

This is the **active** checklist for the custom Simple-CDD ISO. The earlier comprehensive decision and failure log is preserved in [history/08_validation_and_pending.md](history/08_validation_and_pending.md).

## Build and boot

- [ ] Run `./build.sh` from `99_custom_netintst/my-cdd`; verify the two-stage mirror/index flow, `zstd`, `parted-udeb` and `util-linux-udeb` on the resulting ISO.
- [ ] Boot **graphical and text** installation, both UEFI and BIOS menus as applicable. Confirm editable locale, Spanish keyboard, timezone, identity and network prompts.
- [ ] Confirm all **seven optional profiles are initially unchecked**; verify zero-selection and independent combinations; display a complete early GTK/text summary with default-No confirmation.
- [ ] Validate tasksel selections (no desktop; SSH and standard utilities), manual disk partitioning, native package-retry, root emergency credentials and completion status guard.

## Selected profile execution

- [ ] Backports source, priority **100**, reviewed upgrade and removal approvals; signed source and CD-ROM APT cleanup.
- [ ] Latest eligible 7.x kernel and exact headers; preserve bootable Stable fallback.
- [ ] Broad firmware and both microcode packages; display both full vendor license prompts and independently approved omissions.
- [ ] ZRAM: exact swap partition from target fstab or manual Debconf selection, no mounted/held/duplicate device, safe targeted swapoff, approved 1 MiB BusyBox erase, GPT `8300` type/name, no residual swap signature, correct fstab and dynamic PARTUUID.
- [ ] Debian tweaks only if selected, independent of 7.x/ZRAM.
- [ ] OMV 8 and Docker separately and together; OMV update scheduling off, SSH administration preserved, vendor service defaults, no OMV-Extras/Compose.

## First boot and release

- [ ] Boot with selected Linux 7.x; validate actual ZRAM `compressed_writeback`, backing capacity, generator ordering, monitor restart and emergency failure path.
- [ ] Confirm all selected-profile completion markers and full log export; failed operation must **not** appear as installation success.
- [ ] Use **disposable VM disks only** until the destructive ZRAM path and first boot are confirmed. A successful ISO build alone is not a release test.

**Status (2026-11-16):** Source refactor and documentation structure are present, but these runtime gates are not closed.
