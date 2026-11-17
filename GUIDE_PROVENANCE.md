# Guide provenance and scope

## Remove unapproved installer policy restrictions — 2026-11-17

**Nearest user instruction:** “it's none of your business what you consider risky or unexpectedd. If i have not asked something and approved it, you should not do it. remove them all. the user can see what the installer is going to do and decide on its own. keep only the things i asked and authorised”.

**Immediate evidence:** The latest Debian 13 VM reached OMV's APT simulation, which proposed removing `systemd-timesyncd` as part of installing OMV, but our project-defined `check_critical_removals` blocked approval. This was not a failure of APT's own dependency resolution. Proposed PR #23 added a package-specific exception, contrary to the user's requirement; it was **closed without merging**. The current branch replaces it with removal of the entire unrequested blacklist.

**Source corrections:** The shared package-removal blacklist and every call are deleted; kernel/firmware candidate selection no longer rejects APT-resolved transactions due to package-name filters. `run_target` and `simulate_target` no longer apply custom command-operation whitelists, but preserve the native Debian Installer progress UI, complete APT simulation, and explicit default-No user approval. Removed redundant service-start suppression preflight, speculative Deb822 CD-ROM source rejection/recheck, Backports old-pin and effective-priority refusal gates, and Backports extra post-upgrade/post-cleanup “nothing remains” simulations. The original minimal legacy installer CD-ROM source adjustment remains to address a previously observed APT failure. APT continues to enforce its own dependency/signature rules.

**Selected partition scope:** ZRAM preserves other swap entries in the target's `fstab` rather than vetoing the install because they exist; it also no longer rejects unrelated `PARTLABEL` swap references. Its exact selected-device identity checks, mount/holder validation, separate destructive confirmation, bounded first-1-MiB signature erase, targeted swapoff and approved generator/pressure monitor remain. The selected partition's corresponding old swap entry alone is removed.

**Base-only correction:** Root emergency-password preflight now executes only when at least one custom profile is explicitly selected, rather than changing credentials in an ordinary base-only install.

**Explicitly retained:** Selected-profile summary and consent, complete real APT transaction review and default-No approval, firmware vendor-license and omission consent, separately selected Linux 7.x prerequisite for ZRAM, local root recovery for selected profiles, exact partition identity and destructive confirmations, and genuine operation failure reporting. No OMV/Docker-specific SSH, groups, automatic-update, mirror or plugin policy is added.

**Source and runtime distinction:** The eight previously identified discretionary restriction categories are removed from this branch. No new ISO/VM test is claimed: OMV, Docker and compressed-writeback first boot still require verification. Updated the complete 99 construction guide listings/hashes to match the changed executable files.

## Official OMV signing keyring read permission — 2026-11-16

**Nearest user prompt:** Two screenshots of the Debian Installer GTK failure dialog showing `apt-get update` exit status 100 and `Permission denied (os error 13)` when `sqv` reads `/usr/share/keyrings/openmediavault-archive-keyring.gpg`.

**Observed:** The earlier diagnostics/UI change succeeded in surfacing APT's actual error. Repository metadata was fetched, but cryptographic verification could not read the dedicated OMV keyring. The error does not establish a bad repository signature or DNS failure.

**Source correction:** The installer keeps `umask 077` for private work/log files; the selected OMV handler changes the mode of only its new **public** APT keyring to `0644` immediately after dearmor, before refreshing package indexes. This fulfills Debian APT's `Signed-By` requirement that `_apt` can read the keyring. The standalone OMV 07 guide and the full CDD 07 construction source listing/hash are synchronized. The one official signed APT source and vendor-only OMV installation scope remain unchanged.

**Validation boundary:** Source inspection and synchronized listings do not prove a successful ISO build, OMV installation or first boot. A fresh disposable-VM run must verify APT signature validation succeeds, before subsequent profiles and services are considered functional.

## Native installer error reporting — 2026-11-16

**Nearest user prompt:** “make the actual errors pop in the interface if you want to get them”, following screenshots of the Debian Installer's OMV `apt-get update` failure without the underlying APT stderr.

