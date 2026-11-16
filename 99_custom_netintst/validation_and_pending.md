# Validation — Test the scripts and generated Debian installer

## Latest real installer VM evidence — 2026-11-16

**Observed in the newer test screenshots and installer syslog:**

1. The approved selections included Debian tweaks, Backports, the 7.x kernel, extended device support, ZRAM, OMV and Docker. The selected Debian tweaks profile executed **first**.
2. Debian's own sudo administrator and the separately requested local root password were established. Target `update-grub` completed.
3. The installer stopped when the former Debian tweaks code ran `sshd -t`. The installer syslog explicitly states **`Missing privilege separation directory: /run/sshd`**. This is a pre-boot runtime prerequisite, not evidence that `PermitRootLogin no` is invalid.
4. ZRAM partition conversion and subsequent selected profiles were **not reached in this latest test**. The overall installation failed.

**Earlier VM evidence (same date):** Under the former profile order, ZRAM's default-No GPT conversion confirmation, approved bounded 1 MiB erase, partition type/name change and reviewed generator installation were observed. That older test subsequently failed in Debian tweaks at `sshd -T`; it does **not** prove successful first boot or compressed writeback.

**Current source correction, not runtime-tested:** Debian tweaks now edits the existing `sshd_config` directly and runs no pre-boot SSH daemon tests. It sets generic root `noatime` and filesystem-specific panic behavior (ext2/3/4: `errors=panic`; Btrfs: `fatal_errors=panic`), preserves the original `fstab` and leaves unsupported XFS error handling untouched. Automatic-update configuration happens only in this selected profile and is not rechecked by subsequent profiles.

**Next disposable-VM retest:**

- [ ] Leave initial Debian root-password fields blank, verify the normal sudo account and set the distinct local root recovery password.
- [ ] Select Debian tweaks and ZRAM with its separately approved Linux 7.x dependency; confirm tweaks executes first and does not call `sshd -t` or `sshd -T`.
- [ ] Check the installed root `fstab` behavior for ext4 and Btrfs; on XFS, check `noatime` without an unsupported panic option, preserving other mount entries and the backup.
- [ ] Verify `PermitRootLogin no` in the installed main `sshd_config` and a successful normal-user SSH connection after first boot.
- [ ] Verify manual APT upgrade policy with `unattended-upgrades` absent, disabled and enabled, and no subsequent OMV/Docker changes to that policy.
- [ ] Only after tweaks succeeds, separately approve the ZRAM conversion on a **throwaway partition**; verify native candidate selection, generator, backing PARTUUID and actual first-boot writeback.
- [ ] Preserve logs and treat any selected-profile or first-boot failure as a failed VM test.

## Step 0 — Test that the written guides can actually reproduce the source

Before making an ISO, reproduce the **file contents from the chapters**, on a scratch checkout. Use the complete file listings, not shortened code samples.

1. Follow [Build project](build_project.md), [Shared profile helpers](profile_construction.md), [Installer framework](installer_framework.md) and each selected feature page. Keep the entire current seven-profile set when reconstructing the shipped configuration.
2. For each created file, run `git hash-object <path>` from `my-cdd`. It **reads the file only** and prints a Git blob identifier. Compare that output with the expected blob SHA printed above the file's full listing. A mismatch means the copy differs.
3. Confirm `build.sh`, `installer/profile-confirm.sh`, `installer/run-selected.sh`, `installer/15my-cdd-status` and every `profiles/*.postinst` have executable permissions. The imported feature modules should remain **sourced** files.
4. Confirm every path in each `profiles/*.extra` exists before running the build. A module is not executed merely because it was staged.
5. Do not run sourced installer modules on a host machine. Their behavior must be exercised in the **Debian Installer VM**.

This checks reproducibility of **source bytes**. It does not validate installer logic, which is what the following steps cover.

This is a **developer's testing procedure** for the source you built in [Build project](build_project.md), [Installer framework](installer_framework.md), [Shared profile helpers](profile_construction.md) and the individual profile-construction chapters.

A shell syntax check and a successful ISO build are **not** equivalent to testing the installer runtime.

## Step 1 — Check the source before building

From `99_custom_netintst/my-cdd`, parse your changed module without executing it:

~~~sh
sh -n installer/profile-zram.sh
~~~

This is an example. Change the filename to the module you actually edited. `sh -n` checks POSIX shell syntax **without running disk writes or APT**.

Check that the relevant `profiles/<name>.description`, `.extra` and `.postinst` exist. The source file must be listed in the appropriate media manifest; the postinst should verify a completion marker, not repeat installation.

Confirm that `simple-cdd.conf` still has the seven offered profiles and **empty** `auto_profiles` and `default_profiles`. Verify that new code is inside a **selected function**, not executed when sourced unconditionally.

## Step 2 — Run the guarded ISO build

Execute:

~~~sh
./build.sh
~~~

This generates editable defaults, prepares the local mirror, builds the ISO and checks the staging tree. Inspect terminal logs on any failure.

