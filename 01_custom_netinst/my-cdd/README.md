# my-cdd — Debian 13 (Trixie) amd64 custom Simple-CDD sources

**Stage:** selected-profile installation routines and Simple-CDD hooks are now written in source; **not** a built or boot-tested installer. Started 2026-11-14 following the user's instruction to proceed with generating build files in `my-cdd/`.

## Entry points

- [`simple-cdd.conf`](simple-cdd.conf) — actual Trixie/amd64 Simple-CDD 0.6.9 build variables; seven optional profiles, no auto-selection; official Debian mirror components.
- [`build.sh`](build.sh) — minimal wrapper around standard `build-simple-cdd --conf ./simple-cdd.conf --dist trixie`. A source build is **not** proof of installer correctness.
- [`profiles/`](profiles/) — native Simple-CDD profile descriptions, empty optional auto-package queues, and seven postinst **completion verifiers**. The actual selected-profile actions run in Debian Installer's normal late-command stage.
- [`installer/`](installer/) — approved early Debconf selection/confirmation, plus [`run-selected.sh`](installer/run-selected.sh) and [`profile-actions.sh`](installer/profile-actions.sh), invoked from the normal `preseed/late_command` with the agreed ordered operations and individual confirmations. **Actual GUI/installer behavior is untested.**
- [`scripts/`](scripts/) — approved firmware package inventory, selected-only Backports and ZRAM configuration inputs, and untested ZRAM source assets.
- [`profile_defaults.conf`](profile_defaults.conf) — original canonical, editable native Debian Installer suggestions, moved here byte-for-byte from the former root-level file.
- [`profile_defaults.conf.example`](profile_defaults.conf.example) — original example/reference, not another source of truth.
- [`SOURCE_MANIFEST.md`](SOURCE_MANIFEST.md) — creation provenance, source categories and current blocked implementation status.

## Important engineering boundaries

**Do not run an installable test image on a real OS installation disk from this tree.** Building a reliable final ISO still requires **runtime verification** of the early summary, native late-command execution, package transactions and individual approvals, safe ZRAM conversion, OMV 8 installation/network behavior, Docker daemon suppression, log export and USB boot menu. The source routines are written but must not be represented as tested or guaranteed to work.

The minimal default preseed only bootstraps Simple-CDD and deliberately leaves **normal Debian Installer prompts native** (hostname, language/locale, keyboard, time, accounts, selected OS installation disk and partitions, networking, tasksel). Canonical default suggestions have not yet been mapped to real installer Debconf questions in a tested manner. Neither the planned kernel 7.x nor its ZRAM features have been shown to be available at image-build time.

In the installed system, **both microcode packages** and broad firmware would be evaluated when Extended device support is selected. With Backports selected, targeted Backports package versions take precedence under global priority **100**; incompatible/missing firmware requires an explicitly approved individual omission, and Stable fallbacks are listed in the final APT transaction.

No ISO image, USB medium or functional test has been produced. Follow the [preparation guide](../01_custom_cdd_preparation.md), [validation checklist](../08_validation_and_pending.md) and [implementation gates](installer/IMPLEMENTATION_GATES.md). No source ISO/output ISO hash or USB read-back/integrity-only test has been introduced.

## ZRAM backing selection (source implementation, not installer-validated)

The selected ZRAM profile now reads the installed target's `/etc/fstab` to
automatically identify its single assigned, eligible GPT swap partition,
whether newly created or reused from an older installation. If none is
uniquely assigned, a native GTK/text Debconf single-select prompt lists
verified swap and prior raw `zram-writeback` candidates with a safe
stop-without-changes default. Each selection still needs separate destructive
confirmation, plus separately approved memory-checked targeted `swapoff`
if Debian Installer has activated it. No partition is selected by its order
or by sharing a disk with the new OS.

`installer/zram-selection.sh` implements discovery, while
`installer/profile-actions.sh` performs confirmed conversion. The original
`scripts/zram-generator.conf.template` remains a source template; the
selected partition's PARTUUID is instantiated into the target's
`/etc/systemd/zram-generator.conf`. Missing backing stops safely; returning
to the earlier partitioner is **not implemented** in the late-stage hook.

**Do not assume this source is ready for real-disk installation.** Native
GTK/text dynamic choices, target fstab timing, block utilities, emergency
boot dependencies and complete installer runtime behavior remain untested.
