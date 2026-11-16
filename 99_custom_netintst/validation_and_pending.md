# Validation — Test the scripts and generated Debian installer

## Most recent real installer VM run — user screenshots, 2026-11-16

**What the screenshots show (observed, not inferred):**

1. A native GTK dialog displayed the exact automatically selected GPT backing partition, size, parent disk and PARTUUID; destructive conversion defaulted to **No**.
2. The user approved converting the selected VM swap partition. The installer log shows targeted BusyBox `swapoff`, a bounded `dd` write of **1 MiB to the partition**, `parted` type/name updates and a completed ZRAM profile.
3. The full `systemd-zram-generator` APT simulation was displayed, followed by the approved package installation.
4. The next selected stage, **Debian tweaks**, ran `update-grub` and attempted `sshd -T`. It then stopped with **“OpenSSH configuration invalid”** and a FAILED status. The actual `sshd` stderr is **not visible in these screenshots**.
5. There is **no verified first boot**, ZRAM writeback activity, emergency-mode recovery or completed custom installation in this evidence.

**Working diagnosis, not a confirmed cause:** a not-yet-booted Debian target may not contain `/run/sshd`, a directory normally prepared by `ssh.service`. The revised installer shared SSH helper creates only that transient target directory, runs `sshd -t` and `sshd -T`, and records failures in `/target/var/log/installer/my-cdd.log`. This must be re-tested; host keys or real SSH configuration errors remain possible.

**Safety improvement:** the approved new dispatcher order runs **Debian tweaks first**, so a recurrence of the same failure should stop **before** the ZRAM partition erase, rather than after it.

**Next disposable-VM retest:**

- [ ] Use blank initial root-password fields, a regular first user, verify that user has `sudo`, and set the separate root recovery password via the native late-stage prompt.
- [ ] Select Debian tweaks and ZRAM with its separately approved 7.x prerequisite; confirm the profile screen and dispatcher start with **Debian tweaks**.
- [ ] Verify the SSH check reports full stderr in `my-cdd.log` if it fails and does not mislabel a missing runtime directory as invalid configuration.
- [ ] Verify SSH host keys, `/run/sshd`, effective `PermitRootLogin no`, and a real normal-user SSH login on first boot.
- [ ] Verify automatic-upgrade handling both when `unattended-upgrades` is absent and when installed/enabled.
- [ ] Only after tweaks succeeds, approve the separate ZRAM conversion on a **throwaway partition**, then verify generator, zram0, backing device and first-boot writeback behavior.
- [ ] Preserve actual logs and mark the test failed on any selected-profile or first-boot failure.

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
- [ ] Debian tweaks affect only selected target GRUB/root ext4/SSH/APT settings.
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