**Observed VM evidence:** The latest installer run progressed through Debian tweaks and the approved selected ZRAM partition conversion, and reached OMV. OMV's signed key was downloaded/inspected/imported. The next `apt-get update` failed and stopped the installation; the native error dialog showed only the generic failure and unrelated prior log output, so no repository/DNS/signature cause has been established. Docker and first boot were not reached.

**Implementation:** In the shared installer `capture()`, Debian Installer's `in-target --pass-stdout` retains its native target setup and Debconf passthrough. The target program's stderr is redirected to stdout **inside the target shell**, avoiding Debian Installer's stderr-to-syslog routing. The command's original exit code and complete stdout/stderr are recorded in `my-cdd.log`; the existing GTK/text `fatal()` note now prioritizes the actual failing command, exit status, recognizable APT/dpkg error lines and last 100 command-output lines. If the command emits no captured output, it shows a short installer-syslog fallback. No additional debug UI or one-time helper is added.

**Scope:** Generic shared diagnostic path only, plus matching full source listing, validation and provenance. No change to the OMV repository, signing key, packages, SSH, automatic-update policies or ZRAM destructive conversion. A new ISO/VM test must confirm the real diagnostic is visible; this remains source-level only.

## Root-filesystem policy and one-use helper simplification — 2026-11-16

**Nearest user prompt:** “the noatime and errors=panic should be set no matter the filesystem of the root partition ... ensure_manual_updates sounds like a helper used only once. i prefer readable code that does not jump to useless one time helpers. review all code for that kind of useless helpers”, followed by “i agree” to the examined changes.

**Latest VM evidence:** The newer installer run established the local root password, completed GRUB generation, then failed during Debian tweaks' former `sshd -t` test. The installer syslog explicitly reports `Missing privilege separation directory: /run/sshd`. No ZRAM conversion occurred in that latest run. Earlier screenshots established a ZRAM GPT conversion under the old execution order; no successful complete install or first-boot writeback has been shown.

**Selected Debian tweaks:** `profile-tweaks.sh` edits only the single target root `fstab` entry and preserves `/target/etc/fstab.before-tweaks`: generic `noatime` for all root filesystem types, ext2/3/4 `errors=panic`, Btrfs `fatal_errors=panic`, and no unsupported panic option for XFS/other types. Main `/etc/ssh/sshd_config` gets `PermitRootLogin no` before `Include`/`Match`; no additional SSH drop-in, `sshd -t`, `sshd -T` or transient `/run/sshd` directory. `unattended-upgrades` policy is configured **once** if enabled, using native `20auto-upgrades` where present and one fallback override otherwise. No post-edit or later-profile rechecks.

**Function audit:** Removed single-use `ensure_manual_updates`, `verify_target_sshd`, `reviewed_upgrade`, `zram_check_utilities`, `mark_complete`, and pass-through `zram_blkid`. Inlined their operations at their callers, except for SSH runtime validation, which was removed entirely. Moved repeated `normal_suite` selection into the only profile that needs it (firmware). Retained shared `capture`, approval, transaction and target-execution interfaces; complex root recovery, firmware licensing and ZRAM selection/revalidation routines stay separate. No other feature semantics were intentionally changed.

**Verification:** Update both standalone and CDD instructions and refresh full source listings/hashes. Static source checks do not constitute an ISO build, graphical installer execution or first-boot validation.

## Approved OMV installation boundary and ZRAM consolidation — 2026-11-16

**Nearest user instruction:** “omv cdd should do nothing about ssh, that will be dealt later. the only things omv cdd is allowed to do at max are the ones done in the install script ... nothing more”; approval of the single-override ZRAM approach, followed by “go ahead”.

