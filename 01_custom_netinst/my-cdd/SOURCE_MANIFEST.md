# my-cdd source file manifest and provenance

**Created:** 2026-11-14 (Europe/Berlin).  
**Nearest user prompt for this revision:** “A” — explicit approval of the **early preseed confirmation hook**, without patching the upstream Simple-CDD profile-selector udeb. The previous source creation was prompted by “proceed”, and subsequent implementation was requested with “continue the implementation. remember not to decide anything without asking.”
**Last revised:** 2026-11-14 (Europe/Berlin).  
**Repository:** `dcf1007/home_server`, `01_custom_netinst/my-cdd/`.

## Provenance categories

- **Moved unchanged from the parent planning directory:** `profile_defaults.conf` and `profile_defaults.conf.example`. The exact original contents were verified and the root-level duplicates deleted in the preceding turn.
- **Generated Simple-CDD source structure:** `simple-cdd.conf`, `build.sh`, and `profiles/{default,backports,ensure-7x-kernel,extended-device-support,zram-writeback,debian-tweaks,openmediavault,docker}.*`, grounded in [the 01 preparation guide](../01_custom_cdd_preparation.md) and Debian [Simple-CDD 0.6.9 source](https://sources.debian.org/src/simple-cdd/0.6.9/).
- **Extracted unchanged from approved original ZRAM source blocks:** `scripts/zram-pressure.sh`, `scripts/zram-generator.conf.template`, `scripts/10-compressed-writeback.conf` and `scripts/zram-pressure.service`, sourced from [03 ZRAM writeback](../03_zram_writeback.md#original-design--complete-source).
- **Generated non-destructive inspection/test helpers:** `scripts/apt-simulate.sh`, `scripts/inspect-zram-backing.sh`, `scripts/verify-source-layout.sh`, and `installer/ordered-selection.sh`, `installer/test-ordered-selection.sh`, etc.
- **Generated design/validation documents:** all other `README.md`, `IMPLEMENTATION_GATES.md`, Debconf templates, and metadata entries.
- **Generated in the current continuation (source-only, no installer actions):** `scripts/plan-firmware.py` (strict read-only APT policy + joint simulation), `tests/test_plan_firmware.py` and `tests/README.md` (mocked offline tests), `scripts/debian-backports.sources` (selected-only signed repository template), `scripts/90-zram-swappiness.conf` (ZRAM-selected-only setting). The `installer/profile-confirm.sh` and `installer/profile-confirm.templates` were revised to use one status field per optional profile and explicit reselection on No; build/source checks and related documentation were updated. These changes implement **existing approved policy only**.
- **Approved early integration method:** A — modify only the existing `profiles/default.preseed` to invoke `installer/profile-confirm.sh` before `anna-install simple-cdd-profiles`. The hook loads both Debconf template sets, collects manual selection, presents seven status lines and default-No confirmation, and marks the same selection question as seen on approval. The **upstream udeb is not modified**, and no profile is auto-selected. This source-level integration was **not tested in a running installer**; a failure requires asking the user before changing methods.
- **User concern on offline tests:** The user objected to unrequested mock firmware/offline tests. No test files were added, removed or executed in response to the latest “A”, which approved the confirmation method only. Their disposition remains unapproved and should not be silently decided.

## Current implementation status

**Not production ready.** The optional profile `*.packages` files deliberately queue nothing. The optional `*.postinst` files explicitly stop until an independently reviewed ordered executor and early installer gate are implemented. The user-approved but not yet validated ZRAM source code is not deployed by any profile. `sh build.sh --test-build` and `--release` remain blocked by explicit integration/test gates. No ISO/USB has been built; no first boot, actual APT transaction, GTK/text integration or destructive ZRAM conversion has been tested.

No installer media/source-image hashes or USB read-back checks have been added. Package repository signing checks are independent and remain mandatory.

## Tracked files as of this revision (53)

- `.gitignore`
- `README.md`
- `SOURCE_MANIFEST.md`
- `build.sh`
- `installer/IMPLEMENTATION_GATES.md`
- `installer/README.md`
- `installer/ordered-selection.sh`
- `installer/profile-confirm.sh`
- `installer/profile-confirm.templates`
- `installer/test-ordered-selection.sh`
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
- `scripts/apt-simulate.sh`
- `scripts/debian-backports.sources`
- `scripts/firmware-candidates.txt`
- `scripts/inspect-zram-backing.sh`
- `scripts/plan-firmware.py`
- `scripts/verify-source-layout.sh`
- `scripts/zram-generator.conf.template`
- `scripts/zram-pressure.service`
- `scripts/zram-pressure.sh`
- `simple-cdd.conf`
- `tests/README.md`
- `tests/test_plan_firmware.py`

**Note:** This manifest lists the tracked project sources, not completed installer features or an artifact manifest for an ISO. Newly added future files should be appended when the project advances.
