# my-cdd — customized Debian 13 Simple-CDD project

**Status:** source-tree scaffold only, created 2026-11-14. The profiles, custom installer components, build entry point and ISO are **not yet implemented or tested**.

This directory will contain the build inputs for the [custom Debian 13 installer](../readme.md). It is deliberately named **`my-cdd`**, not `simple-cdd`. It will still use the Debian `simple-cdd` package and `build-simple-cdd` tool.

## Configuration

- [`profile_defaults.conf`](profile_defaults.conf) — canonical editable suggestions for native Debian Installer screens; moved here verbatim from `../profile_defaults.conf` (which is removed).
- [`profile_defaults.conf.example`](profile_defaults.conf.example) — reference companion; moved here verbatim and **not** a competing configuration source.

**Important:** `profile_defaults.conf` is not a Debian Installer preseed or Simple-CDD build configuration. The needed `simple-cdd.conf` and executable profile files will be authored and validated in the implementation phase. The defaults must remain editable in the native installer; no passwords, hard-coded OS installation disks or automatically selected profiles are stored in them.

## Planned folders

- [`profiles/`](profiles/) — Simple-CDD profile descriptions, package selections and per-profile integration.
- [`scripts/`](scripts/) — explicitly reviewed helper scripts for custom optional-profile behavior.
- [`installer/`](installer/) — installer-stage integration and Debconf templates, including the optional-profile summary gate.

All seven optional profiles remain **unchecked by default**. Never silently change a documented design decision. Review the [preparation guide](../01_custom_cdd_preparation.md) and [validation checklist](../08_validation_and_pending.md) before treating any generated scripts as installable.
