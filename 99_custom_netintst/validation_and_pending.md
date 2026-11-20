# Validation — Test the scripts and generated Debian installer

## Standalone ZRAM diagnostic evidence — 2026-11-20

The user supplied a completed v7 [standalone writeback diagnostic](../06_zram_writeback/README.md#observed-disposable-vm-result--v7-2026-11-20) terminal report: normal/emergency/readback all PASS, 5,213.6 MiB verified and discarded (1,334,685 pages), backing writes and reads each 3,475.7 MiB, final resident memory 0 MiB, transient-unit cleanup successful and exit status 0. Normal/emergency/readback elapsed times were 104.1/81.0/746.7 seconds. This validates the pressure and integrity paths exercised by that particular running VM. The full kernel version, installer build identity, partition-conversion procedure, deliberate failure/restart behavior and complete original logs are not established by the screenshots.

The user subsequently supplied a completed v8 [standalone test report](../06_zram_writeback/README.md#observed-disposable-vm-result--v8-2026-11-20): normal/emergency/readback all PASS, 5,213.9 MiB verified and discarded (1,334,757 pages), backing writes and reads each 3,475.9 MiB, final resident memory 0 MiB, cleanup successful and exit status 0. Phase times were 107.8/81.7/725.1 seconds; total 914.9 seconds. The resident payload ratio and RAM savings matched v7 (3.82:1 and 73.76%). Compared with v7, readback elapsed time decreased approximately 2.9%, while summed measured stage CPU time increased about 50%. The two tests support the exercised writeback and integrity paths, not every installation or recovery scenario.

Version 9 simplifies the standalone test's readback concurrency optimization, retaining measured history instead of restarting periodically. Isolated tuning decision tests passed; actual v9 integration and VM performance remain pending. Neither v8 nor v9 changes the production service or ISO. The installer build and end-to-end installation checklist below are not marked complete by these standalone tests.

## Approved OMV self-cleaning one-time first boot — 2026-11-17

**Nearest user prompts:** “go ahead” approved the first-boot service; “i would prefer a one shot script that after execution is gone and doesn't leave anything behind. the only thing that can stay behind are the logs”, followed by “i agree with the suggestion”, approved the subsequent self-cleanup revision.

**Observed latest VM outcome:** On 17 November 2026, OMV package installation reached its official database initialization; running `in-target omv-confdbadm populate` exited 1 from OMV's `50timezone.sh` because `timedatectl` could not reach system D-Bus. The installer correctly stopped. Docker had not been reached.

**Current behavior:** Debian Installer retains the approved OMV repository, fully reviewed APT transaction, package audit and OMV 8 version check, then enables a native one-shot systemd service **without running either OMV command inside the chroot**. The first real boot runs the two official commands in their original order: `omv-confdbadm populate`, then `omv-salt deploy run hosts`. The runner writes a private `/var/log/installer/my-cdd-omv-firstboot.log` **before** the first command; the log is the only persistent project-specific first-boot artifact and the one-run record.

**Self-cleanup and notifications:** Both successful and normally failed runs disable the service, remove its enablement symlink, unit and executable script, and request `systemctl daemon-reload`. Command output, final result, failure step and exit status remain in the log. Progress and errors appear on the boot console and journal; **there is no permanent MOTD notice or separate state/attempt marker**. An interrupted run with an existing log performs cleanup-only at the next launch, never repeating OMV commands. Absolute cleanup cannot be guaranteed if abrupt power loss occurs before cleanup; durability of the early log write is flushed best-effort.

**Installer completion boundary:** Native stage-11 completion marker, stage-14 selected-profile verifier and stage-15 finish guard mean **OMV packages installed and one-time job successfully registered**. They do not assert successful OMV initialization after first boot. Docker and shared installer hooks remain unchanged.

**Static/isolated checks performed:** Exact Git blob `56d7ed069e2380785fc126dd2e4c42e9ff420edc` passed `sh -n`. Six isolated mocked runs passed: both commands succeed, `populate` fails (37), `hosts` fails (23), interrupted prior attempt, recovery cleanup after prior successful result, and failure of `systemctl disable` with direct symlink removal fallback. In all six mock cases the unit, symlink and runner were removed and only the log remained in target paths. These do **not** establish a successful actual ISO/VM first boot.

**Next disposable-VM acceptance checks:**

- [ ] Selected-only OMV installer stages service/runner and enables the service, without running `populate` in the installer
- [ ] First boot has a functioning system bus; both official commands succeed in the original order
- [ ] Verify systemd journal and boot console progress/error plus retained root-readable log
- [ ] In separate disposable VMs, simulate failing each command and verify logged command/exit status
- [ ] Confirm removal of unit, runner and enablement link on both success and failure, with no status/MOTD/attempt files remaining
- [ ] Confirm reboot does not repeat the OMV commands, and interruption recovery is cleanup-only
- [ ] Confirm Docker first-boot service state, OMV web UI/DNS and ZRAM writeback separately


## User-approved native per-profile completion restoration — 2026-11-17

**Nearest user authorization:** “i agree. use A”, after agreeing to consistent profile file naming and unchanged feature scope. This supersedes the single-status-only design recorded in the next dated section.

**Current source:** The stage-11 `run-selected.sh` runs each approved selected handler once and writes `/target/var/log/installer/my-cdd-completed/<profile>` only after successful return; overall `COMPLETE` follows only after every selected handler succeeds. Unmodified native Simple-CDD stage `14simple-cdd` executes the selected profile's executable `profiles/<profile>.postinst` **in-target**, checking its marker without repeating installation. The final `15my-cdd-status` checks selection approval, overall status and the marker of **every selected profile**, returning native finish-install exit 10 if incomplete. All seven installer handler filenames share the canonical profile stem; the ZRAM helper is `zram-writeback-selection.sh`.

**Outstanding validation:** Confirm executable bits and exact current source listings, successful and failed selected-profile combinations, per-profile marker checks in the native stage-14 hook, a deliberately missing marker at stage 15, installer failure diagnostics and no false final success message. An ISO build, full disposable-VM run, and first-boot checks have **not** been performed for this change.

## Previous native finish-install orchestration refactor (superseded) — 2026-11-17

**Nearest user prompt:** “implement”, in response to the source audit identifying duplicate custom lifecycle orchestration, marker-only Simple-CDD postinst checks, firmware-license template extraction, and manual local mirror edits.

**Implemented source architecture:** `installer/profile-confirm.sh` still uses upstream Simple-CDD's real `simple-cdd/profiles` choice and the user's explicit pre-udeb confirmation. It now registers `run-selected.sh` as native `/usr/lib/finish-install.d/11my-cdd`, together with the one `15my-cdd-status` gate. The default preseed no longer sets `preseed/late_command`. With `apt-setup/disable-cdrom-entries=true`, native Debian Installer executes `10apt-cdrom-setup` **once before** the stage-11 custom runner; no bespoke source editor or second call exists. Upstream `14simple-cdd` remains unmodified. The seven redundant marker-only optional `profiles/*.postinst` files were deleted, as were the runner's per-profile marker writes and the ZRAM marker preflight. The final stage 15 checks only that a confirmed selection exists and the runner's overall status is `COMPLETE`; on failure it returns native finish-install **10**.

**Preserved user requirements:** The same seven optional profiles and explicit selection summary/default-No approval; fixed approved order; separately reviewed full APT transactions including removals; vendor firmware licenses and individually approved omissions; exact selected ZRAM partition and destructive/swapoff confirmations; real diagnostic output; independent official OMV/Docker sources; previously approved root recovery and Debian tweaks conditional manual updates.

**Native reuse boundaries:** Source inspection shows Simple-CDD's normal stage 14 executes optional postinst scripts **in-target**, where the early D-I disk-conversion environment and custom pre-install GTK/text approval workflow are not equivalent. The stage-11 runner therefore remains, but uses Debian's native hook scheduler rather than duplicating its lifecycle. The two firmware vendor licenses must be approved or individually omitted **before** the reviewed transaction, while ordinary APT/Debconf passthrough asks questions during installation; replacing the approved pre-transaction omission workflow is **not proven**. Simple-CDD 0.6.9's `mirror_reprepro.py` hard-codes `UDebComponents: main`, so no verified Simple-CDD configuration-only substitute for the extra installer udeb-component mirror stage exists. The manual mirror adaptation was retained, not silently deleted.

**Source checks:** The 43 remaining complete source listings' Git blob SHA IDs match the current PR branch; the five changed executable/preseed listings match byte-for-byte. All seven deleted `.postinst` files are absent from the Git tree and developer source listings. These are source-level checks, not a successful ISO build.

**New disposable-VM tests required:**

- [ ] Early profile summary and default-No consent still appear once, before native Simple-CDD's selected-profile udeb work
- [ ] Native `10apt-cdrom-setup` runs before stage `11my-cdd`, disables the observed CD-ROM source, and is **not invoked a second time** by our code
- [ ] Stage 11 preserves the exact ordered profile set, full APT/GTK transactions, native firmware license and individually approved omission screens, and partition selections
- [ ] An actual selected-profile failure results in the stage-15 status hook returning exit **10**, preventing an incorrect native installation-complete screen
- [ ] A base-only install still establishes approved local root recovery and reaches COMPLETE with no optional profile side effects
- [ ] A full approved OMV/Docker install and ZRAM compressed-writeback first boot succeed on a disposable virtual disk

**No new ISO, successful installer run, firmware-passthrough test, or first boot is claimed.**

## Native apt-cdrom-setup early reuse — 2026-11-17

**Nearest user instruction:** “isn't the early editor the one from cdd? just call the cdd one early and don't reinvent the wheel”.

**Current source:** The bespoke source-list `sed` editor was removed. After profile selection is confirmed, `run-selected.sh` **always invokes the existing Debian Installer `/usr/lib/finish-install.d/10apt-cdrom-setup`** before local root recovery and optional profiles; a real invocation failure is reported through native installer diagnostics. This hook belongs to Debian `apt-setup 1:0.198`, not Simple-CDD. The unconditional preseed value `apt-setup/disable-cdrom-entries=true` remains. The native code comments active `deb cdrom:` in target `sources.list`, adds an explanatory comment and runs target `apt-get update` itself.

**Checks required next disposable VM:** Confirm the native hook is present/usable at the custom `07preseed` stage and removes the actual installed target CD-ROM APT entry **before** other profile transactions. Validate the second, ordinary `10apt-cdrom-setup` invocation; with preseed true, the upstream source can rerun APT refresh and append another explanatory comment. Confirm OMV/Docker install, selected ZRAM conversion and first boot after APT is usable. Current source inspection does **not** establish ISO/VM success.

## Unconditional pre-profile CD-ROM APT cleanup — 2026-11-17

**Nearest user clarification:** “I wanted the CD-ROM cleanup to be non-conditional an happen before the custom profiles and therefore the custom apt transactions”.

**Superseded intermediate implementation in PR #24:** A prior version used bespoke `sed` to disable installer `deb cdrom:` and `deb-src cdrom:` entries (including ordinary `[options]`) from the installed target's `/etc/apt/sources.list` and `/etc/apt/sources.list.d/*.list`. The cleanup is outside any `[ -n "$ordered" ]` gate; it runs even for zero optional profiles. It precedes the previously approved root recovery step, the custom profile loop and **every custom `apt-get` transaction**. Comments and network APT sources remain unchanged. The native unconditional `apt-setup/disable-cdrom-entries` preseed option remains enabled for Debian's later normal finish-install handling.

**Why both steps exist:** Debian Installer calls the custom `preseed/late_command` during `07preseed`, ahead of its later `10apt-cdrom-setup` finish-install cleanup. The native setting therefore cannot by itself protect the custom APT transactions. The early unconditional edit addresses the observed legacy CD-ROM source; it does not add a package-management restriction or new user-selection gate. No blanket rewrite of unrelated Deb822 network sources is introduced.

**Source-level check:** A read-only fixture tested ordinary `deb cdrom:`, `deb-src cdrom:`, bracket-options CD-ROM sources, active network sources and already-commented sources. Four active CD-ROM lines were disabled, two network lines and one inactive comment preserved. Full regenerated ISO and disposable-VM execution remain untested.

**Next VM checkpoint:** Verify the target's legacy CD-ROM APT entries are disabled **before the first selected profile calls APT**. If the installed Debian target uses a CD-ROM Deb822 `.sources` stanza instead of the observed legacy format, inspect its actual contents and adapt the minimal cleanup rather than assuming success.

## User-directed final simplification — 2026-11-17

**Nearest instruction:** Remove OMV/Docker custom origin gates, ZRAM's duplicate root check, all additional build-time refusal checks, the conditional CD-ROM edit (keep the unconditional native Debian preseed), and ZRAM's installer-only RAM/swapoff threshold refusals. Explain, but do not modify, the selected Debian tweaks manual-updates behavior.

**Implemented in PR #24:** OMV/Docker retain signed APT sources and complete user-approved transactions without additional `apt-cache policy` URL verification. ZRAM retains only the selected-partition confirmation, separate default-No targeted swapoff consent, actual `swapoff` execution and prohibition on overwriting active swap; no RAM reserve or memory-pressure refusal. The duplicate ZRAM root-account check is gone. In this **superseded intermediate revision**, the runner did not modify CD-ROM sources; the subsequent clarification above reinstates early cleanup unconditionally. `profiles/default.preseed` retains unconditional `d-i apt-setup/disable-cdrom-entries boolean true`. Custom build preflights and staged ISO/pkg-content gates are removed; native Simple-CDD/reprepro failures determine build success. Inert network method/keyboard variant build settings were deleted; both selections are still offered through Debian's normal installation screens. The earlier user-approved local root recovery setup is again performed on the base-only path.

**Retained, unchanged:** The Debian tweaks policy checks whether `unattended-upgrades` is installed and currently enabled; only then sets `APT::Periodic::Unattended-Upgrade "0";` exactly once. It is not a restriction on manual APT commands or an OMV/Docker configuration step.

**VM release gates:**

- [ ] Verify the **early unconditional runner CD-ROM source edit** completes before the custom profiles' initial APT update. The later native `10apt-cdrom-setup` cleanup alone does not meet this timing requirement.
- [ ] Validate correct operation and progress dialogs with OMV's signed repository and replacement of `systemd-timesyncd`, followed by Docker installation.
- [ ] Confirm an installer-activated but unused selected ZRAM swap partitions can be deactivated with only the approved targeted `swapoff`, without arbitrary memory-reserve thresholds.
- [ ] Confirm base-only root recovery behaves as originally approved, and optional Debian tweaks applies manual-update configuration at most once.
- [ ] First boot: Linux 7.x matching headers, compressed ZRAM writeback, OMV and Docker services, network/SSH access.

**Validation state:** Source changes only. No fresh ISO build or graphical/text VM test for this revision; the previous screenshot showed a custom OMV APT removal blacklist failure before the actual OMV package installation.

## Current review branch: user-owned installer policy — 2026-11-17

**Latest observed VM outcome (2026-11-16):** The selected profiles progressed through Debian tweaks and the confirmed ZRAM backing conversion. OMV's signed repository and archive key worked; its APT simulation proposed `Remv systemd-timesyncd`. The *project's own package-removal blacklist* stopped the installer before the user could approve the plan. The actual OMV transaction, Docker and first boot were **not** reached. PR #23's package-specific exception was closed unmerged.

**Current source changes (not ISO-tested):** Removed the shared and kernel/firmware package-name removal blacklists; APT command whitelist; unrequested installer service-start preflight; speculative CD-ROM source rejection/recheck while keeping the narrow source fix addressing an observed CD-ROM problem; Backports old-pin/priority refusals and both redundant empty-plan post-install tests; whole-system swap/`PARTLABEL` rejection unrelated to the chosen ZRAM backing. Removed the extra APT priority lookup after each signed update. The later authorized-scope correction restored the previously approved root-recovery setup for base-only installs.

**Required user-owned behavior retained:**

- [ ] The seven profile checkboxes remain genuinely optional, with an unchanged approval summary and no automatically selected optional profile.
- [ ] A base-only install still establishes the previously approved local root recovery password, without applying other optional-profile changes.
- [ ] Selected profiles display the complete simulated APT transaction, including removals, and require native default-No approval. A valid APT plan is not vetoed by a custom package blacklist.
- [ ] The Backports profile performs the user-approved full upgrade and individually approved cleanup; APT status/error results govern completion rather than repeated “empty plan” tests.
- [ ] The independent OMV/Docker profiles each use the single official signed repository with no additional policy changes.
- [ ] ZRAM still identifies the exact target GPT partition, confirms destructive conversion and targeted `swapoff` separately, and changes **only** that partition. An unrelated `fstab` swap entry remains untouched and cannot veto the selected conversion.
- [ ] Genuine operation failures and refused user consent remain visible through the native GTK/text diagnostics.
- [ ] After a successful installer, verify the Linux 7.x kernel, normal-user SSH access, ZRAM compressed-writeback setup/monitor, OMV/Docker services and first-boot networking.

**Release gate:** The current branch is source-reviewed only. A fresh disposable-VM ISO build and install are necessary; previous screenshots do not establish successful OMV installation or first boot.

## Confirmed OMV APT keyring permission failure — 2026-11-16

**Newest user-provided VM evidence:** The custom GTK failure dialog now displays the actual command, exit code 100, APT `Err:4` and `E:` diagnostics. The signed OpenMediaVault repository metadata is reachable, but `/usr/bin/sqv` reports `Failed to parse keyring "/usr/share/keyrings/openmediavault-archive-keyring.gpg": Permission denied (os error 13)`; APT consequently reports the repository as unsigned. The attempted repository signature check **did not succeed**, but the error is attributable to inability to read the public keyring rather than demonstrated bad signature content.

**Source-based explanation:** `run-selected.sh` sets `umask 077`; `profile-omv.sh` runs `gpg --dearmor -o /usr/share/keyrings/openmediavault-archive-keyring.gpg` but did not set readable permissions. The new source adds exactly one `run_target chmod 0644` immediately after dearmoring, so `_apt` can read this public signing key. No mirror changes, signature bypass, SSH/update-policy changes or other profile operations are introduced. The standalone OMV guide has the same command.

**New test gates:**

- [ ] Build a fresh ISO with the keyring-permission change; test in a disposable VM.
- [ ] Confirm OMV public keyring has mode `0644`, that `apt-get update` completes with the original official signed source, and that the package-origin check and reviewed OMV transaction can proceed.
- [ ] Confirm package signature verification remains enabled; do not add `trusted=yes`, insecure APT flags or redundant mirror configurations.
- [ ] Validate the full installer, OMV post-install database and hosts initialization, Docker and first-boot ZRAM behavior separately. **None is yet established by this VM run.**

## Latest VM installer evidence and diagnostic UI fix — 2026-11-16

**Observed in the most recent graphical VM screenshots:**

1. The Debian tweaks profile progressed past the former pre-boot OpenSSH failure. The selected Backports/kernel/firmware profiles progressed far enough for ZRAM to run.
2. The native default-No ZRAM dialog automatically identified `/dev/sda3` by its GPT PARTUUID and showed the exact disk and partition. The user approved conversion and the separately prompted targeted `swapoff` (0 used bytes).
3. The `systemd-zram-generator` APT simulation was reviewed. The installer progressed to the OMV profile, establishing that ZRAM's installer-stage handler returned successfully. **First-boot ZRAM writeback has not been verified.**
4. OMV installed its approved `gnupg`/`wget` prerequisites, retrieved and inspected the official signing key, and imported it to the target's dedicated keyring.
5. After the one official OMV signed APT source was configured, `apt-get update` **failed**. The dialog showed only “Target APT transaction failed: apt-get update” and unrelated trailing log output. The actual HTTP/DNS/signature/APT error is **not present in the screenshots**, so its cause is unknown. Docker was not reached and the installation remains **FAILED**.

**Source-level correction requested by the user:** “make the actual errors pop in the interface if you want to get them”. Debian Installer's `in-target` forwards stdout with `--pass-stdout` but logs stderr to syslog, while `debconf-apt-progress --logstderr` emits package output on stderr. The common `capture()` now redirects stderr to stdout **inside the target command**, preserving the original exit status and native package-progress UI. On any captured-command failure, the existing native GTK/text failure note shows the exact command, exit code, recognizable APT/dpkg error lines and recent actual command output **before** generic log information. Full output still goes to `/target/var/log/installer/my-cdd.log`. The OMV endpoint/source and package operations are **unchanged** until an actual APT diagnostic is available.

**Next disposable-VM checks:**

- [ ] Build the revised ISO from the current code and reproduce the OMV `apt-get update` case with the seven selected profiles on a disposable VM.
- [ ] Confirm the native failure dialog displays actual `Err:` / `E:` / HTTP / DNS / signature diagnostics from the failed command without requiring an installer shell.
- [ ] Confirm the failure dialog displays the command and nonzero exit status, the on-disk log contains both output streams, and installation remains FAIL/CANNOT COMPLETE after a selected-profile failure.
- [ ] Confirm normal native Debconf progress and approvals remain visible for successful package transactions.
- [ ] If the APT diagnostic confirms a problem in OMV's official repository, fix **only that grounded issue**; do not add unrequested mirror lists or SSH/update policy.
- [ ] Complete first-boot checks for ZRAM compressed writeback, SSH, networking, OMV and Docker after an entirely successful installer run.

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
3. Confirm `installer/profile-confirm.sh`, `installer/run-selected.sh`, `installer/15my-cdd-status` and all seven `profiles/*.postinst` verifiers have executable permissions. The imported feature modules should remain **sourced** files.
4. Confirm every path in each `profiles/*.extra` exists before running the build. A module is not executed merely because it was staged.
5. Do not run sourced installer modules on a host machine. Their behavior must be exercised in the **Debian Installer VM**.

This checks reproducibility of **source bytes**. It does not validate installer logic, which is what the following steps cover.

This is a **developer's testing procedure** for the source you built in [Build project](build_project.md), [Installer framework](installer_framework.md), [Shared profile helpers](profile_construction.md) and the individual profile-construction chapters.

A shell syntax check and a successful ISO build are **not** equivalent to testing the installer runtime.

## Step 1 — Check the source before building

From `99_custom_netintst/my-cdd`, parse your changed module without executing it:

~~~sh
sh -n installer/zram-writeback.sh
~~~

This is an example. Change the filename to the module you actually edited. `sh -n` checks POSIX shell syntax **without running disk writes or APT**.

Check that each selected feature has its own `profiles/<name>.description` and `.extra`, and that its handler is staged by Simple-CDD. All seven optional `.postinst` files verify per-profile completion markers; the runner's overall `COMPLETE` status is checked at stage 15.

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

## Route A additional completion verification tests

- [ ] Select two or more profiles; confirm an individual success record is created only after each handler returns success
- [ ] Confirm native Simple-CDD stage 14 executes exactly the approved executable `profiles/<name>.postinst` verifiers in-target, without executing the selected installation handlers again
- [ ] With a selected profile marker absent, confirm stage 15 returns **10** even if the global status file contains `COMPLETE`
- [ ] On a failed profile handler, confirm no marker is written for that profile and native Debian Installer does not display a false success screen
- [ ] Confirm all seven selected handler files and the ZRAM helper are staged from their matching native `.extra` manifests
