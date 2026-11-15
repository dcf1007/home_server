# Native Debian Installer integration (source only)

The seven profiles are presented by Simple-CDD's standard `simple-cdd/profiles` Debconf multiselect; none is automatically selected. We must add one custom **summary confirmation** before profile operation, not replace Debian's native installer GUI or its normal keyboard/time/account/network/partman/retry dialogs.

- [`profile-confirm.templates`](profile-confirm.templates) — proposed Debconf note/boolean templates, with **seven independently substituted status lines**, a default-No confirmation and a dependency-error note.
- [`profile-confirm.sh`](profile-confirm.sh) — **wired into [`profiles/default.preseed`](../profiles/default.preseed)** through the approved `preseed/early_command`, before `anna-install simple-cdd-profiles`. It explicitly loads Simple-CDD's generated multiselect and the seven-line confirmation, then sets the original selection's Debconf `seen` flag on approval. It is **not yet tested in a running installer**.
- [`ordered-selection.sh`](ordered-selection.sh) — read-only, deterministic ordering and dependency parser; not a package installer.
- [`run-selected.sh`](run-selected.sh) — existing Debian Installer `preseed/late_command` integration: reads the approved selection, executes only those profiles in the agreed order, displays review and default-No transaction prompts through native Debconf, and logs to the installed target.
- [`profile-actions.sh`](profile-actions.sh) — approved per-profile commands (Backports, 7.x kernel, firmware, ZRAM, tweaks, OMV 8, Docker); no user-space GUI framework or upstream installer patch.
- [`IMPLEMENTATION_GATES.md`](IMPLEMENTATION_GATES.md) — remaining runtime and boot validation requirements.

**Why an early integration is needed:** [Simple-CDD 0.6.9's udeb postinst](https://sources.debian.org/src/simple-cdd/0.6.9/debian/simple-cdd-profiles.postinst) reads `simple-cdd/profiles` then loads preseeds and queues packages in the same script. Its [finish-install hook](https://sources.debian.org/src/simple-cdd/0.6.9/debian/14simple-cdd) later runs executable selected `*.postinst` **inside the target**. Thus an ordinary late profile script cannot replace an early GUI gate, nor guarantee execution order from UI selection alone.

**Not yet verified:** execution of the early hook in Debian 13 GTK and text frontends; generated template path, `debconf-loadtemplate` availability, Debconf `seen` semantics avoiding duplicate profile prompts, cancellation/Back navigation, zero-selection behavior and successful transfer to the unmodified udeb. No custom udeb rebuild has been performed. The source now includes the ordered package runner, native review questions, target-root log recording and fail-closed per-profile completion verification. **None has been exercised in real Debian Installer GTK or text mode**. USB boot menu edits, exact repository/daemon compatibility, safe ZRAM partition conversion and first-boot behavior still require validation.

ZRAM backing discovery lives in [`zram-selection.sh`](zram-selection.sh).
It uses an exact unique swap assignment in the installed target's `fstab`
for automatic selection (including reused swap). When that is unavailable,
Debconf's native `Type: select` and `Choices-C` present a safe-default
manual picker in both GTK and text frontends. It checks GPT PARTUUID, type,
signature, mounts, active swap and block holders before destructive actions;
conversion still requires separate default-No confirmation and a targeted
memory-checked swapoff if active. Runtime frontend and partition behavior
remain untested.
