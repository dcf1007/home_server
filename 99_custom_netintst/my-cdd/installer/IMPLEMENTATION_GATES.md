# Implementation requirements still outstanding

## Initial root dialog and firmware license policy — 2026-11-20

**Nearest user prompt:** “in the sequence, is it possible to exchange 5 and 6 in an easy way? if not leave them ass they are.these 2 changes should be an independent pr”

- Native account setup: generated `defaults.preseed` now contains `d-i passwd/root-login boolean false`. This skips initial root-password questions and preserves ordinary interactive user setup plus native sudo membership. The existing stage-11 sudo verification and separate root-recovery password prompt remain unchanged in timing and behavior; moving that prompt into early account setup would need additional lifecycle/credential handling. No credentials are preseeded, and no SSH policy changes.
- Firmware: `AUTO_ACCEPT_FIRMWARE_LICENSES="true"` in `profile_defaults.conf` preauthorizes only the two named vendor agreements (`firmware-ipw2x00` and `firmware-ivtv`) for the explicitly selected Extended device support profile. `build.sh` validates true/false and produces a data-only `tmp/generated/firmware-license-policy` staged by that profile's .extra. Exact candidate archive/template checks remain; acceptance is recorded in target Debconf and verified before installation. Log distinguishes preauthorization from interactive acceptance and records the selected version. Set false and rebuild to recover the original complete license, refusal, and omission workflow. Review vendor terms before enabling or distributing the ISO; later package versions may have changed terms.
- Existing complete APT simulations and explicit transaction, omission and destructive approvals remain. No Netplan diagnostic changes from PR #33; no OMV/Docker changes.
- Source changes require a fresh ISO build and disposable-VM verification in both automatic and interactive firmware modes (including refusal), with the initial root dialog absent, regular user sudo membership intact, late recovery password and normal completion. No ISO/runtime verification claimed.


**Current OMV one-time self-cleaning lifecycle (2026-11-17):** The approved first-boot systemd service runs the two unmodified upstream initialization commands, `omv-confdbadm populate` and `omv-salt deploy run hosts`, on the booted system rather than in Debian Installer's chroot, which lacks system D-Bus during OMV timezone population. The job logs complete output and final result to `/var/log/installer/my-cdd-omv-firstboot.log`, then disables/removes its temporary unit, enablement symlink and runner on either success or failure; **no persistent MOTD or status/attempt file** remains. A preexisting attempt log causes cleanup-only, without command reruns. Runtime progress/failure is visible on boot console/journal. Native stage-14/15 markers still indicate OMV package installation and successful job registration, not post-boot readiness. Six mock cases passed; ISO and VM first-boot verification remain outstanding. No Docker or other profile change. Historical entries below describe superseded versions.


**Latest user-approved Route A restoration, 2026-11-17:** The original Simple-CDD `14simple-cdd` hook is not patched: it again executes each approved selected profile's executable `profiles/<name>.postinst` verifier **in-target**. The stage-11 runner writes each selected profile's success marker only after the handler returns successfully, and writes overall `COMPLETE` only when all selected handlers succeeded. Stage `15my-cdd-status` independently requires the confirmed selection, every selected marker and overall `COMPLETE`, returning finish-install exit 10 when incomplete. All seven `installer/<name>.sh` files share their canonical Simple-CDD profile IDs, as does the `zram-writeback-selection.sh` helper stem. Native profile verification does **not** rerun installation. This is source-only until a disposable-VM ISO/installer/first-boot test.

**Previous single-status-only architecture, 2026-11-17 (superseded by approved Route A above):** At the user's “implement” request following the upstream-reuse audit, `profile-confirm.sh` registers the approved profile runner as native finish-install `11my-cdd` **before** the standard finish-install hook enumeration. Debian's existing `10apt-cdrom-setup` therefore disables CD-ROM APT sources **once**, unconditionally, before the custom runner. The old `preseed/late_command` and direct duplicate `10apt-cdrom-setup` invocation are gone. `14simple-cdd` is untouched. Seven redundant marker-only optional `.postinst` verifiers and all per-profile marker writes/checks are gone. The single `15my-cdd-status` checks final `COMPLETE` plus confirmed selection and returns native exit 10 if not complete. This retains the approved seven-profile order, GTK/text consent, APT transaction review and target error output.

**Boundaries:** The firmware-license preapproval code remains because user-approved individual omission must occur *before* actual package installation; plain native APT passthrough alone is not proven to provide that workflow, and an earlier VM showed passthrough fd-3 failure. Manual `reprepro` udeb-component preparation also remains because Simple-CDD 0.6.9 constructs `UDebComponents: main` and no verified configuration-only equivalent was identified. Neither was silently deleted or represented as replaced. Stage-11 execution, native CD-ROM timing, license handling, build and first boot require a disposable-VM retest. Historical references below to duplicate CD-ROM hook calls, late-command execution and per-profile markers describe **superseded revisions**, not the current source.

