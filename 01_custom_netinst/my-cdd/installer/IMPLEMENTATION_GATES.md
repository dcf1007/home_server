# Mandatory integration gates — production build intentionally blocked

**Status (2026-11-14): all gates open / untested.** Do not create any milestone markers as shortcuts. The entry point has three modes: `sh build.sh --check` validates source structure; `sh build.sh --test-build` requires `INTEGRATION_IMPLEMENTED` after all mandatory installer hooks and scripts exist; `sh build.sh --release` additionally requires `INTEGRATION_VALIDATED` and `FIRST_BOOT_TESTED` after actual functional tests. **First-boot tests follow a test image; they do not precede the first image build.** Markers must correspond to concrete evidence recorded in this repository. Until then, a test/release build fails closed.

## 1. Early selected-profile confirmation

Upstream **Simple-CDD 0.6.9** (`debian/simple-cdd-profiles.postinst`) calls `db_input high simple-cdd/profiles`, `db_go`, then immediately processes `*.preseed`, `*.udebs` and `*.packages`. A late `profiles/*.postinst` or `preseed/late_command` cannot enforce approval before queuing.

Provide a reviewed integration (custom udeb or appropriately patched profile-selection flow) that:
- reads the exact seven-profile selection after the Debconf multiselect;
- displays the selected/unchecked state and dependencies in GTK and text;
- obtains an explicit **default-No** approval before ANY selected-profile actions;
- allows backing out / changing the selection where the frontend permits;
- blocks when ZRAM was selected but Ensure 7.x was not separately selected;
- does not silently change any profile selection.

See [profile-confirm.templates](profile-confirm.templates) and [profile-confirm.sh](profile-confirm.sh). They are **source components, not yet connected to any executable early installer stage**. The revised template displays seven selected/unselected states through separate Debconf substitutions, so no newline is passed through the line-oriented Debconf protocol. Declining confirmation returns to the original profile question, without altering the selection; any error or Back/cancel must stop profile loading.

**Integration method not authorized/selected yet:** investigate whether the existing `preseed/early_command` can safely load the template and ask the already-available `simple-cdd/profiles` question **before** `anna-install simple-cdd-profiles`, so the unmodified upstream udeb can consume the approved answer without showing a duplicate prompt; otherwise a revised udeb may be required. Do not silently adopt either method. Confirm the exact supported ordering, cdebconf `seen` flag and no-package-queue-before-approval behavior in a disposable installer.

## 2. Preserve native Debian Installer behavior

Keep ordinary keyboard, locale/time, account/password, network/mirror, partman, tasksel, package-retry and reboot screens native. Map `../profile_defaults.conf` into editable defaults only after validating the Trixie Debconf IDs and whether the screen remains shown. The minimal `profiles/default.preseed` deliberately has no other answers. Do not copy upstream old default preseed over it.

## 3. Profile transaction execution

Simple-CDD 0.6.9 runs each executable `*.postinst` **in-target**, in the order returned by the Debconf selection, not necessarily the design order. Replace the current fail-closed .postinst sources with a verified **single ordered dispatcher**:
Backports → Ensure 7.x → Extended device support → ZRAM → Debian tweaks → OMV 8 → Docker.

The current `*.packages` files for optional profiles intentionally **queue no packages**: automatic queueing would bypass required simulation/approval and, for Docker or ZRAM, violate service and conversion timing.

Implement and test the exact package/repository changes, interactive approval and omission UI, safe log persistence, ZRAM partition conversion, Docker service suppression and OMV SSH/update behavior. All critical failures must fail-stop, without rollback or skipped profiles.

## 4. Boot and functional release tests

Confirm generated USB boots UEFI **and** legacy BIOS, with **Graphical install** highlighted and an indefinite manual Enter wait; text and rescue remain available. The BOOT_TIMEOUT config alone is not proof of this. Confirm target UEFI/GPT and normal Debian manual partman.

Test profile combinations, conditional Backports-first kernel/firmware, first boot, 7.x headers, generator sysfs features, ZRAM writeback/emergency path, OMV 8 and Docker inactive state. Test diagnostic display, full-log copies/permissions and export. Follow [the validation checklist](../../08_validation_and_pending.md).

**Explicitly excluded by user choice:** source ISO/file hashes, output ISO hashes, USB read-back comparison and media-integrity-only tests. Functional tests and signed APT metadata verification are still required.

## Upstream evidence

- [Simple-CDD 0.6.9 postinst control](https://sources.debian.org/src/simple-cdd/0.6.9/debian/simple-cdd-profiles.postinst)
- [Simple-CDD 0.6.9 finish-install runner](https://sources.debian.org/src/simple-cdd/0.6.9/debian/14simple-cdd)
- [Simple-CDD default preseed](https://sources.debian.org/src/simple-cdd/0.6.9/profiles/default.preseed)
- [Simple-CDD build variables](https://sources.debian.org/src/simple-cdd/0.6.9/simple_cdd/variables.py)
