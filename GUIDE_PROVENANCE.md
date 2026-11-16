# Guide provenance and scope

## Current synchronization contract — approved 2026-11-16

**Nearest user instruction:** “when there is a change in a section, the changes have to be reflected in the cdd as well. leave this recorded in your provenance/memory files ...” followed by approval and five screenshots from the latest generated ISO.

**Mandatory change rule:** A feature change must update **both** its ordinary Debian how-to and its matching CDD construction tutorial **and source code**, where behavior changes are applicable. Differences necessary for installer-only udebs, cdebconf or `/target` must be documented. When CDD code changes, update its **complete embedded file listings and Git blob hashes** in the same change. Check chapter numbers, internal links, dispatcher order, selection summary and VM validation together. Record the user prompt, revision date, tests, and any still-open gates. Never infer successful runtime behavior from a shell syntax check or ISO build.

**Approved new sequence:** 01 Base Debian → 02 Debian tweaks → 03 Backports → 04 Linux 7.x → 05 Firmware/microcode → 06 ZRAM → 07 OMV → 08 Docker. The CDD profile IDs remain their original stable names; only the offered/validated/executed **order** changes. CDD shared build/framework/validation tutorials are now unnumbered.

**Identity and recovery:** In the native Debian installation, leave both initial root-password fields empty to enable sudo administration for the first regular user. The ordinary [base guide](01_base_debian/README.md) sets a local root recovery password **after** confirming sudo works. The CDD instead verifies the sudo account during the late installation stage and asks for the separate recovery password **before** any selected destructive or package operations, protecting first boot.

**Automatic upgrades:** `unattended-upgrades` may be installed and enabled on some Debian 13 installations; do not assume a universal default. The standalone [tweaks guide](02_debian_tweaks/README.md) checks package presence and effective APT settings and uses Debian's own interactive reconfiguration only when needed. The CDD shared helper makes a target override **only when that package is installed and automatic installation is enabled**. OMV's independent scheduled-update and notification rules remain documented.

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

The earlier standalone OMV helper has been removed: the normal [OMV how-to](07_openmediavault/README.md) uses manual UI/configuration steps. The **installer** OMV shell module still contains its existing inline JSON manipulation for the unavailable-preboot-web-UI case; no external Python helper is installed on the target.

**Accuracy boundary:** annotated snippets show portions of the currently tracked implementation; snippets explicitly labelled illustrative or excerpts are **not** complete scripts to execute independently. The linked existing code is the complete implementation being explained—not a substitute for these instructions. This revision does **not** claim a new ISO build, runtime installer test, physical disk operation or first-boot validation. The required tests remain in the [developer validation guide](99_custom_netintst/validation_and_pending.md).