**Native Debian Installer CD-ROM cleanup reuse (2026-11-17):** At the user's direction, the runner no longer implements any custom `sed` editor. It now **unconditionally invokes the existing `/usr/lib/finish-install.d/10apt-cdrom-setup` hook** after profile confirmation and before root recovery, the first profile and all custom APT transactions. This Debian `apt-setup` hook uses the retained `apt-setup/disable-cdrom-entries=true` preseed value; it also ordinarily runs again at finish-install stage 10 (possible repeated native `apt-get update` and explanatory source comments). Confirm timing, availability and APT behavior in a disposable VM. No ISO/VM validation is claimed.


**Current user-directed correction (2026-11-17):** The explicit request removes OMV/Docker package-origin refusal gates, ZRAM's duplicate end-of-profile root-status check, bespoke build validations and arbitrary ZRAM swapoff RAM/PSI thresholds. The subsequent clarification restores the CD-ROM source cleanup unconditionally before every custom profile, rather than gating it by selected profiles. The unconditional native `apt-setup/disable-cdrom-entries` option remains. Targeted swapoff still requires independent user consent and cannot overwrite an actually active swap partition. The original local root recovery requirement was restored even when no custom optional profile is selected, undoing an unapproved intermediate scope change. Debian tweaks' conditional one-time `unattended-upgrades` setting remains unchanged. The new early unconditional legacy CD-ROM cleanup runs during `07preseed`, before custom APT; the native cleanup still occurs later at `10apt-cdrom-setup`. Actual installer success requires a fresh disposable VM. No ISO/VM execution is claimed for this revision.

**Current approved-scope correction (2026-11-17):** The user explicitly rejected unrequested restrictions, including the hard-coded critical-package blacklist that stopped the latest OMV APT simulation. PR #23's proposed one-package exception was **closed unmerged**. The new review branch deletes the blacklist everywhere, removes APT-command whitelisting, redundant service-start and APT-source/preference refusal checks, unnecessary repeated Backports post-transaction simulations and the extra veto on unrelated ZRAM swap entries. Keep APT's native dependency/signature enforcement and the **full user-reviewed default-No transaction approval**. A later correction restored the previously approved base-install local root recovery requirement; it is no longer conditional on selecting an optional profile. Exact ZRAM partition identity and destructive consent remain required. All changes await a fresh disposable-VM ISO run.

**Confirmed latest VM failure (2026-11-16):** The shared native GTK failure note now correctly displays actual `apt-get update` diagnostics. OMV's official archive signing key was imported, but APT's `sqv` verifier could not read `/usr/share/keyrings/openmediavault-archive-keyring.gpg` (`Permission denied (os error 13)`); exit status 100 stopped the selected OMV profile. With the shared runner's `umask 077`, the keyring was created with permissions incompatible with APT's unprivileged signature verifier. The OMV handler now explicitly executes `run_target chmod 0644` on the **public keyring only** after `gpg --dearmor`. This exact change needs a new disposable-VM test. No repository source/mirror change or signature bypass is approved. Docker and first boot have not been verified.

**Newest 2026-11-16 VM evidence and pending diagnostic test:** The latest user screenshots show user-approved selected swap backing, separate swapoff confirmation (0 bytes used), reviewed ZRAM generator installation and successful progression to OMV. The OMV signing-key download, fingerprint display and keyring creation succeeded; OMV's `apt-get update` then returned nonzero and stopped the installation, before Docker. The actual APT stderr was absent from the original dialog. The revised shared `capture()` explicitly forwards stderr through `in-target --pass-stdout` using an in-target shell redirection; `fatal()` now shows failed command, status, recognizable errors and its output in the native GTK/text dialog. **No new ISO/VM test has yet confirmed this diagnostic output.** The OMV package source and service policy are unchanged; first boot remains unverified.


**Latest user-provided VM evidence (2026-11-16):** The newer graphical installer ran Debian tweaks **before ZRAM** and established the separate local root recovery password. It stopped during the former unnecessary `sshd -t` test. The installer syslog identifies **`Missing privilege separation directory: /run/sshd`**. Earlier screenshots separately established an approved 1 MiB swap-partition conversion and ZRAM generator installation under the old profile order, but no complete installation or first-boot ZRAM operation. The current Debian tweaks source now edits the existing main `sshd_config` directly and performs **no** preboot SSH daemon checks. The root mount receives generic `noatime` and only the panic option supported by its filesystem. It configures manual APT updates once, without follow-up checks. These changes remain unverified in a new VM.

