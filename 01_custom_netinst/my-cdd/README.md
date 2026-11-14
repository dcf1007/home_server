# my-cdd — Debian 13 (Trixie) amd64 custom Simple-CDD sources

**Stage:** implementation source tree, **not** a complete or boot-tested installer. Started 2026-11-14 following the user's instruction to proceed with generating build files in `my-cdd/`.

## Entry points

- [`simple-cdd.conf`](simple-cdd.conf) — actual Trixie/amd64 Simple-CDD 0.6.9 build variables; seven optional profiles, no auto-selection; official Debian mirror components.
- [`build.sh`](build.sh) — `sh build.sh --check` for safe static source checks. `--test-build` and `--release` are **blocked** until their respective documented integration and test milestones are completed.
- [`profiles/`](profiles/) — default preseed/udebs/base packages and seven selectable profile descriptions plus deliberate fail-closed postinst sources.
- [`installer/`](installer/) — early GTK/text Debconf confirmation prototypes, deterministic selection handling, and mandatory implementation gates.
- [`scripts/`](scripts/) — read-only APT/ZRAM inspections, firmware inventory, and **untested source-extracted ZRAM assets**.
- [`profile_defaults.conf`](profile_defaults.conf) — original canonical, editable native Debian Installer suggestions, moved here byte-for-byte from the former root-level file.
- [`profile_defaults.conf.example`](profile_defaults.conf.example) — original example/reference, not another source of truth.
- [`SOURCE_MANIFEST.md`](SOURCE_MANIFEST.md) — creation provenance, source categories and current blocked implementation status.

## Important engineering boundaries

**Do not run an installable test image on a real OS installation disk from this tree.** Building a coherent final ISO still requires a reviewed early Simple-CDD profile gate, target-side ordered profile execution, interactive transaction approvals, safe ZRAM conversion, OMV 8 repository/service verification, Docker daemon suppression, logs/export and bootloader menu integration. The source files intentionally fail closed rather than silently skip work.

The minimal default preseed only bootstraps Simple-CDD and deliberately leaves **normal Debian Installer prompts native** (hostname, language/locale, keyboard, time, accounts, selected OS installation disk and partitions, networking, tasksel). Canonical default suggestions have not yet been mapped to real installer Debconf questions in a tested manner. Neither the planned kernel 7.x nor its ZRAM features have been shown to be available at image-build time.

In the installed system, **both microcode packages** and broad firmware would be evaluated when Extended device support is selected. With Backports selected, targeted Backports package versions take precedence under global priority **100**; incompatible/missing firmware requires an explicitly approved individual omission, and Stable fallbacks are listed in the final APT transaction.

No ISO image, USB medium or functional test has been produced. Follow the [preparation guide](../01_custom_cdd_preparation.md), [validation checklist](../08_validation_and_pending.md) and [implementation gates](installer/IMPLEMENTATION_GATES.md). No source ISO/output ISO hash or USB read-back/integrity-only test has been introduced.
