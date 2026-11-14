# my-cdd source manifest and provenance

**Initial creation date:** 2026-11-14 (Europe/Berlin).  
**Latest revision:** 2026-11-14 (Europe/Berlin).  
**Nearest user prompt:** “yes”, authorizing cleanup of the unnecessary mock tests,
their supporting infrastructure, the extra build modes/checks and unused helper
scripts, while retaining the seven required Simple-CDD profiles and approved
early preseed confirmation.  
**Repository location:** `dcf1007/home_server/01_custom_netinst/my-cdd/`.

## Source provenance

- `profile_defaults.conf` and `profile_defaults.conf.example` were moved
  **unchanged** from the parent planning directory under the user's earlier
  instruction to name the project `my-cdd`.
- `simple-cdd.conf`, `profiles/` and the minimal `build.sh` implement the
  [documented installer project](../01_custom_cdd_preparation.md), based on
  Debian Simple-CDD's native profile structure. Their source was initially
  generated after the user said “proceed”.
- `installer/profile-confirm.sh`, `profile-confirm.templates` and
  `ordered-selection.sh` support **user-approved option A**, a standard
  `preseed/early_command` hook before the unchanged upstream
  `simple-cdd-profiles` udeb. The user selected option A explicitly.
- The four ZRAM generator/monitor/systemd assets are **verbatim extractions**
  from the [approved original design](../03_zram_writeback.md#original-design--complete-source).
  They are not automatically deployed.
- `scripts/firmware-candidates.txt` follows the
  [Extended device support inventory](../10_extended_device_support.md).
  The signed Backports and ZRAM swappiness templates are only source material
  for their independently selected profiles.
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

## Actual implementation state

**Not a working ISO.** The seven optional profiles are described, but their
`.packages` files do not auto-queue packages and their `.postinst` scripts
are fail-closed placeholders. The early profile confirmation exists as
source but has not run inside Debian Installer. Actual target package
installation, ZRAM partition conversion, OMV/Docker service management,
boot-menu changes and first-boot validation remain incomplete.

There has been no ISO build, USB creation, package-install run, partition
modification or extra test execution in this cleanup.

## Current tracked files (46)

- `.gitignore`
- `README.md`
- `SOURCE_MANIFEST.md`
- `build.sh`
- `installer/IMPLEMENTATION_GATES.md`
- `installer/README.md`
- `installer/ordered-selection.sh`
- `installer/profile-confirm.sh`
- `installer/profile-confirm.templates`
- `profile_defaults.conf`
- `profile_defaults.conf.example`
- `profiles/README.md`
- `profiles/backports.description`
- `profiles/backports.packages`
- `profiles/backports.postinst`
- `profiles/debian-tweaks.description`
- `profiles/debian-tweaks.packages`
- `profiles/debian-tweaks.postinst`
- `profiles/default.description`
- `profiles/default.packages`
- `profiles/default.preseed`
- `profiles/default.udebs`
- `profiles/docker.description`
- `profiles/docker.packages`
- `profiles/docker.postinst`
- `profiles/ensure-7x-kernel.description`
- `profiles/ensure-7x-kernel.packages`
- `profiles/ensure-7x-kernel.postinst`
- `profiles/extended-device-support.description`
- `profiles/extended-device-support.packages`
- `profiles/extended-device-support.postinst`
- `profiles/openmediavault.description`
- `profiles/openmediavault.packages`
- `profiles/openmediavault.postinst`
- `profiles/zram-writeback.description`
- `profiles/zram-writeback.packages`
- `profiles/zram-writeback.postinst`
- `scripts/10-compressed-writeback.conf`
- `scripts/90-zram-swappiness.conf`
- `scripts/README.md`
- `scripts/debian-backports.sources`
- `scripts/firmware-candidates.txt`
- `scripts/zram-generator.conf.template`
- `scripts/zram-pressure.service`
- `scripts/zram-pressure.sh`
- `simple-cdd.conf`

