# Native Debian Installer integration (source only)

The seven profiles are presented by Simple-CDD's standard `simple-cdd/profiles` Debconf multiselect; none is automatically selected. We must add one custom **summary confirmation** before profile operation, not replace Debian's native installer GUI or its normal keyboard/time/account/network/partman/retry dialogs.

- [`profile-confirm.templates`](profile-confirm.templates) — proposed Debconf note/boolean templates, with **seven independently substituted status lines**, a default-No confirmation and a dependency-error note.
- [`profile-confirm.sh`](profile-confirm.sh) — proposed early call **after** reading selected profiles, **before** loading profile preseeds or queuing udebs/packages. **Not yet installed/integrated**.
- [`ordered-selection.sh`](ordered-selection.sh) — read-only, deterministic ordering and dependency parser; not a package installer.
- [`test-ordered-selection.sh`](test-ordered-selection.sh) — standalone source-level checks.
- [`IMPLEMENTATION_GATES.md`](IMPLEMENTATION_GATES.md) — exact release blockers and validated test/build sequence.

**Why an early integration is needed:** [Simple-CDD 0.6.9's udeb postinst](https://sources.debian.org/src/simple-cdd/0.6.9/debian/simple-cdd-profiles.postinst) reads `simple-cdd/profiles` then loads preseeds and queues packages in the same script. Its [finish-install hook](https://sources.debian.org/src/simple-cdd/0.6.9/debian/14simple-cdd) later runs executable selected `*.postinst` **inside the target**. Thus an ordinary late profile script cannot replace an early GUI gate, nor guarantee execution order from UI selection alone.

**Not yet done:** trusted custom udeb integration, Debconf template loading, safe back navigation, installed-target package runner, diagnostic persistence/export, and boot menu edits. Build/first-boot tests must precede any production claim. The current optional profile `*.postinst` deliberately fail closed.
