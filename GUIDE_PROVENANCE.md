# Guide provenance and scope

**Current update date:** 2026-11-16 (Europe/Berlin).

**Nearest user prompt:** “you're messing everything up. the netinst sections should describe how to build the custom script for the section. i don't know what you did but it's useless”.

**Correction:** PR #15 and preceding documentation revisions treated the `99_custom_netintst` chapters as a walk-through of operating the **finished installer**, which was not what the user requested. This revision reorients `99_custom_netintst` into a **developer-facing construction guide**: which scripts, manifests, sources, Debconf templates and build settings to create or modify; the actual implementation mechanics; annotated code excerpts; hook integration; and source/VM validation.

**Source basis:** `dcf1007/home_server` at the current `main` before this revision, including `99_custom_netintst/my-cdd/build.sh`, `simple-cdd.conf`, `profiles/default.preseed`, all seven `profile-*.sh` modules, `zram-selection.sh`, `profile-confirm.sh`, `run-selected.sh`, `profile-common.sh`, `15my-cdd-status`, the package manifests, license handling and archived historical plans. The actual Simple-CDD project files remain **unchanged**; this change edits only its documentation.

**Structure:** [ordinary installed-Debian guides 01–08](README.md) remain end-user operational procedures. [custom netinst](99_custom_netintst/README.md) is now a source-construction manual with [00 — common profile wiring](99_custom_netintst/00_profile_construction.md), [01 — ISO build](99_custom_netintst/01_custom_cdd_preparation.md), [05 — installer framework](99_custom_netintst/05_base_installation.md), each feature's construction chapter and [08 — developer validation](99_custom_netintst/08_validation_and_pending.md).

The earlier standalone OMV helper has been removed: the normal [OMV how-to](07_openmediavault/README.md) uses manual UI/configuration steps. The **installer** OMV shell module still contains its existing inline JSON manipulation for the unavailable-preboot-web-UI case; no external Python helper is installed on the target.

**Accuracy boundary:** annotated snippets show portions of the currently tracked implementation; snippets explicitly labelled illustrative or excerpts are **not** complete scripts to execute independently. The linked existing code is the complete implementation being explained—not a substitute for these instructions. This revision does **not** claim a new ISO build, runtime installer test, physical disk operation or first-boot validation. The required tests remain in the [developer validation guide](99_custom_netintst/08_validation_and_pending.md).
