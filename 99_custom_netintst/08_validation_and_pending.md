# Netinst — Step-by-step VM and release validation

This is the **active test plan** for the custom Debian 13 image, not a declaration that the tests have passed. Earlier observed failures and full chronological notes remain in [history](history/08_validation_and_pending.md).

## Step 1 — Build and inspect the ISO

- [ ] On a compatible Debian build VM, follow [01 — Build preparation](01_custom_cdd_preparation.md) and run `./build.sh` from `99_custom_netintst/my-cdd`.
- [ ] Confirm the build created `images/debian-13-amd64-CD-1.iso` and did not report missing staged assets or syntax errors.
- [ ] Confirm the build's package-index checks found `zstd`, `parted-udeb` and `util-linux-udeb`; **this alone does not verify their runtime dependency closure**.
- [ ] Check the generated GRUB and ISOLINUX boot-menu settings, including the intended indefinite wait.

## Step 2 — Check Debian Installer's human-facing screens

- [ ] Boot the ISO in a VM with a **throwaway GPT disk**, first using graphical Debian Installer and then the text interface.
- [ ] Confirm normal language, Spanish-keyboard suggestion, country/timezone, DHCP, hostname, administrator and root-password prompts remain **editable**.
- [ ] Verify the **seven optional profiles all start unchecked**, with a full selected/not-selected summary and default-No confirmation. Test **No**, corrected selection, and zero selected profiles.
- [ ] Select ZRAM without Ensure Linux 7.x and verify the installer rejects the invalid combination without adding the kernel checkbox.
- [ ] Confirm manual disk partitioning remains manual. At tasksel select **SSH server** and **standard system utilities**, with no desktop/GNOME.

## Step 3 — Check common late-install safeguards

- [ ] Verify the installer validates the exact approved profile selection before any selected operations.
- [ ] When root is locked, verify the **native root recovery password** prompt and its confirmation, without passwords in logs.
- [ ] Check service-start suppression in the target and that only installer `cdrom:` APT entries are disabled before network APT work.
- [ ] Review a complete APT simulation in the installer GUI and test the **default-No** cancellation path.
- [ ] On an intentional failure, verify the status guard **does not** show a misleading success screen.

## Step 4 — Check each selectable profile

- [ ] **Backports:** the signed source appears under the installed target, priority is **100**, package upgrades and proposed removals are separately reviewed, and essential packages remain.
- [ ] **Kernel:** a viable Linux **7.x image and exact ABI-matching headers** are installed, and a Stable boot fallback survives. Test with and without Backports selected.
- [ ] **Firmware:** both CPU microcode packages and the broad inventory are attempted. Test unavailable packages, fallback explanations, per-package omission prompts and **both full vendor firmware licenses**.
- [ ] **ZRAM:** confirm exact PARTUUID discovery and manual-choice fallback, default-No destruction, separate targeted swapoff, RAM reserve, mounted/held/duplicate-device rejection, the approved 1 MiB erase, GPT type `8300` and label, absence of conventional swap signatures, and target `fstab`/generator identity.
- [ ] **Debian tweaks:** verify only the approved GRUB/ext4/SSH/manual-APT changes were applied when selected; no changes when unselected.
- [ ] **OMV 8:** verify the signed OMV source, version, admin SSH/sudo membership, OMV unattended-upgrade and APT-event settings, targeted Salt deploy and no active apticron schedule.
- [ ] **Docker:** verify the official signed source and all five requested packages, with normal service startup and no OMV-Extras or Docker/OMV integration.

## Step 5 — Verify the installed server after boot

- [ ] Confirm the running Linux kernel is **7.x** with matching headers and a working rescue boot path.
- [ ] Verify `/dev/zram0` (not the former physical swap partition) is active, ZSTD compression and compressed-writeback interfaces exist, the correct PARTUUID resolves, and writeback counters move during **controlled** pressure.
- [ ] Test ZRAM setup-failure **emergency mode** and independent monitor-restart behavior, on a disposable VM only.
- [ ] Verify OMV web/SSH network access and Docker/containerd service behavior if selected.
- [ ] Confirm `/var/log/installer/my-cdd-status` says `COMPLETE` and each approved profile has a completion marker; inspect the detailed operation log for unexpected errors.

**Release status as of 2026-11-16:** these runtime checks remain **open**. Do **not** interpret a successful ISO build, a shell syntax check or this documentation refactor as validation for a real-disk installation.