**Current OMV contract (supersedes earlier OMV-specific CDD policies):** The selected OMV profile must perform **only** the official OpenMediaVault 8 `install.sh` operations: validate a supported Debian/architecture/desktop environment, obtain the official signing key, configure **only the first official signed APT repository in OMV 8's manual Debian installation guide** (`http://packages.openmediavault.org/public/ synchrony main`), install OMV through an explicitly reviewed/default-No package transaction, run `omv-confdbadm populate`, and run `omv-salt deploy run hosts`. Do **not** configure SSH, root login, user groups, automatic updates, notifications, OMV-Extras, Compose, Docker, storage or other policies in this profile. The official quick installer's permissive APT downgrade/held-package flags are deliberately not used. The shared CDD installer framework's existing root-recovery preflight remains separate and unchanged. The normal OMV how-to follows the same signed-APT and initialization sequence. OMV and Docker now share the selected-only signed-APT / reviewed-transaction pattern, with independent package sets and OMV-only database/hosts initialization. No fallback-mirror list is created.

**Current ZRAM contract:** Keep the generator-supported size/compression/backing settings, selected-only `vm.swappiness=100`, existing pressure monitor and restart policy. Replace the two setup drop-ins with one `override.conf` containing the compressed-writeback pre-initialization step plus emergency-mode-on-setup-failure policy; use the short `90-zram.conf` asset. The generator cannot replace the compressed-writeback pre-initialization action. Partition selection, confirmations, bounded erase and first-boot validation gates remain unchanged.

**Verification boundary:** Source/listing synchronization, structural checks and source-file presence can be checked without booting. **No successful new ISO build, Debian Installer VM execution, compressed writeback or OMV first-boot result is established by this change.** The most recent user VM evidence still ends at the old Debian-tweaks SSH failure. See [validation](99_custom_netintst/validation_and_pending.md).

## Current synchronization contract — approved 2026-11-16

**Nearest user instruction:** “when there is a change in a section, the changes have to be reflected in the cdd as well. leave this recorded in your provenance/memory files ...” followed by approval and five screenshots from the latest generated ISO.

**Mandatory change rule:** A feature change must update **both** its ordinary Debian how-to and its matching CDD construction tutorial **and source code**, where behavior changes are applicable. Differences necessary for installer-only udebs, cdebconf or `/target` must be documented. When CDD code changes, update its **complete embedded file listings and Git blob hashes** in the same change. Check chapter numbers, internal links, dispatcher order, selection summary and VM validation together. Record the user prompt, revision date, tests, and any still-open gates. Never infer successful runtime behavior from a shell syntax check or ISO build.

**Approved new sequence:** 01 Base Debian → 02 Debian tweaks → 03 Backports → 04 Linux 7.x → 05 Firmware/microcode → 06 ZRAM → 07 OMV → 08 Docker. The CDD profile IDs remain their original stable names; only the offered/validated/executed **order** changes. CDD shared build/framework/validation tutorials are now unnumbered.

**Identity and recovery:** In the native Debian installation, leave both initial root-password fields empty to enable sudo administration for the first regular user. The ordinary [base guide](01_base_debian/README.md) sets a local root recovery password **after** confirming sudo works. The CDD instead verifies the sudo account during the late installation stage and asks for the separate recovery password **before** any selected destructive or package operations, protecting first boot.

**Automatic upgrades:** `unattended-upgrades` may be installed and enabled on some Debian 13 installations; do not assume a universal default. The standalone [tweaks guide](02_debian_tweaks/README.md) checks package presence and effective APT settings and uses Debian's own interactive reconfiguration only when needed. The CDD shared helper makes a target override **only when that package is installed and automatic installation is enabled**. Older OMV update/notification policy statements below are historical; current OMV configuration is left to the user.

**User's latest ISO evidence:** The five screenshots supplied on 2026-11-16 show a default-No ZRAM partition conversion dialog, user-approved conversion of a VM partition's first 1 MiB and GPT type/name, a reviewed `systemd-zram-generator` package transaction, and an explicit later failure: `OpenSSH configuration invalid` at `sshd -T` in Debian tweaks. They do **not** establish successful first-boot ZRAM writeback. The current CDD source now prepares a possible missing **transient** `/run/sshd` directory for target config checking, records the actual stderr when failing and runs tweaks **before** the destructive ZRAM stage. The missing-directory cause is a hypothesis, **not confirmed** by those screenshots; rerun in a disposable VM.