**Synchronization rule:** when standalone Debian instructions change, update the matching CDD developer tutorial and its actual selected-profile source (if applicable), regenerate complete source listings/hashes, and re-run syntax + disposable-VM checks. The first user must be sudo-capable after the native initial root-login skip; the late preflight then creates a separate local root recovery password before selected changes. Conditional `unattended-upgrades` handling depends on the package being installed and actually enabled. See [SOURCE_MANIFEST](../SOURCE_MANIFEST.md) and [GUIDE_PROVENANCE](../../../GUIDE_PROVENANCE.md).

**Native installer service handling (2026-11-15):** Debian Installer 1.155 automatically sets a temporary `policy-rc.d` returning 101 when the `in-target` wrapper runs and diverts `start-stop-daemon`. The selected-profile runner verifies this upstream protection; it does not duplicate it or disable first-boot services. Historical 2026-11-15 behavior: the OMV profile used apt/apticron to disable automatic updates. **Superseded on 2026-11-16:** OMV profile now only adds upstream signed sources, installs OMV with review and executes `omv-confdbadm populate` plus `omv-salt deploy run hosts`. Its network/hosts transition needs live testing.


**Additional approved policy (2026-11-15):** The common late-command preflight must verify/set a local root password if the installed root account is locked or passwordless **before any selected profile changes files, packages or partitions**. The native user-setup Debconf password questions are reused and cleared afterward; no password may enter a log or package manifest. Test root already enabled, locked root with sudo user, password mismatch and cancellation, including the zero-profile path. Docker and OMV remain independent; no OMV-Extras/Compose install and no Docker service masking/disabling. This 2026-11-15 OMV scheduled-update requirement has been **superseded**: the OMV-specific CDD handler now leaves update policy, notifications and SSH untouched.

**Current source revision (2026-11-15):** Optional operations were reorganized into selected-only modules, with no unselected base account/SSH/update overrides. `profiles/default.packages` now falls back to CDD's upstream file. The source was not revalidated in a live installer, so all runtime gates below remain open. The latest recovery preflight and Docker-default-startup changes also await actual GTK/text installer validation.

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
Debian tweaks → Backports → Ensure 7.x → Extended device support → ZRAM → OMV 8 → Docker.

Optional `.packages` files have been removed to leave **no automatic package queue**: automatic queueing would bypass required simulation/approval and, for Docker or ZRAM, violate service and conversion timing.

The selected-only `profile-*.sh` modules and shared [`profile-common.sh`](profile-common.sh) source include package/repository changes, native review and omission questions, target logging, ZRAM GPT conversion, and OMV's official package/install initialization (no additional SSH/update handling). **These remain untested implementations**, not proof of compatibility. Verify that early/late command execution order, package candidates, GUI interaction and critical failure handling actually work, without rollback or skipped profiles.

## 4. Boot and functional release tests

Confirm generated USB boots UEFI **and** legacy BIOS, with **Graphical install** highlighted and an indefinite manual Enter wait; text and rescue remain available. The BOOT_TIMEOUT config alone is not proof of this. Confirm target UEFI/GPT and normal Debian manual partman.

Test profile combinations, conditional Backports-first kernel/firmware, first boot, 7.x headers, generator sysfs features, ZRAM writeback/emergency path, OMV 8 and Docker normal startup state. Test diagnostic display, full-log copies/permissions and export. Follow [the validation checklist](../../validation_and_pending.md).

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

Source: [`zram-selection.sh`](https://github.com/dcf1007/home_server/blob/8a8c5b055531523fb3088905a21aa3c82701c5df/99_custom_netintst/my-cdd/installer/zram-selection.sh),
[`profile-zram.sh`](https://github.com/dcf1007/home_server/blob/8a8c5b055531523fb3088905a21aa3c82701c5df/99_custom_netintst/my-cdd/installer/profile-zram.sh), and
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

## 6. Native installer ZRAM block tools (2026-11-16)

ZRAM probing uses installer-native `blkid`, `/sys/class/block`,
`/proc/swaps` and `/proc/self/mountinfo`; targeted swapoff and an
explicitly approved 1 MiB signature erase use installer BusyBox. The
selected partition is kept, changed to GPT type 8300 and renamed
`zram-writeback`. Target-side block-device commands are no longer used.
Build-only `installer-media.udebs` includes `util-linux-udeb` for `blkid`
and `parted-udeb` for GPT updates.

**Runtime validation remains open:** confirm low-level `blkid -p -o export`
`PART_ENTRY_*` data on raw partitions, actual BusyBox `dd` flags, device
links, /proc/swaps KiB readings, GPT updates and first-boot generator behavior
on a disposable VM disk. A successful ISO build is not runtime validation.
