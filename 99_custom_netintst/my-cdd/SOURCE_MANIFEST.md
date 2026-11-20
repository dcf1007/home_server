# my-cdd source manifest and provenance

## Native progress reporting — 2026-11-20

**Nearest user prompt:** “i would choose option A” (native Debian Installer progress feedback rather than embedded terminal or live output changes).

- Use native cdebconf templates and status messages for selected profiles, administrator/recovery checks, APT index refresh/simulation/approved execution, kernel candidates, firmware candidates and license preparation, OMV/Docker signing-key downloads, writeback partition inspection/preparation, GRUB/initramfs refresh, package/service verification and completion. Firmware counts actual candidate tokens; local profile progress counts verified completion markers, not elapsed time.
- Trixie `finish-install` 2.124 already starts its own bar (https://sources.debian.org/src/finish-install/2.124/debian/postinst). Trixie cdebconf 0.280 GTK destroys previous bars on START, and its command dispatcher ignores DC_NOTOK for progress INFO (https://sources.debian.org/src/cdebconf/0.280/src/modules/frontend/gtk/progress.c and https://sources.debian.org/src/cdebconf/0.280/src/commands.c). Do not start a competing nested bar. Initially use existing native progress INFO; after APT or anna handoff, open a custom native bar between native operations with actual completed profile count; stop it before another native transaction or exiting the hook. This cannot restore the already-replaced finish-install bar and frontend rendering is not yet tested. Native APT mechanism unchanged. No change to command capture/log streaming, package choices, acceptance/dialogs, credentials, partition policy, repositories, OMV first boot, or the independent Netplan experiment.
- Validation: source inspection and static consistency checks only; rebuild/test GTK and text frontend, base-only recovery, firmware candidate progression, transitions to/from APT including failure/cancel, and final native completion. Do not infer continuous animation or per-command percentage for blocking operations.


## Initial root dialog and firmware license policy — 2026-11-20

**Nearest user prompt:** “in the sequence, is it possible to exchange 5 and 6 in an easy way? if not leave them ass they are.these 2 changes should be an independent pr”

- Native account setup: generated `defaults.preseed` now contains `d-i passwd/root-login boolean false`. This skips initial root-password questions and preserves ordinary interactive user setup plus native sudo membership. The existing stage-11 sudo verification and separate root-recovery password prompt remain unchanged in timing and behavior; moving that prompt into early account setup would need additional lifecycle/credential handling. No credentials are preseeded, and no SSH policy changes.
- Firmware: `AUTO_ACCEPT_FIRMWARE_LICENSES="true"` in `profile_defaults.conf` preauthorizes only the two named vendor agreements (`firmware-ipw2x00` and `firmware-ivtv`) for the explicitly selected Extended device support profile. `build.sh` validates true/false and produces a data-only `tmp/generated/firmware-license-policy` staged by that profile's .extra. Exact candidate archive/template checks remain; acceptance is recorded in target Debconf and verified before installation. Log distinguishes preauthorization from interactive acceptance and records the selected version. Set false and rebuild to recover the original complete license, refusal, and omission workflow. Review vendor terms before enabling or distributing the ISO; later package versions may have changed terms.
- Existing complete APT simulations and explicit transaction, omission and destructive approvals remain. No Netplan diagnostic changes from PR #33; no OMV/Docker changes.
- Source changes require a fresh ISO build and disposable-VM verification in both automatic and interactive firmware modes (including refusal), with the initial root dialog absent, regular user sudo membership intact, late recovery password and normal completion. No ISO/runtime verification claimed.


## OMV one-time job cleans up after itself — 2026-11-17

**Nearest user prompt:** “i agree with the suggestion”, after requesting that the one-shot script, service and all state markers disappear after execution, leaving only logs.

**Revision of PR #25:** `installer/openmediavault.sh` still stages and enables a temporary job after approved OMV 8 package installation. The updated `installer/openmediavault-firstboot.sh` creates `/var/log/installer/my-cdd-omv-firstboot.log` before any initialization, runs only `omv-confdbadm populate` and `omv-salt deploy run hosts` on the real first boot, then disables/deletes its service, enablement symlink and itself on both success and failure. `installer/openmediavault-firstboot.service` has no persistent-state condition or MOTD. A prior log forces cleanup-only after interruption, with no automatic command retry. The OMV `.extra` manifest, Docker handler, selected-profile dispatcher and native completion guard do not change.

**Observability boundary:** Log and boot console/systemd journal are retained reporting channels; no persistent login notice/status file is installed. If a sudden power loss interrupts cleanup the next boot can recover it, provided the attempt log reached storage. Six isolated mock cases passed; full ISO and first-boot validation remain outstanding. Full current source listings and Git hashes are in the OMV construction guide.

## Latest user-approved Route A and canonical naming — 2026-11-17

**Nearest user prompt:** “i agree. use A”, after expressly approving identical profile filename stems and unchanged feature-installation scope.

**Current revision:** The native Simple-CDD stage `14simple-cdd` executes seven possible selected-profile `profiles/*.postinst` verification-only scripts inside the target. The stage-11 runner writes per-profile success records only after each approved handler returns successfully, and the final stage-15 guard verifies **every selected marker** plus the overall `COMPLETE` status, returning native exit 10 when incomplete. The seven selected installer handler files now use exactly their matching profile IDs, with `zram-writeback-selection.sh` for the ZRAM-specific helper. No package, partitioning or service policy has been changed by this restoration. The complete developer source listings and SHA values were updated. No build, disposable-VM installer execution or first boot is claimed for this change.

**Historical provenance boundary:** Earlier dated entries below that describe removal of the seven verifiers and marker files document an intermediate, superseded PR #24 revision, not the current source.


## Current source manifest: native lifecycle and reduced duplication — 2026-11-17

**Nearest user prompt:** “implement”, following the audit of the native installer lifecycle, duplicate Simple-CDD postinst verifiers, firmware Debconf license handling and the custom build mirror mechanism.

**Current Git source architecture:** The early selector `installer/profile-confirm.sh` preserves the native `simple-cdd/profiles` multiselect, explicit ordered summary and default-No consent before the original profile udeb is installed. It stages `installer/run-selected.sh` into `/usr/lib/finish-install.d/11my-cdd` and the single status guard into `/usr/lib/finish-install.d/15my-cdd-status`. `profiles/default.preseed` no longer defines `preseed/late_command`, retaining `apt-setup/disable-cdrom-entries=true`. Native order: `10apt-cdrom-setup` → `11my-cdd` → original `14simple-cdd` → `15my-cdd-status`. No direct CD-ROM hook double invocation or custom source editor remains.

**Removed files:** `profiles/debian-tweaks.postinst`, `profiles/backports.postinst`, `profiles/ensure-7x-kernel.postinst`, `profiles/extended-device-support.postinst`, `profiles/zram-writeback.postinst`, `profiles/openmediavault.postinst` and `profiles/docker.postinst`. Removed all `my-cdd-completed` marker generation and status checks; ZRAM relies on explicit independent kernel-profile selection plus dispatcher ordering, not a marker. The final status hook checks only the confirmed profile-selection record and overall `COMPLETE` state, returning Debian's native exit 10 on incomplete execution.

**Existing custom logic deliberately retained:** Full APT simulation, native default-No user transaction review, selected partition and separate destructive/swapoff consent, individual firmware/microcode omission and pre-install vendor-license confirmation, signed official OMV/Docker repositories and normal first-boot service defaults. The user did not authorize dropping these features. Native `apt-install`/`debconf-apt-progress` cannot be treated as an equivalent proven substitute for a *pre-install license decline/omit* procedure. The Debian Simple-CDD 0.6.9 mirror code hard-codes `UDebComponents: main`, so its documented mirror configuration is not yet a demonstrated substitute for the project's existing two-stage `reprepro` component adjustment. Both have been marked for runtime tests rather than speculatively replaced.

**Exact documentation/validation contract:** The 99 construction guides now contain 43 full remaining source listings with matching current Git blob IDs; seven obsolete postinst listings are removed, and the five changed embedded executable/configuration listings were checked byte-for-byte. Historical entries below include pre-refactor source snapshots and are not current instructions. This PR is source-only, unmerged and not a claim of successful ISO/VM or first boot.

## Native Debian Installer CD-ROM source cleanup reuse — 2026-11-17

**Nearest user instruction:** “isn't the early editor the one from cdd? just call the cdd one early and don't reinvent the wheel”.

**Confirmed implementation:** Debian 13 Trixie's `apt-setup 1:0.198` provides `/usr/lib/finish-install.d/10apt-cdrom-setup`. This is a native Debian Installer hook, not part of Simple-CDD. In `installer/run-selected.sh`, after the full chosen-profile approval is verified but before any root recovery or custom profiles, call the unmodified Debian Installer hook via `capture`; treat an actual nonzero result as a command failure. Retain `apt-setup/disable-cdrom-entries=true` in `profiles/default.preseed`, ensuring its cleanup path is taken regardless of optional profile selection. No custom `sed` CD-ROM editor remains. The hook updates the target APT lists itself.

**Upstream limitation:** The native finish-install scheduler will also execute `10apt-cdrom-setup` at its later normal stage. It can repeat `apt-get update` and append explanatory comments twice when forced true. The hook edits only `^deb cdrom:` in target `/etc/apt/sources.list`; it does not cover unrelated Deb822 or `.list` syntax. This matches the legacy form in the observed installer failure, but the next VM must establish actual behavior. Upstream reference: https://sources.debian.org/src/apt-setup/1:0.198/finish-install.d/10apt-cdrom-setup .

**Verification:** Synchronize native runner and preseed complete CDD listings and Git blob hashes; confirm no local sed editor, no selection-condition gate, and correct call order. No ISO rebuild or VM install tested.

## Unconditional CD-ROM APT cleanup before custom transactions — 2026-11-17

**Nearest user clarification:** “I wanted the CD-ROM cleanup to be non-conditional an happen before the custom profiles and therefore the custom apt transactions”.

**Superseded intermediate implementation:** An earlier PR revision iterated over legacy target source files with bespoke `sed`. The current code invokes Debian's own hook as described above. Comment only active legacy installer `deb[-src] [options] cdrom:` lines. No `[ -n "$ordered" ]` condition controls this operation; it also runs for base-only installs. Non-CD-ROM lines and already-disabled entries remain unchanged. Fail only if the actual source-file edit fails. The native `d-i apt-setup/disable-cdrom-entries boolean true` remains in `profiles/default.preseed` for the later finish-install stage.

**Why timing matters:** Debian Installer runs the custom late command in `07preseed`, before its normal `10apt-cdrom-setup` cleanup, and earlier VM tests failed when an active `cdrom:` source remained during custom APT. Removing the early editor was a misinterpretation of the previous user instruction. This correction restores the early cleanup **without selection gating**; no custom APT dependency/removal policy is introduced.

**Validation:** Legacy source-line syntax and idempotent comment/no-edit behavior checked in an isolated sed fixture. No fresh built ISO or actual Debian Installer run. The current edit is scoped to the observed legacy `.list` syntax, not unrelated Deb822 `.sources` stanzas.

## User-directed final policy cleanup and exact source manifest — 2026-11-17

**Nearest user instruction:** “remove 1,2,3 and 5. for 4, remove the conditional one and leave the unconditional cdrom entries . remove also the zram swapoff refusals, it is an installation environment ffs, of course the swap is going to be empty. talk me through what you call 'conditional manual-update policy.'”

**Executable changes:** Removed OMV's `apt-cache policy` origin and URL refusal and Docker's five equivalent package-origin checks; retain signed repository metadata and normal APT transaction approval. Removed the duplicate post-ZRAM root-account status check. In this **superseded intermediate PR revision**, `run-selected.sh` did not edit legacy installer CD-ROM entries. The current source restores the edit unconditionally before profiles, and retains the native unconditional `apt-setup/disable-cdrom-entries` preseed option. Selected swapoff no longer performs artificial RAM reserve/PSI tests; it still identifies and gets separate consent for the exact partition, calls `swapoff` when active and refuses to erase an actually active partition. Restore the already-approved root recovery check also for the base-only path (undo an earlier unauthorized PR #24 scope change).

**Build changes:** `build.sh` now delegates ordinary build failures to Simple-CDD/reprepro, without project-specific shell/profile, default-value, mirror-state or staged ISO/package-pool refusal gates. It still generates editable preseed defaults, runs two-stage mirror/build and handles generated local udeb components. Removed the two unused `profile_defaults.conf` fields that had only served as unsupported validation targets (`DEFAULT_NETWORK_METHOD` and `DEFAULT_KEYBOARD_VARIANT`); their actual choices remain in Debian Installer's interactive screens.

**Unchanged:** The Debian tweaks conditional manual-only APT upgrade setting is applied once in the selected tweaks profile **only if** `unattended-upgrades` is installed and periodic upgrade execution is enabled; it does not alter OMV/Docker policies or block manually initiated APT operations. All signed sources, user transaction confirmation, individually approved firmware/license decisions, ZRAM raw-partition scope, and diagnostics remain.

**Verification boundary:** Update every complete CDD listing and Git blob SHA when the above executable assets change. This branch has not been ISO-built or tested in a fresh disposable VM. The user clarified that the runner must perform unconditional early legacy CD-ROM cleanup, which is now source-implemented; actual VM behavior remains unverified.

## User-directed removal of discretionary installer guards — 2026-11-17

**Nearest user instruction:** “it's none of your business what you consider risky or unexpectedd. If i have not asked something and approved it, you should not do it. remove them all. the user can see what the installer is going to do and decide on its own. keep only the things i asked and authorised”.

**Observed trigger:** The latest Debian Installer GTK failure showed a valid-looking OMV installation plan including `Remv systemd-timesyncd`, which a custom project blacklist rejected before the user's default-No package-transaction approval. A separate exception-only approach was opened as PR #23 and **closed unmerged**.

**Removed executable rules:** (1) hard-coded essential-package removal filtering in the shared runner, firmware and kernel; (2) APT operation whitelist in `run_target`/`simulate_target`; (3) redundant `in-target` service-start suppression probe; (4) speculative rejection of nonlegacy CD-ROM APT sources and a redundant post-edit source scan (retain only the proven legacy CD-ROM adjustment); (5) old Backports pin, explicit priority-100 verification and other priority refusal rules; (6) repeated `dist-upgrade` post-install simulation requiring an empty plan; (7) repeated `autoremove` simulation requiring an empty plan; (8) unrelated conventional-swap or ambiguous `PARTLABEL` entry rejection in ZRAM's target `fstab`. Removed the cross-cutting unnecessary `apt-cache policy` inspection after repository refresh. An intermediate version scoped root recovery to selected profiles only; the later user-directed correction above restored the previously approved base-install recovery requirement.

**Retained user contracts:** All feature profiles remain opt-in, with no profile automatically added. Full APT simulation and native default-No approval remain before user-approved installs/upgrades; Backports cleanup retains individual package approval. Debian/firmware vendor-license consent, explicit selected ZRAM GPT identity, swapoff/destructive confirmations, rollback-aware `fstab` preparation and fail-on-command-error behavior remain. OMV and Docker keep their own one official signed repository each; their install operations and vendor init are unchanged. No new one-use helper.

**Reproducibility:** Full literal executable sources and SHA-1 Git blob IDs in 99's CDD construction chapters synchronized. Source review is not proof of a Debian Installer ISO build or successful VM first boot; repeat on a disposable disk.

## OMV keyring permission fix — 2026-11-16

**Nearest user prompt:** Screenshot evidence from the newest Debian Installer VM, showing OMV `apt-get update` failed after key import with `/usr/bin/sqv` error `Failed to parse keyring ... Permission denied (os error 13)` and exit status 100.

**Evidence and cause:** The shared `run-selected.sh` launcher sets `umask 077` to protect sensitive installer state. The OMV handler wrote its dedicated signing keyring without resetting its file permissions. Debian APT's unprivileged verification cannot read that keyring when created with mode `0600`. The official signed source itself was reachable; the evidence does not justify changing endpoints, mirrors, keys or disabling APT verification.

**Patch:** Add one `run_target chmod 0644 /usr/share/keyrings/openmediavault-archive-keyring.gpg` immediately after dearmoring the official public key, and before the first OMV `apt-get update`. Preserve the global umask, single official OMV APT source, approved package transaction and both vendor init commands. Update standalone 07 and the complete CDD 07 source/hash.

**Status:** The current VM diagnosis is confirmed; the corrected ISO has not yet been built or tested in a fresh disposable VM. OMV/Docker and first-boot ZRAM operation remain unverified.

## Shared installer failure popup / target stderr — 2026-11-16

**Nearest user prompt:** “make the actual errors pop in the interface if you want to get them”, in response to the newer VM run showing an OMV `apt-get update` failure with no underlying error in the native GTK dialog.

**Observed:** The latest VM successfully progressed beyond the old Debian tweaks SSH blocker, confirmed an automatically identified ZRAM GPT backing partition, separately approved targeted `swapoff` (0 used bytes), reviewed/installed the ZRAM generator and entered the OMV handler. OMV's key download/import succeeded; its first package-index refresh failed. Only “Target APT transaction failed: apt-get update” appeared; the actual APT diagnostics were not visible and the cause is still unknown.

**Source change:** `installer/run-selected.sh` now wraps **only** `capture in-target ...` invocations with an in-target POSIX shell `exec "$@" 2>&1`, preserving `in-target --pass-stdout` and its chroot/service/Debconf setup while exposing actual target stderr alongside stdout. `capture` retains the failed command and exit status, logs both streams, and `fatal` places them, the recognized APT/dpkg error lines and recent command output at the top of its existing native GTK/text note. The unmodified log path remains `/target/var/log/installer/my-cdd.log`; the fallback uses recent syslog only when the failed command produces no output.

**Source boundaries:** OMV remains one official signed APT repository and official package initialization, with no added OMV policy. The single ZRAM backed-partition selection/conversion procedure is unchanged. No change to any other selected-profile behavior was intended.

**Reproduction and verification:** The full `installer/run-selected.sh` listing and its Git blob hash in `99_custom_netintst/installer_framework.md` must match this source. A fresh disposable ISO/VM run must confirm that the diagnostic popup displays actual APT errors, returns fail-closed status and preserves package Debconf progress/approvals. Do not infer a mirror/DNS failure or claim runtime validation from these screenshots.

## Approved Debian tweaks / helper refactor — 2026-11-16

**Nearest user instruction:** “the noatime and errors=panic should be set no matter the filesystem of the root partition ... ensure_manual_updates sounds like a helper used only once. ... review all code for that kind of useless helpers”, approved by “i agree”.

**Source changes:** Debian tweaks now processes the only root `fstab` entry regardless of filesystem, saves `fstab.before-tweaks`, writes `noatime` generally, `errors=panic` only for ext2/3/4, and `fatal_errors=panic` for Btrfs. XFS/other filesystem error behavior is left untouched. The existing main SSH configuration receives `PermitRootLogin no` before global includes; the former drop-in, both preboot daemon tests and transient directory handling are gone. Automatic-upgrade configuration executes only in Debian tweaks and is never revisited by later profiles. The source refactor removes one-use `ensure_manual_updates`, `verify_target_sshd`, `reviewed_upgrade`, `zram_check_utilities`, `mark_complete`, and trivial `zram_blkid`; the repeated firmware `normal_suite` helper is moved into the firmware module. Complex and shared safety functions remain.

**Observed VM evidence:** The latest screenshots confirm Debian tweaks ran first, root recovery password was set, and the previous `sshd -t` test failed with the installer syslog `Missing privilege separation directory: /run/sshd`. Earlier screenshots demonstrated the selected-partition 1 MiB ZRAM conversion, not a successful first boot.

**Scope and release status:** The ZRAM partition chooser, default-No destructive approval, bounded erase, generator and monitor remain functionally unchanged. OMV and Docker remain independently selectable signed-APT profiles with no added SSH/update policy. Full CDD listings, hashes and guides require synchronization. No new ISO/VM outcome is claimed by this source refactor.

## Current approved OMV/ZRAM simplification — 2026-11-16

**Nearest user instruction:** “omv cdd should do nothing about ssh ... only things ... allowed ... are the ones done in the [official] install script ... nothing more”; “2. agreed” to the single ZRAM systemd override and preserved monitor; “go ahead”.

**Source boundary:** `installer/profile-omv.sh` now follows the current upstream official OpenMediaVault 8 installer (`openmediavault/openmediavault` `install.sh`): Debian/architecture/desktop checks, official signing key, the first official manual-install signed APT source (`http://packages.openmediavault.org/public/ synchrony main`), **not** a custom mirror list, reviewed `openmediavault` APT transaction, `omv-confdbadm populate` and `omv-salt deploy run hosts`. No OMV-specific SSH changes, usermod, update/notification policy, apticron, plugin or Docker actions remain. Previous OMV-specific SSH/update behavior described below is **historical and superseded**, not an active implementation requirement. OMV and Docker both use the shared signed-APT update, origin verification, transaction simulation and default-No approval workflow; vendor-specific initialization remains separate.

**ZRAM source boundary:** `installer/profile-zram.sh` copies one selected-only `scripts/override.conf` combining the previous compressed-writeback and setup-failure directives, plus `scripts/90-zram.conf`; the standalone `06_zram_writeback/files` assets use exactly the same bytes. `profiles/zram-writeback.extra` stages only the new filenames. Existing monitor, generator, backing identity and destructive safeguards remain unchanged.

**Tests and release gate:** The documentation's full embedded files and hashes must match their current source. Source-level review does not replace `sh -n`, an ISO build, a fresh text/GTK disposable-VM install, or first-boot compressed-writeback/OMV checks. That earlier SSH failure has now been reproduced with a visible `/run/sshd` diagnostic; the replacement source awaits a fresh VM test.

## Current synchronized change — 2026-11-16

**Nearest approved user prompt:** leave the initial Debian root password blank for a sudo administrator, then set a separate root recovery password; move Debian tweaks immediately after Base Debian; reorder chapters logically everywhere; clarify conditional `unattended-upgrades` handling; use editor-neutral instructions; and require ordinary and CDD feature changes to be synchronized. User also provided five Debian Installer VM screenshots showing the latest test stopped at `sshd -T` after ZRAM setup.

**Permanent rule:** Any new feature change must be reflected in its standalone Debian how-to, the corresponding CDD construction tutorial and, if needed, the actual installer source **in the same review**. Refresh the full embedded source listings and Git blob hashes, all links, selection order and release tests. Installer-only differences must explain the udeb/cdebconf/`in-target` reason. Record the authorizing prompt, date and evidence; request user approval before further decisions or edits.

**Current CDD execution order:** `debian-tweaks` → `backports` → `ensure-7x-kernel` → `extended-device-support` → `zram-writeback` → `openmediavault` → `docker`. The profile **IDs** are unchanged. `simple-cdd.conf`, `ordered-selection.sh`, `profile-confirm.sh`, `profile-confirm.templates` and `run-selected.sh` were synchronized.

**Account and SSH update:** Native Debian root password remains initially empty; the dispatcher verifies the first user is in `sudo` and that sudo is installed, then prompts for a distinct local root recovery password before selected work. Shared `verify_target_sshd` prepares a transient `/target/run/sshd` for config validation, runs `sshd -t` and `-T`, and preserves stderr in the target installer log. This is a **possible correction** for the latest failure, not a verified root cause.

**APT check:** `ensure_manual_updates` verifies that `unattended-upgrades` is installed before checking its enabled state. It writes no override if absent or already disabled; if enabled, it disables automatic package installation and verifies the APT configuration. The older selected-OMV update/notification policy is superseded by the current limited official-install profile.

**Latest VM evidence, status:** User's screenshots show native ZRAM choice and GPT conversion plus reviewed generator installation, then the selected tweaks stage failed with an “OpenSSH configuration invalid” message. No screenshot shows the actual OpenSSH stderr or first-boot writeback. Re-test all new steps before declaring the ISO functional.

**Static verification:** Every one of the **50 full CDD source listings** embedded in the construction guides was independently hashed as a Git blob and matched its actual branch file. The six relocated standalone firmware/ZRAM assets retain original blob identities and modes. The two installer shell entry points retain executable mode `100755`; no tracked installer source-file modes differ from the previous `main`. Local chapter and historical links were checked and repaired. The screenshots demonstrate a partial real VM run but **not** a successful entire installation or first boot. No new ISO build or actual `sh -n` execution was performed by the assistant.

**History below:** older “latest revision” and “installer source unchanged” statements describe their **own dates**, not this current change. Do not use those as current release status.

> **Current location (2026-11-16):** `99_custom_netintst/my-cdd/` (relocated from `01_custom_netinst/my-cdd/`). The historical entries below are preserved as dated provenance, not all current operational instructions. For ordinary Debian setup see [numbered chapters](../../README.md); the active installer path is in [99's README](../README.md). No installer executables changed in the relocation.

**Initial creation date:** 2026-11-14 (Europe/Berlin).  
**Latest revision:** 2026-11-15 (Europe/Berlin).  
**Nearest user prompt (latest change, paraphrased):** On 2026-11-15, uploaded four GTK installer screenshots confirming the custom kernel and headers transaction completed but ZRAM stopped because the installer-native `parted` executable was missing. Added the official `parted-udeb` to the existing Simple-CDD build-only media profile, native `anna-install` loading, and an ISO inclusion guard while preserving the original ZRAM partition approvals. Historic provenance follows.  
**Repository location:** `dcf1007/home_server/01_custom_netinst/my-cdd/`.

## Source provenance

- `profile_defaults.conf` and `profile_defaults.conf.example` were moved
  **unchanged** from the parent planning directory under the user's earlier
  instruction to name the project `my-cdd`.
- `simple-cdd.conf`, `profiles/` and the minimal `build.sh` implement the
  [documented installer project](../build_project.md), based on
  Debian Simple-CDD's native profile structure. Their source was initially
  generated after the user said “proceed”.
- `installer/profile-confirm.sh`, `profile-confirm.templates` and
  `ordered-selection.sh` support **user-approved option A**, a standard
  `preseed/early_command` hook before the unchanged upstream
  `simple-cdd-profiles` udeb. The user selected option A explicitly.
- The four ZRAM generator/monitor/systemd assets are **verbatim extractions**
  from the [approved original design in the historical archive](../history/03_zram_writeback.md#original-design--complete-source).
  They are not automatically deployed.
- `scripts/firmware-candidates.txt` follows the
  [Extended device support inventory](../05_extended_device_support.md).
  The signed Backports and ZRAM swappiness templates are only source material
  for their independently selected profiles.
- `installer/run-selected.sh` and `installer/profile-actions.sh` were written
  in the continuation after “replace the placeholders” and “ok. continue then”.
  They use Debian Installer's standard `preseed/late_command` to execute
  confirmed profiles, native cdebconf approvals, signed APT repositories,
  explicitly confirmed ZRAM conversion, OMV 8 and Docker safeguards. The seven
  `*.postinst` scripts now verify completion rather than duplicate the work.
  Their behavior remains **unverified on a running installer**.
- The remaining README and implementation notes document approved behavior,
  remaining integration work and safety limitations.

## Authorized cleanup

The following **seven unrequested test or unused development files were
deleted** from the current tree following the user's explicit “yes”:

- `tests/test_plan_firmware.py`
- `tests/README.md`
- `installer/test-ordered-selection.sh`
- `scripts/verify-source-layout.sh`
- `scripts/apt-simulate.sh`
- `scripts/inspect-zram-backing.sh`
- `scripts/plan-firmware.py`

The automatic Python/shell offline test execution, the additional
`--check`/`--test-build`/`--release` modes and the artificial
`INTEGRATION_*`/`FIRST_BOOT_TESTED` build markers were removed from
`build.sh`. The current script is a direct `build-simple-cdd` invocation
with only an unfinished-profile safeguard. File history remains in Git.

## Authorized change: 2026-11-15 ZRAM selection correction

**Creation date:** 2026-11-15 (Europe/Berlin).
**Nearest user prompt:** “i authorise” after “I agree” and the detailed
new/reused swap and native GTK selection decisions.
**Base commit:** `df8ea81ea40a1131c8fd0fdb3e6ff9eaf82f61bf`.
**Working branch:** `fix/zram-backing-selection-20261115`.

- **New** `installer/zram-selection.sh`: collects GPT Linux-swap and prior
  validated raw `zram-writeback` candidates; identifies the unique swap
  assigned to the new target fstab or offers a Debconf `Choices-C` single
  select with safe default, including reused swap partitions.
- **Edited** `installer/profile-actions.sh`: exact selected identity and
  safety checks, independent destructive confirmation, targeted swapoff with
  memory reserve, removal of exact conventional swap fstab references,
  unchanged conversion-before-provisioning order.
- **Edited** `installer/profile-confirm.templates`: native select question,
  display of selected disk and provenance, warning on possible other-OS use.
- **Edited** `simple-cdd.conf`: ship the additional helper on install media.
- **Edited** `build.sh`: check executable hooks instead of changing Git
  checkout permissions. Tracked `build.sh` and all seven
  `profiles/*.postinst` modes changed to `100755`.
- **Updated** the related installation, profile, validation and source
  documentation. `scripts/zram-generator.conf.template` remains unchanged.

**Source-only:** No Debian Installer GTK/text execution, ISO build,
partition conversion, swapoff, first boot, or recovery test was performed.
Kernel Backports/profile-selection and full end-to-end diagnostic gates
remain open. The original embedded ZRAM source is retained.

## Authorized follow-up: apt CLI (2026-11-15)

**Nearest user prompt:** the user's earlier request to switch installer transactions to `apt` and attempt a Debian 13 chroot build.

- Replaced all legacy package-manager executable invocations with user-requested `apt` in
  `installer/profile-actions.sh` and `installer/run-selected.sh`, without
  changing package selections, simulations, approval gates or ordering.
- Confirmed that Debian 13 `apt -s install`, `apt -s full-upgrade` and
  `apt -s autoremove --purge` accept the existing simulation forms. Debian
  warns that `apt` does not have a stable scripting interface; runtime
  integration remains untested.
- Attempted an isolated Debian 13 chroot build but could not bootstrap a
  fresh Debian installation or install `simple-cdd`: package indexes were
  unavailable and both DNS and external network traffic failed.
  A minimal Debian 13 host-derived fallback chroot executed the original
  verified build wrapper; it stopped because `build-simple-cdd` was absent.
  **No ISO was built, no installer ran and no disk was modified.**

## Repository-wide APT naming follow-up (2026-11-15)

**Nearest user prompt (paraphrased):** Use `apt` throughout the repository, including documentation, and eliminate references to the old CLI spelling.

**Provenance:** The already-merged installer shell change was retained unchanged. Based on `main` commit `d5be1f583578ba2224a20e530dcb546b7ad8fa93`, this follow-up updates four planning documents and this manifest. All 61 tracked files were checked for remaining legacy command references. No package operations or installer build were performed for this wording-only update. The existing Debian warning about `apt` output instability in scripts still applies.

## Installer packaging defect and correction (2026-11-15)

- **Observed:** the user booted the generated 395 MiB Debian 13 installer-only ISO to the graphical Debian Installer, but at "Load debconf preconfiguration file" the preseeded command `/bin/sh /cdrom/simple-cdd/profile-confirm.sh && anna-install simple-cdd-profiles` exited with status **2**. The screenshot does not independently distinguish which subcommand failed.
- **Source-level finding:** `simple-cdd.conf` listed 13 installer assets as relative entries in `all_extras`. Upstream Simple-CDD's Debian-CD tool changes its working directory before copying these paths and skips files it cannot read. This is consistent with an omitted `/cdrom/simple-cdd/profile-confirm.sh` (running `/bin/sh` on a nonexistent script exits 2).
- **Correction:** `profiles/default.extra` now enumerates the original 13 assets. Simple-CDD resolves each relative entry against `simple_cdd_dir` before changing into the Debian-CD workspace. The old `all_extras` assignment was removed. `build.sh` verifies every staged asset's bytes against the source, plus the generated `simple-cdd.templates`.
- **Entry-point permissions:** `installer/profile-confirm.sh` and `installer/run-selected.sh` now have Git mode `100755`, because sourcing the Debconf `confmodule` may relaunch a script by pathname. `build.sh` also checks executable permissions in the staged ISO tree.
- **Validation boundary:** GitHub source contents, references and executable mode were checked; **a rebuilt ISO and successful graphical installation have not yet been demonstrated after the correction**. The original early Debconf method A remains unchanged. No disk operations were authorized or performed.

## Netinst base-system and interactive-defaults correction (2026-11-15)

- **Nearest user prompt:** “also you seem to have ignored me when i said that it also did not read any of the pre-set configurations. no locale, no keyboard etc; i don't have the shell access anymore so you'll have to make a guess”. This followed screenshots of failed base installation.
- **Observed:** the graphical installer successfully mounted `/target` (ample free space) and reached `bootstrap-base`, but debootstrap reported missing `/target/dev/*` paths and could not execute `/bin/true` in the target. The previous `INSTALLER_CD="1"` produced an installer-only ISO; `INSTALLER_CD="2"` includes Debian Installer **and the base system**. This is a source-backed correction and a likely resolution, not a proven diagnosis of every underlying debootstrap error.
- **Confirmed configuration omission:** `profile_defaults.conf` previously contained only symbolic planning defaults; neither `simple-cdd.conf` nor `default.preseed` applied its values, and ISO file preseeding occurs after language/keyboard prompts.
- **Correction:** `build.sh` sources `profile_defaults.conf` and validates values. It writes `tmp/generated/simple-cdd.conf` with early editable `?=` locale/language/country/keyboard kernel parameters and `tmp/generated/defaults.preseed` for hostname, administrator username, time zone, UTC and headless tasksel, with Debconf `seen false` resets. `profiles/default.preseed` includes the rendered defaults and `profiles/default.extra` packages the generated file. Normal DHCP and an empty domain remain native; passwords, device identifiers, disk changes, and optional profile selections are not preseeded.
- **Tests/boundary:** a representative preseed grammar sample was accepted by `debconf-set-selections --checkonly` in the assistant environment. The `build.sh` wrapper now validates generated preseed syntax and staged ISO inclusion, but **no Simple-CDD ISO build or live installer retest has yet been performed using these changes**. As before, selected-profile runtime, security and destructive operation behavior remains unverified.

## Historical single-invocation experiment (2026-11-15; reverted)

- **Nearest user prompt:** “now that you know what was hapenning, can you fix it without having to do a two stage build?”
- **Upstream behavior examined:** Simple-CDD 0.6.9/0.6.10 generates `UDebComponents: main` independently of `mirror_components`. The earlier split invocation first imported only `main` installer udebs, then explicitly changed the generated repository and imported `contrib` and `non-free-firmware`. Its next run could fail with a stale reprepro database target (`u|trixie|contrib|amd64`).
- **Historical implementation (now removed):** for one commit series, `build.sh` called `build-simple-cdd` once and installed the project-owned `scripts/reprepro-udeb-wrapper.sh` as a temporary `PATH` wrapper to change `UDebComponents` just before invoking `/usr/bin/reprepro`. This wrapper is no longer present or invoked.
- **Historical testing:** the wrapper passed a local simulation, but no live Simple-CDD build or installer boot using the wrapper was verified before it was removed.

## Restored two-stage build (2026-11-15)

- **Nearest user prompt:** “prioritize simplicity and maintainability over reducing two commands to one. remove the wrapper and leave the two stage build”.
- **Change:** deleted `scripts/reprepro-udeb-wrapper.sh` and removed all temporary PATH interception from `build.sh`. The build runs `build-simple-cdd --mirror-only`, expands the generated local `UDebComponents` to include `contrib` and `non-free-firmware`, runs `reprepro update`, checks both udeb indexes, and then runs `build-simple-cdd --build-only`. Separate `build-mirror-debug.log`, `build-debug.log` and combined `build-terminal.log` are retained.
- **Repeat-build cleanup:** if a previous build's reprepro database exists, the script accepts only the expected local `UDebComponents` configuration, resets it to `main` and invokes `reprepro --delete clearvanished` on `tmp/mirror` before Simple-CDD's first stage. It does not delete the mirror package cache. This cleanup has not been validated in a successful repeat build.
- **Unchanged:** `INSTALLER_CD="2"`, `profile_defaults.conf` and its generated editable boot/preseed files, all selected-profile scripts, ISO file comparisons, and executable-mode checks. The previously successful two-stage build used `INSTALLER_CD="1"`; the newly configured netinst still needs real build and installation tests.

## Missing `zstd` during base installation (2026-11-15)

- **Nearest user prompt:** uploaded two screenshots of the graphical Debian Installer and virtual console at “Install the base system,” showing `base-installer/kernel/failed-package-install` and `E: Package 'zstd' has no installation candidate`.
- **Observed:** the new two-stage `INSTALLER_CD="2"` netinst built successfully (408 MiB, 509 packages). During its VM installation, target APT installed `busybox` from `cdrom:` but could not find the distinct `zstd` command-line package. Earlier logs showed `libzstd1` and `libzstd1-udeb` downloads, neither of which substitutes for `zstd`. The official Debian 13 `zstd` package exists in `main`. The CD package subset omission is the evidence-backed immediate reason; no additional installer syslog was provided.
- **Initial source correction (later refined):** first appended `zstd` to `profiles/default.packages`. This ensured media inclusion but also queued its automatic installation with the always-present default profile, unnecessarily broadening the target baseline. The later correction moved it to `profiles/default.downloads`, documented separately below. After `--build-only`, `build.sh` reads the staged `CD1/dists/trixie/main/binary-amd64/Packages.gz`, extracts the exact `Package: zstd` record's `Filename`, and requires that the corresponding `.deb` exists and is nonempty.
- **Unchanged:** the documented two-stage mirror-build process, `INSTALLER_CD="2"`, editable installer defaults, seven unselected optional profiles and pre-existing ISO asset checks.
- **Validation boundary:** source-only changes; the corrected `zstd` ISO has not been rebuilt or install-tested. A successful rebuilt ISO/package check would not by itself prove the whole installation, including locale/keyboard GUI values and optional profiles.

## Installer-media `zstd` dependency refinement (2026-11-15)

- **Nearest user prompt:** “shouldn't zstd be a requirement in the zram profile and not in default?”
- **Evidence:** Debian Installer requested `zstd` during `base-installer/kernel` while performing the standard base installation, before any optional ZRAM work. The installed-target ZRAM code uses `systemd-zram-generator` with the Linux kernel's ZSTD compression algorithm; it does not directly invoke the user-space `zstd` command.
- **Simple-CDD semantics verified:** upstream 0.6.9 includes both `default.packages` and `default.downloads` in CD package selection. `*.packages` is automatically installed for a selected profile, while `*.downloads` places files on the media without automatically installing them through Simple-CDD (Debian Installer may still install them for its own reasons).
- **Intermediate implementation (superseded):** project-local `profiles/default.downloads` listed only `zstd`, replacing rather than merging the upstream default downloads due to Simple-CDD's first-match profile resolution. This file has since been deleted and replaced by a uniquely named build-only profile. The separate staged-ISO `zstd` index/archive gate remains, and the optional ZRAM package queue remains empty.
- **Validation boundary:** source changes checked, but not yet rebuilt or tested in a graphical installer. This change does not prove the installed system's final package set or successful base installation.

## Upstream default restoration and Debconf summary correction (2026-11-15)

- **Nearest user prompt (paraphrased):** “there are saltos de linea missing ... even when not selecting any of the custom profiles ... why are you not using the default.downloads given by cdd? ... have we overridden some files we should not have touched?”
- **Confirmed Simple-CDD 0.6.9 behavior:** `build-simple-cdd` resolves a profile file by searching `simple_cdd_dirs` and yielding **only the first match**. A local `profiles/default.downloads` therefore fully obscures the packaged `/usr/share/simple-cdd/profiles/default.downloads`, rather than appending to it. The upstream list contains GRUB variants, console setup, LVM/RAID/cryptsetup, debootstrap, busybox, boot media packages and more. This was an unintended regression in the intermediate `zstd` fix.
- **Changes:** deleted local `profiles/default.downloads` and the redundant `profiles/default.udebs` (upstream version already requests `simple-cdd-profiles`); added `build_profiles="installer-media"` to `simple-cdd.conf` and `profiles/installer-media.downloads` containing `zstd`. Build-only profiles contribute packages to the CD without becoming installer checkbox choices. Updated `build.sh` to fail if a local `default.downloads` or `default.udebs` reappears, if the upstream installed copies are unavailable, or if the build-only `zstd` profile is not configured. Preserved the existing final ISO `zstd` index/archive gate and the **two-stage** build.
- **Other defaults audit:** local `default.preseed` intentionally overrides the upstream sample because it must keep interactive Debian Installer questions and manual partitioning (the upstream example specifies automatic/hidden choices). Local `default.packages` is intentional for SSH/sudo/time-sync and now retains upstream `less`; local `default.extra` is project-specific. No installed Simple-CDD file was modified.
- **Display correction:** the seven status lines in `installer/profile-confirm.templates` now start with **two** continuation spaces, making them preformatted per Debian Debconf template conventions rather than joining them into one paragraph. The existing conditional status substitutions, choices, default-No confirmation and installer hook remain unchanged.
- **Validation:** GitHub source inspection plus official upstream source/specification review; **no rebuilt ISO or GTK/text install test has been performed with this latest source**. The user explicitly reran an older ISO, so its recurring `zstd` error does not test the changed `installer-media.downloads`.

## Authorized source reorganization (2026-11-15)

- **Nearest user request:** Clarify Docker/OMV first-boot semantics and the firmware inventory; eliminate unconditional base policies; add editable German country and `dcf1007-world` domain defaults; streamline redundant Simple-CDD profile inputs; improve installer labels and organize selected-profile helpers. Runtime installation validation was deferred.
- **Immutable architectural constraint:** Do not edit CDD-generated outputs, except the existing narrowly scoped `UDebComponents: main` -> `main contrib non-free-firmware` generated local mirror workaround and associated reprepro reconciliation. Upstream default downloads/udebs/packages are inherited.
- **Changes:** removed local default package and descriptive overrides, duplicated sample defaults and seven comment-only optional package lists; separated optional assets into native per-profile `.extra` inputs; split the existing shared action file into a common helper and seven selected-only modules, without changing operation bodies. The unselected late-command path no longer enforces sudo, a root password, SSH root-login policy or manual APT updates.
- **Defaults:** `DEFAULT_COUNTRY="DE"`; `DEFAULT_DOMAIN="dcf1007-world"`; language English, locale en_US.UTF-8, keyboard Spanish and timezone Europe/Berlin retained.
- **Unchanged:** the entire Extended device support inventory is attempted regardless of detected hardware; version/source choices and omissions are conditional on signed repository compatibility and explicit approval. The build-only installer-media `zstd` request remains; no global target installation was added. Docker daemon/socket manual-start behavior remains pending clarification and separate authorization.
- **Follow-up integrity adjustment:** With no unconditional `default.packages` override, the selected OMV profile explicitly reviews/install-checks its required `openssh-server` and `sudo` prerequisites before preserving administrator SSH/sudo access. Debian tweaks applies its SSH hardening only when OpenSSH was actually installed by native task selection. Trailing comments accidentally carried over during the function split were removed; the function bodies otherwise remain intact. These changes have not been installer-tested.
- **Validation boundary:** Changes were made on a review branch, not merged into main. Neither the revised ISO nor real installer phases have been built or boot-tested.

## Approved root-recovery and native-service follow-up (2026-11-15)

- **Nearest user prompt:** “Leave docker and omv independent and don't attemp any install of OMV-Extras Compose. If I decide to install it from the Web interface it will take care of the sources. Therefore leave everything by default for the first boot and don't deactivate anything. The root account password check should occur before applying any of the custom profiles. I agree with your findings.”
- **Recovery check:** The common `installer/run-selected.sh` preflight runs before the profile loop, including the zero-profile path. It inspects `passwd -S root`. Existing usable root passwords are preserved. If locked or passwordless, it displays the original Debian Installer password-type questions twice, rejects empty/mismatched/control-character-containing entries, clears the temporary Debconf values, applies the password through target-side `chpasswd` standard input, then verifies root has a usable password. It does not add user sudo privileges or enable root SSH.
- **Service behavior:** Removed Docker `systemctl mask`, `unmask`, `disable` and desired-disabled checks; official Docker package installation now owns startup behavior. OMV already had no service-start suppression. The optional profiles remain separate, and neither installs OMV-Extras or `openmediavault-compose`. A later web-interface installation of the optional integration belongs to the user.
- **Policy scope:** Existing OMV cron-apt *scheduled update* disabling remains as previously approved; it is not a Docker/OMV systemd service startup suppression. All seven profile IDs and the authorized `UDebComponents` workaround remain unchanged.
- **Validation:** These source changes have **not** been ISO-built or executed in a Debian 13 GTK/text installer. Password prompts, cdebconf clearing, target `chpasswd`, selected-profile ordering, and first-boot services must be tested in a disposable VM before merge.

## Native installer service policy and OMV 8 updates (2026-11-15)

**Nearest user prompt:** “You should prevent the execution of unnecessary services coming from the custom profiles during the installation phase. Is that necessary or they won't interfere? Keep omv updates off.”

- Verified from Trixie `debian-installer-utils` 1.155 that `in-target` already temporarily rejects normal service starts using `policy-rc.d` status 101 and diverts `start-stop-daemon`. Added a preflight to confirm this native policy before selected operations, without persistent systemd masks or disablement.
- OMV 8.6.2 source changed from older `cronapt` settings to `conf.system.apt.updates`, APT notification settings and `apt`/`apticron` Salt. Updated the selected OMV profile to turn off unattended upgrades and generated scheduled update notifications via OMV's configuration database, plus both Debian periodic APT settings. No OMV-generated files were directly modified.
- Docker and OMV remain independent, with normal first-boot service settings. The prior conditional root recovery preflight and authorized `UDebComponents` mirror workaround remain unchanged.
- **Unverified:** OMV Salt DNS/service interactions and complete new ISO installer tests remain release blockers.

## Final authorized OMV Salt sequence before main integration (2026-11-15)

- **Nearest user prompt:** “I agree. Then proceed to integrate the changes in main, if there's nothing else to discuss”; immediately preceding agreement: use the supported `omv-salt stage run prepare` before targeted `omv-salt deploy run apt apticron`, not the broad `stage run all`, and keep OMV scheduled updates off.
- **Code:** The OMV 8 profile refreshes Salt grains/modules/pillar after updating the OMV configuration database and before deploying the two update-related states. It does not redeploy unrelated OMV services or set the obsolete OMV 5 `OMV_CRONAPT_SECURITY_UPGRADES_ENABLED` variable.
- **Preserved:** The OMV and Docker profiles remain independently selectable, no OMV-Extras/Compose install occurs, the OS root-recovery preflight precedes optional profiles, OMV unattended/scheduled updates remain disabled, and normal first-boot service defaults are retained. The single authorized generated-mirror `UDebComponents` change is unchanged.
- **Validation:** This is a source-level maintenance change. ISO generation, Debian 13 graphical/text installer execution, OMV DNS/Salt service interactions and first-boot behavior remain unverified pending disposable-VM testing.

## User-reported GTK installer failure and source correction (2026-11-15)

- **Nearest user prompt:** “fix the issues so i can generate a new image”, after screenshots of Debian Installer's late-command failure and an installed system showing empty `/var/log/installer/my-cdd-completed/`, no ZRAM, and no OMV/Docker.
- **Evidence:** Base Debian completed and booted after inclusion of the missing `zstd` package. The user selected all seven profiles but the common late runner stopped on its initial `passwd -S root` parse because `in-target` by default routes standard output to the installer syslog. This failure occurred before any custom profile could begin.
- **Source change:** Central `capture()` automatically invokes `in-target --pass-stdout`; this applies to all target APT simulations, candidate/version checks, sshd output and root status parsing, without changing package/profile policy. `chpasswd` receives its secret only on the stdin of a direct target `chroot`, bypassing `in-target`'s Debconf stdin. Target `/var/log/installer/my-cdd-status` explicitly records `INCOMPLETE`, `FAILED` or `COMPLETE` for a later manual check. No password is written to custom logs or source files.
- **Tasksel status:** Trixie tasksel 3.81's `tasksel-debconf` overrides a preseeded value when marked `seen=false`; setting it true may hide the ordinary editable screen. The project retains the normal screen, and a user must currently select only `ssh-server` and `standard` manually. This is a known outstanding GUI-default defect, not a completed fix. Patching upstream tasksel, suppressing the GUI, or replacing the native screen was not authorized by this user request.
- **Testing:** This revision has no ISO build or installer GUI test. Require testing the fallback root password prompt (and cancellation/mismatch) plus every profile's actual reviewed APT transactions; the prior failure blocked them all.

## CD-ROM APT timing fix and native finish-install status gate (2026-11-15)

- **Nearest user prompt:** “the dialog to set the root password did show up, this happens after. i thought this time at this point the installation would abort but it continues again. I am not going to test it. let's fix it first and i with generate the next iteration of the image”.
- **Source evidence:** User's GTK installer screenshots show root account password was established (status P) and Debian Installer's normal `policy-rc.d` protection verified. At the first selected profile, `apt update` failed with `Please use apt-cdrom to make this CD-ROM recognized by APT` while Backports and other network repositories were reachable. Debian Installer subsequently showed its standard `Installation complete` despite `preseed/late_command` exit 1. The original seven profiles were selected but not completed.
- **Timing:** Debian preseed 1.125 uses `/usr/lib/finish-install.d/07preseed` for the late command. The native apt-setup CD-ROM disabling runs at `10apt-cdrom-setup`, then Simple-CDD's completion verifier at `14simple-cdd`, then finish-install's `20final-message`. Therefore the custom APT operation must handle the active installation CD-ROM source earlier without changing the CD itself.
- **Narrow APT correction:** `installer/run-selected.sh` comments only active legacy `deb cdrom:` and `deb-src cdrom:` entries in installed target APT source lists before any selected custom profile. It retains http(s) sources, fails on unfamiliar active deb822 CD-ROM source arrangements, and sets `apt-setup/disable-cdrom-entries` in the normal preseed for Debian's own subsequent cleanup. No media remounting or regenerated Simple-CDD files are involved.
- **Finish-install status gate:** New executable `installer/15my-cdd-status` is staged via `profiles/default.extra` and registered in `/usr/lib/finish-install.d/` by the early confirmation script, before the native finish-install hook list is constructed. It succeeds only if `/target/var/log/installer/my-cdd-status` is `COMPLETE` and every selected `my-cdd-completed` marker exists; otherwise returns `10`, the upstream finish-install special `back up` code. This returns to the installer menu rather than falsely showing `Installation complete`. It is not a forced abort/shutdown of the installed OS. Build checks verify the staged executable and `sh -n` syntax.
- **Sources reviewed:** Debian Trixie finish-install 2.124 `debian/postinst`, preseed 1.125 `finish-install.d/07preseed`, and apt-setup's `apt-setup/disable-cdrom-entries` and `finish-install.d/10apt-cdrom-setup` mechanisms. Native packages remain unpatched.
- **Validation:** Source and isolated sed/shell syntax tests only, **no new ISO build or actual installer run**. Full GTK/text validation, especially the real exit-10 main-menu path and all selected-profile transactions, remains required. OMV automatic updates remain off, Docker/OMV independent, root recovery preflight remains mandatory, and the authorized local mirror udeb component workaround is unchanged.

## Native APT progress and exact-version firmware licenses (2026-11-15)

- **Nearest user prompt:** “while apt is running i can only see 'running preseed...'. is it a way to show the progress like the normal setup pages do? I agree the license should be shown and accepted by the user in the gui. can you fix that using cdd's own mechanisms?”
- **Direct VM evidence:** The previous test progressed past Backports and the reviewed Linux 7.2.12 Backports kernel image/headers, then the complete firmware install failed while unpacking `firmware-ipw2x00` and `firmware-ivtv`. D-I syslog recorded an inaccessible target Debconf passthrough frontend at fd 3; the normal `Running preseed...` label remained visible during transactions.
- **Upstream mechanisms verified:** Debian 13 `debian-installer-utils` 1.155 `apt-install` uses `in-target` with `debconf-apt-progress`; the `debconf-apt-progress` manual describes GUI progress, `--logstderr`, and Debconf passthrough. Firmware-nonfree source for Trixie includes full Boolean Debconf license questions `firmware-ipw2x00/license/accepted` and `firmware-ivtv/license/accepted`, with their own maintainer scripts refusing license declines.
- **Approved source changes:** Actual APT installs/upgrades/autoremove and source refreshes now pass through `in-target debconf-apt-progress --logstderr -- apt-get`. APT simulations, including kernel and firmware candidate compatibility checks, now also use `apt-get` to match the real transaction. No package-selection or first-boot service policy is relaxed.
- **Exact native vendor licenses:** After the reviewed firmware transaction, each selected license-restricted package is downloaded to a new root-owned temporary target directory using `apt-get download package=version` from the suite version already selected by the firmware algorithm. The binary's package name and version are checked via `dpkg-deb`. Its complete, unedited `DEBIAN/templates` is loaded by the existing installer `debconf-loadtemplate`. The actual Boolean question is reset to false and shown at critical priority. Accepted consent is piped to the target's `debconf-set-selections`, and checked with `debconf-communicate` before the package transaction; license bytes and acceptance are not embedded in ISO or the repository. The temporary downloaded package and extracted templates are removed after a completed answer.
- **Explicit refusal path:** A No answer does not accept the license. The original single-package, default-No omission confirmation is required to remove the package from the final selector set, with a new complete `apt-get` simulation and approval. Any declined package reintroduced as a dependency blocks installation. A refused omission remains fatal.
- **Validation:** GitHub source checks and a read-only Debian 13 `debconf-apt-progress --logstderr -- apt-get -s install apt` invocation passed. **Not** a GUI or package-installation test. The next disposable VM must verify actual graphical progress, full-license readability/buttons, separately saved consent, refusal and omission paths, Debconf fd-3 passthrough, and final `dpkg --audit`. Continue to block real-disk deployment until validated.

## Explicit apt-get source simplification (2026-11-15)

- **Nearest user prompt:** “go ahead and do the cahnges”, referring to the approved proposal to replace all remaining `run_target apt ...` calls with explicit `run_target apt-get ...` and simplify the shared adapter.
- **Change scope:** The shared installer runner and only five profile/source modules (common, Backports, kernel, firmware and Docker). Other modules and package lists are unchanged.
- **Semantics:** `apt update` becomes `apt-get update`; `apt -y install` becomes `apt-get -y install`; `apt -y autoremove --purge` becomes `apt-get -y autoremove --purge`. The prior wrapper translated `apt -y full-upgrade` to `apt-get -y dist-upgrade`; both the source call and matching simulation now explicitly say `dist-upgrade`. Target execution still uses `in-target debconf-apt-progress --logstderr -- apt-get` with the existing approval process. Non-transaction inspection uses `apt-cache` and `apt-config` as before.
- **Intent:** Remove the implicit `apt`-to-`apt-get` translation, keep all reviewed APT transactions and native progress, and avoid any policy or behavior changes.
- **Validation:** Source comparison and syntax checks only; full Debian Installer GTK/text execution and first-boot behavior still require a disposable-VM test.

## Selected ZRAM: installer vs installed-target util-linux utilities (2026-11-15)

- **Nearest user prompt:** Three Debian 13 installer screenshots dated 2026-11-15, showing previously approved kernel, firmware and microcode APT transactions completed and the ZRAM stage immediately failed with `Installation stopped: ZRAM conversion requires unavailable installer utility: lsblk`. The screenshot log shows `PROFILE COMPLETE: extended-device-support`, then `PROFILE BEGIN: zram-writeback` and the fatal utility preflight.
- **Cause and verified packaging facts:** The Debian Installer runs in a stripped-down udeb environment; the standard Debian 13 `util-linux` package supplies `/usr/bin/lsblk` in the *installed* system. Requiring that command in the installer shell was incorrect. Other `util-linux` operations such as `blkid`, `findmnt`, `swapon`, `swapoff` and `wipefs` can have the same mismatch.
- **Exact source change:** `installer/zram-selection.sh` now defines namespaced wrappers that run just the required target tools via D-I's standard `in-target --pass-stdout`. `installer/profile-zram.sh` sources those wrappers and validates installer-side `parted`, `readlink`, `cmp` plus target command availability and target device/proc/sys visibility before choosing or converting a partition. The `/target` root mount is checked using installer-side `/proc/self/mountinfo`, not target-side `findmnt -M /target`. Selected `swapoff` and `wipefs` still operate only on the separately approved block device and use the same privilege and safety checks.
- **Preserved:** No ISO media additions, `.extra` changes, generated-file edits, new automatic package installation, modified GPT choices or altered Debconf `my-cdd/zram-swapoff` question. The earlier Linux 7.x dependency, kernel/memory checks, targeted swapoff approval, exact PARTUUID identity and unique-holder/mount constraints, atomic target fstab update, and root rescue password remain intact. No effect on Docker, OMV or other independent profiles.
- **Validation:** Read-only source review only; installer tooling, target namespace availability, GPT partition conversion and first boot remain runtime release gates. A clean disposable VM installation is required to validate this change before using a real disk.

## Official installer-native parted-udeb for selected ZRAM (2026-11-15)

- **Nearest user message:** Four Debian 13 GUI screenshots dated 2026-11-15 showing a successful kernel/header package transaction and a subsequent ZRAM prerequisite failure: `ZRAM requires unavailable Debian Installer utility: parted`. Previous question explicitly preferred installer-native tools over copying executables into Debian Installer.
- **Cause:** The selected ZRAM profile correctly left GPT editing in Debian Installer, but assumed the minimal udeb environment included the `parted` command. It is not guaranteed to be available after normal partitioning.
- **Supported Debian mechanism:** Debian Trixie provides `parted-udeb` (source parted 3.6-5) with native `libparted2-udeb`, `libuuid1-udeb` and `libc6-udeb` dependencies. Debian Installer's `anna-install` loads additional udebs and resolves normal udeb dependencies. Simple-CDD 0.6.9 collects `*.udebs` from build-only profiles.
- **Implementation:** Added only `profiles/installer-media.udebs` with `parted-udeb`. The ZRAM action calls `anna-install parted-udeb` only when `parted` is missing, then checks it is accessible **before** any partition selection, swapoff, GPT edit or wipefs. No ordinary Debian .deb, unapproved binary copy, local custom udeb or replacement of upstream `default.udebs`. The existing installer-side `parted` operations and all PARTUUID, GPT, memory and explicit default-No destructive approvals are unchanged.
- **Build gate:** Existing Simple-CDD source guard checks `installer-media.udebs` plus the build-only profile; after ISO assembly it verifies that the main Debian Installer Packages.gz index identifies `parted-udeb` and that its referenced udeb archive is present. If not, it stops rather than reporting a usable ISO.
- **Scope limitation:** The earlier supported `in-target` wrapper still runs `lsblk`, `blkid`, `findmnt`, `swapon`, `swapoff` and `wipefs` against the installed target with its own libc, not the installer's libc. This change does not claim to make all util-linux commands installer-native.
- **Unverified:** Actual `anna-install` loading at the late finish-install stage, installed udeb CLI availability, matching installer package indexes and safe GPT conversion require a fresh disposable-VM ISO test. No real disk may be used as validation.

## Actual implementation state

**Not a validated ISO.** The seven optional profiles are described; their
`.packages` files intentionally do not queue unreviewed packages, and their
`.postinst` files verify installer-stage completion records. The approved
early confirmation and late ordered actions are connected in source but have
not been run inside Debian Installer. The existing original ZRAM assets and
all 37 firmware/microcode inventory names are unchanged.

Real APT transactions, native GTK/text prompts, destructive ZRAM conversion,
OMV/Docker package service behavior, boot-menu changes and first-boot
behavior remain unverified. That earlier source-writing turn did not perform an ISO build. Later on 2026-11-15, the user successfully built the ISO and tried the graphical installer, which failed at preseed loading. No installed-target package transaction or disk modification has been demonstrated. No mock/offline
test harness was added.

## Current tracked CDD files (56; updated 2026-11-16)

Current source filenames on the review branch; historical SHA-specific inventories above describe their own dated revisions.

- `.gitignore`
- `README.md`
- `SOURCE_MANIFEST.md`
- `build.sh`
- `installer/15my-cdd-status`
- `installer/IMPLEMENTATION_GATES.md`
- `installer/README.md`
- `installer/ordered-selection.sh`
- `installer/backports.sh`
- `installer/profile-common.sh`
- `installer/profile-confirm.sh`
- `installer/profile-confirm.templates`
- `installer/docker.sh`
- `installer/extended-device-support.sh`
- `installer/ensure-7x-kernel.sh`
- `installer/openmediavault-firstboot.service`
- `installer/openmediavault-firstboot.sh`
- `installer/openmediavault.sh`
- `installer/debian-tweaks.sh`
- `installer/zram-writeback.sh`
- `installer/run-selected.sh`
- `installer/zram-writeback-selection.sh`
- `profile_defaults.conf`
- `profiles/README.md`
- `profiles/backports.description`
- `profiles/backports.extra`
- `profiles/backports.postinst`
- `profiles/debian-tweaks.description`
- `profiles/debian-tweaks.extra`
- `profiles/debian-tweaks.postinst`
- `profiles/default.extra`
- `profiles/default.preseed`
- `profiles/docker.description`
- `profiles/docker.extra`
- `profiles/docker.postinst`
- `profiles/ensure-7x-kernel.description`
- `profiles/ensure-7x-kernel.extra`
- `profiles/ensure-7x-kernel.postinst`
- `profiles/extended-device-support.description`
- `profiles/extended-device-support.extra`
- `profiles/extended-device-support.postinst`
- `profiles/installer-media.downloads`
- `profiles/installer-media.udebs`
- `profiles/openmediavault.description`
- `profiles/openmediavault.extra`
- `profiles/openmediavault.postinst`
- `profiles/zram-writeback.description`
- `profiles/zram-writeback.extra`
- `profiles/zram-writeback.postinst`
- `scripts/90-zram.conf`
- `scripts/README.md`
- `scripts/debian-backports.sources`
- `scripts/firmware-candidates.txt`
- `scripts/override.conf`
- `scripts/zram-generator.conf.template`
- `scripts/zram-pressure.service`
- `scripts/zram-pressure.sh`
- `simple-cdd.conf`
