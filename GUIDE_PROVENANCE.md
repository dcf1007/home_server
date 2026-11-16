# Guide provenance and scope

**Latest construction-manual revision:** 2026-11-16 (Europe/Berlin).

**Nearest user prompt:** “i still would not be able to take one of the guides, understand what i have to do, and recreate it. they are still confusing.”

**Change in response:** The 99_custom_netintst build chapters now specify **prerequisites, exact source paths, the purpose of each file, exact text-editor commands, full file listings for every non-document file needed by the current Simple-CDD project, Git blob SHA provenance and a syntax/build/VM checklist**. The listings are byte-for-byte copies of source at commit `bf5090eb37338d9304be7e7c88fcd063b5db7b0e` (before this documentation update). The project source and normal post-install guides remain unchanged. The guide makes explicit that one optional profile needs the shared framework, whereas the current full ISO contains seven profile choices.

**Static validation performed:** All **50** complete source listings were extracted from these Markdown guides and independently recomputed as Git blob SHA-1 objects. Each matched both its displayed hash and the corresponding source blob in the pre-change repository. All changed active Markdown links resolve, Markdown source-listing fences are balanced, and all **56** tracked files under `99_custom_netintst/my-cdd/` retain their original Git blob IDs and modes. **Runtime validation remains open:** no new ISO build, installer execution, partition conversion or first-boot test was performed.

**Current update date:** 2026-11-16 (Europe/Berlin).

**Nearest user prompt:** “you're messing everything up. the netinst sections should describe how to build the custom script for the section. i don't know what you did but it's useless”.

**Correction:** PR #15 and preceding documentation revisions treated the `99_custom_netintst` chapters as a walk-through of operating the **finished installer**, which was not what the user requested. This revision reorients `99_custom_netintst` into a **developer-facing construction guide**: which scripts, manifests, sources, Debconf templates and build settings to create or modify; the actual implementation mechanics; annotated code excerpts; hook integration; and source/VM validation.

**Source basis:** `dcf1007/home_server` at the current `main` before this revision, including `99_custom_netintst/my-cdd/build.sh`, `simple-cdd.conf`, `profiles/default.preseed`, all seven `profile-*.sh` modules, `zram-selection.sh`, `profile-confirm.sh`, `run-selected.sh`, `profile-common.sh`, `15my-cdd-status`, the package manifests, license handling and archived historical plans. The actual Simple-CDD project files remain **unchanged**; this change edits only its documentation.

**Structure:** [ordinary installed-Debian guides 01–08](README.md) remain end-user operational procedures. [custom netinst](99_custom_netintst/README.md) is now a source-construction manual with [00 — common profile wiring](99_custom_netintst/00_profile_construction.md), [01 — ISO build](99_custom_netintst/01_custom_cdd_preparation.md), [05 — installer framework](99_custom_netintst/05_base_installation.md), each feature's construction chapter and [08 — developer validation](99_custom_netintst/08_validation_and_pending.md).

The earlier standalone OMV helper has been removed: the normal [OMV how-to](07_openmediavault/README.md) uses manual UI/configuration steps. The **installer** OMV shell module still contains its existing inline JSON manipulation for the unavailable-preboot-web-UI case; no external Python helper is installed on the target.

**Accuracy boundary:** annotated snippets show portions of the currently tracked implementation; snippets explicitly labelled illustrative or excerpts are **not** complete scripts to execute independently. The linked existing code is the complete implementation being explained—not a substitute for these instructions. This revision does **not** claim a new ISO build, runtime installer test, physical disk operation or first-boot validation. The required tests remain in the [developer validation guide](99_custom_netintst/08_validation_and_pending.md).
