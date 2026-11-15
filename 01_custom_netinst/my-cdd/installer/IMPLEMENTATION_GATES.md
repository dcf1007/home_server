# Implementation requirements still outstanding

**Current source revision (2026-11-15):** Optional operations were reorganized into selected-only modules, with no unselected base account/SSH/update overrides. `profiles/default.packages` now falls back to CDD's upstream file. The source was not revalidated in a live installer, so all runtime gates below remain open.

**Status (2026-11-15): source-level selected-profile executor and completion checks added, not tested in a live installer.** The minimal `build.sh` invokes upstream `build-simple-cdd`. It has no fabricated offline test harness or artificial release flags. The seven selected-profile postinst files now verify actual installer-stage completion records rather than blindly succeeding. **A successful ISO build is not a functional validation.**

## 1. Early selected-profile confirmation

Upstream **Simple-CDD 0.6.9** (`debian/simple-cdd-profiles.postinst`) calls `db_input high simple-cdd/profiles`, `db_go`, then immediately processes `*.preseed`, `*.udebs` and `*.packages`. A late `profiles/*.postinst` or `preseed/late_command` cannot enforce approval before queuing.

**Approved method (2026-11-14, user choice A):** use the already-supported `preseed/early_command` stage, with **no upstream udeb modification**. The [`profiles/default.preseed`](../profiles/default.preseed) command now invokes `/bin/sh /cdrom/simple-cdd/profile-confirm.sh && anna-install simple-cdd-profiles`. The shell's `&&` prevents the subsequent `anna-install` invocation when the gate fails. The script now loads the generated Simple-CDD and custom Debconf templates and asks the original profile question before the unmodified udeb starts. This is **source integration, not a tested functional installer**.

The integrated source must:
- reads the exact seven-profile selection after the Debconf multiselect;
- displays the selected/unchecked state and dependencies in GTK and text;
- obtains an explicit **default-No** approval before ANY selected-profile actions;
- allows backing out / changing the selection where the frontend permits;
- blocks when ZRAM was selected but Ensure 7.x was not separately selected;
- does not silently change any profile selection.

See [profile-confirm.templates](profile-confirm.templates) and [profile-confirm.sh](profile-confirm.sh). The files are **connected in the source `preseed/early_command`**, but no Debian Installer runtime validation has occurred. The template displays seven selected/unselected states through separate Debconf substitutions, without embedding newlines in the line-oriented protocol. Declining confirmation returns to the original profile question, without changing selections; any error or Back/cancel must prevent profile queuing.

**Required integration verification:** confirm the installer environment exposes `debconf-loadtemplate` at preseed/early_command time; the generated `simple-cdd.templates` is already on `/cdrom`; GTK and text frontends render both prompts; `seen=true` retains the already-approved multiselect after the original udeb reloads its template; and **no duplicate selection prompt, package queue or profile preseed is processed before confirmation**. Verify user decline, Back/cancel, missing templates, unknown selections, absent Ensure 7.x for ZRAM, and zero selected optional profiles. On an incompatibility, STOP and report it; do not patch the upstream udeb or remove confirmation without further user permission.

## 2. Preserve native Debian Installer behavior

Keep ordinary keyboard, locale/time, account/password, network/mirror, partman, tasksel, package-retry and reboot screens native. Map `../profile_defaults.conf` into editable defaults only after validating the Trixie Debconf IDs and whether the screen remains shown. The minimal `profiles/default.preseed` deliberately has no other answers. Do not copy upstream old default preseed over it.

## 3. Profile transaction execution

Simple-CDD 0.6.9 runs each executable `*.postinst` **in-target**, in the order returned by the Debconf selection, not necessarily the design order. The newly written native Debian Installer `preseed/late_command` calls the **single ordered dispatcher** ([`run-selected.sh`](run-selected.sh)):
Backports → Ensure 7.x → Extended device support → ZRAM → Debian tweaks → OMV 8 → Docker.

Optional `.packages` files have been removed to leave **no automatic package queue**: automatic queueing would bypass required simulation/approval and, for Docker or ZRAM, violate service and conversion timing.

The selected-only `profile-*.sh` modules and shared [`profile-common.sh`](profile-common.sh) source include package/repository changes, native review and omission questions, target logging, ZRAM GPT conversion, Docker startup suppression and OMV SSH/update handling. **These remain untested implementations**, not proof of compatibility. Verify that early/late command execution order, package candidates, GUI interaction and critical failure handling actually work, without rollback or skipped profiles.

## 4. Boot and functional release tests

Confirm generated USB boots UEFI **and** legacy BIOS, with **Graphical install** highlighted and an indefinite manual Enter wait; text and rescue remain available. The BOOT_TIMEOUT config alone is not proof of this. Confirm target UEFI/GPT and normal Debian manual partman.

Test profile combinations, conditional Backports-first kernel/firmware, first boot, 7.x headers, generator sysfs features, ZRAM writeback/emergency path, OMV 8 and Docker inactive state. Test diagnostic display, full-log copies/permissions and export. Follow [the validation checklist](../../08_validation_and_pending.md).

**Explicitly excluded by user choice:** source ISO/file hashes, output ISO hashes, USB read-back comparison and media-integrity-only tests. Functional tests and signed APT metadata verification are still required.

## Upstream evidence

- [Simple-CDD 0.6.9 postinst control](https://sources.debian.org/src/simple-cdd/0.6.9/debian/simple-cdd-profiles.postinst)
- [Simple-CDD 0.6.9 finish-install runner](https://sources.debian.org/src/simple-cdd/0.6.9/debian/14simple-cdd)
- [Simple-CDD default preseed](https://sources.debian.org/src/simple-cdd/0.6.9/profiles/default.preseed)
- [Simple-CDD build variables](https://sources.debian.org/src/simple-cdd/0.6.9/simple_cdd/variables.py)

## 5. ZRAM backing identification and reused partitions (2026-11-15)

User explicitly authorized source changes for new *and reused* swap partitions,
automatic selection when the current installation's target `fstab` names exactly
one eligible swap partition, and a native GTK/text Debconf select fallback for
ambiguous or older raw backing. The fallback starts at `none`, with no
conversion until an additional explicit default-No destructive approval.
Previously converted raw `zram-writeback` GPT partitions are shown only as
manual candidates. PARTLABEL alone is not unique proof of identity.

Source: [`zram-selection.sh`](zram-selection.sh),
[`profile-zram.sh`](profile-zram.sh), and
[`profile-confirm.templates`](profile-confirm.templates).
The approved targeted `swapoff` path remains, with memory reserve and
identity/activity rechecks. No partitioning commands occur in candidate
discovery. The original dynamic generator template filename is unchanged.

**Blocking end-to-end checks:** Verify that `/target/etc/fstab` includes the
newly created or reused swap assignment by `preseed/late_command`; that
`lsblk`, `blkid -p`, `findmnt -M`, `parted type` and Debconf dynamic
`Choices-C` behave as expected in Trixie d-i; GTK/text display, cancellation,
and choice IDs; one/multiple/no swap; cloned PARTUUIDs; reusing swap from
another OS; existing unformatted raw backing; mount/holder/active-swap
rejection; swapoff failure and RAM pressure; post-conversion GPT/fstab state;
first-boot zram setup, emergency behavior and monitor restart.

**Known gap:** A late-command failure cannot currently navigate backwards
to the earlier partitioner or deselect the profile. The current code fails
closed instead of presenting a nonfunctional navigation option. Also verify
systemd swap units or other indirect activation paths before production.
An ISO build alone cannot close these gates.