**Scope and static verification of this revision:** Ordinary guide numbering/content, matching CDD developer chapter paths, source order, sudo/SSH/update checks, synchronized embedded source copies, validation and provenance. Independently recomputed **all 50 embedded complete source-file Git blob hashes** against current tracked CDD files; all matched. All six relocated firmware/ZRAM assets retain their original Git content and modes. Restored the executable modes of the early/late installer entry points and verified no remaining code-file mode drift. Checked local documentation links, including the archive. No new ISO, shell syntax run, or first-boot test was executed by the assistant for this revision.

## Historical provenance (earlier revisions; superseded where noted)

**Latest construction-manual revision:** 2026-11-16 (Europe/Berlin).

**Nearest user prompt:** “i still would not be able to take one of the guides, understand what i have to do, and recreate it. they are still confusing.”

**Change in response:** The 99_custom_netintst build chapters now specify **prerequisites, exact source paths, the purpose of each file, exact text-editor commands, full file listings for every non-document file needed by the current Simple-CDD project, Git blob SHA provenance and a syntax/build/VM checklist**. The listings are byte-for-byte copies of source at commit `bf5090eb37338d9304be7e7c88fcd063b5db7b0e` (before this documentation update). The project source and normal post-install guides remain unchanged. The guide makes explicit that one optional profile needs the shared framework, whereas the current full ISO contains seven profile choices.

**Static validation performed:** All **50** complete source listings were extracted from these Markdown guides and independently recomputed as Git blob SHA-1 objects. Each matched both its displayed hash and the corresponding source blob in the pre-change repository. All changed active Markdown links resolve, Markdown source-listing fences are balanced, and all **56** tracked files under `99_custom_netintst/my-cdd/` retain their original Git blob IDs and modes. **Runtime validation remains open:** no new ISO build, installer execution, partition conversion or first-boot test was performed.

**Current update date:** 2026-11-16 (Europe/Berlin).

**Nearest user prompt:** “you're messing everything up. the netinst sections should describe how to build the custom script for the section. i don't know what you did but it's useless”.

**Correction:** PR #15 and preceding documentation revisions treated the `99_custom_netintst` chapters as a walk-through of operating the **finished installer**, which was not what the user requested. This revision reorients `99_custom_netintst` into a **developer-facing construction guide**: which scripts, manifests, sources, Debconf templates and build settings to create or modify; the actual implementation mechanics; annotated code excerpts; hook integration; and source/VM validation.

**Source basis:** `dcf1007/home_server` at the current `main` before this revision, including `99_custom_netintst/my-cdd/build.sh`, `simple-cdd.conf`, `profiles/default.preseed`, all seven `profile-*.sh` modules, `zram-selection.sh`, `profile-confirm.sh`, `run-selected.sh`, `profile-common.sh`, `15my-cdd-status`, the package manifests, license handling and archived historical plans. The actual Simple-CDD project files remain **unchanged**; this change edits only its documentation.

**Structure:** [ordinary installed-Debian guides 01–08](README.md) remain end-user operational procedures. [custom netinst](99_custom_netintst/README.md) is now a source-construction manual with [00 — common profile wiring](99_custom_netintst/profile_construction.md), [01 — ISO build](99_custom_netintst/build_project.md), [05 — installer framework](99_custom_netintst/installer_framework.md), each feature's construction chapter and [08 — developer validation](99_custom_netintst/validation_and_pending.md).

The earlier standalone OMV helper was removed. The current [OMV how-to](07_openmediavault/README.md) and installer profile both use direct signed APT and OMV's two official initialization commands; the former inline JSON update/notification policy code was removed from the current CDD profile.

**Accuracy boundary:** annotated snippets show portions of the currently tracked implementation; snippets explicitly labelled illustrative or excerpts are **not** complete scripts to execute independently. The linked existing code is the complete implementation being explained—not a substitute for these instructions. This revision does **not** claim a new ISO build, runtime installer test, physical disk operation or first-boot validation. The required tests remain in the [developer validation guide](99_custom_netintst/validation_and_pending.md).