Verify that the resulting ISO path exists (`images/debian-13-amd64-CD-1.iso`) and that the staged ISO includes the files in **every** `profiles/*.extra`. Verify both udeb and normal binary indexes contain expected build-only requirements (`parted-udeb`, `util-linux-udeb` and `zstd`).

Also inspect whether the generated boot menu really waits as intended. **Do not assume an indexed udeb has been successfully loaded into a running installer.**

## Step 3 — Check GUI selection and preseed wiring

Boot the ISO with a throwaway disk. Test both graphical and text Debian Installer.

- [ ] All seven profiles appear and start **unchecked**.
- [ ] The summary displays selected and unselected options, and its confirmation defaults to **No**.
- [ ] No returns to selection; Yes preserves the exact approved list.
- [ ] ZRAM without a separately chosen 7.x profile is rejected.
- [ ] Ordinary language, network, user, mirror, storage and tasksel questions still appear and remain editable.
- [ ] Tasksel is manually verified as SSH + standard utilities with no desktop.
- [ ] Root recovery preflight uses native installer questions and does not log a password.

## Step 4 — Test module isolation and package approvals

For every optional module, test **not selected** first: there must be **no package, repository or disk change** for that feature.

Then test:

- [ ] A selected profile with an APT transaction shows the **whole simulation** before a default-No approval.
- [ ] Refusing a package plan or a named removal/omission prevents unapproved work.
- [ ] Backports has effective priority **100**, with its signed source and reviewed cleanup.
- [ ] Kernel chooses an eligible **7.x** image/header pair, keeps a boot fallback and does not auto-enable Backports.
- [ ] Firmware attempts both microcodes, handles conflicts, shows the **full actual vendor licenses**, and reruns the plan after a declined license.
- [ ] Debian tweaks affect only selected target GRUB/root-fstab/SSH/APT settings; no pre-boot SSH daemon checks or later APT-policy rechecks.
- [ ] OMV uses only the first official manual-install signed APT repository (`packages.openmediavault.org/public`), checks its package origin, applies the same full-transaction/default-No review pattern as Docker, installs **8.x**, and runs `omv-confdbadm populate` and `omv-salt deploy run hosts`; it makes no custom SSH, group, update, notification, plugin or Docker changes.
- [ ] Verify OMV's documented `systemd-resolved`/DNS prerequisite before and throughout installation, and verify first-boot network reachability without making unapproved CDD network changes.
- [ ] Docker installs the five official signed packages without changing vendor service defaults or granting the administrator the Docker group.

## Step 5 — Test the destructive ZRAM module separately

Use only a **disposable GPT virtual disk**. Test all of the following before using real disks:

- [ ] Eligible candidate discovery through **native `blkid` and sysfs**; reject non-GPT, wrong identity and duplicate PARTUUID.
- [ ] Automatic selection **only** for the single exact new-target swap reference; manual chooser defaults to Stop.
- [ ] Exact partition, size, parent disk, PARTUUID and destructive scope are visible before default-No consent.
- [ ] A cancelled conversion makes **no destructive write**.
- [ ] Swapoff requires adequate RAM, a **separate** default-No consent, exact-device revalidation and verification that the device is inactive.
- [ ] The first **1 MiB** of the **partition**, not its disk, is zeroed using BusyBox; no unrelated partition data changes.
- [ ] GPT type becomes Linux data (8300), name becomes `zram-writeback`; PARTUUID is unchanged and no recognized swap/filesystem signature remains.
- [ ] Target `fstab` loses **only** the selected conventional swap, while unrelated mounts remain.
- [ ] Generated target ZRAM configuration contains the exact verified PARTUUID in both positions.

## Step 6 — Test finish-install and first boot

- [ ] Every successful selected profile creates its marker; status becomes `COMPLETE` **only after all selected profiles** succeed.
- [ ] A deliberately failed profile leaves status `FAILED`, and the finish-install guard prevents a misleading installation-success message.
- [ ] Log files under `/target/var/log/installer` are complete and contain no password secrets.
- [ ] The installed system boots; `uname -r` is **7.x** when selected, with matching headers and a working Stable fallback.
- [ ] ZRAM uses `/dev/zram0` instead of the physical partition as normal swap; compression, writeback counters and monitor services are tested under controlled conditions.
- [ ] The consolidated `override.conf` enables compressed writeback before initialization; a deliberately broken ZRAM setup triggers the intended **emergency mode** and a monitor-only failure restarts without forcing emergency mode.
- [ ] OMV web/network reachability and Docker/containerd startup (if selected) reflect normal package behavior; SSH policy is separately validated under Debian tweaks.

## Current release status

**Open as of 2026-11-16:** the current native-udeb ZRAM conversion, complete GUI/target APT flow and first-boot writeback have **not** been validated end to end. Do not use the new ISO on important physical disks until these tests pass.

Historical design and earlier failure logs remain in [the original archived validation notes](history/08_validation_and_pending.md).
