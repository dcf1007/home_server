# my-cdd source manifest and provenance

**Initial creation date:** 2026-11-14 (Europe/Berlin).  
**Latest revision:** 2026-11-15 (Europe/Berlin).  
**Nearest user prompt (latest change):** “shouldn't zstd be a requirement in the zram profile and not in default?” The source was refined to distinguish a base-installer media dependency from an optional ZRAM runtime dependency: `zstd` moved from `profiles/default.packages` to the new `profiles/default.downloads` so it can appear on the ISO without an unconditional Simple-CDD target install. The existing media index/archive gate, two-stage builder, and kernel-backed ZRAM profile remain. Earlier reasons for the initial `default.packages` decision are retained below as history.  
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
- `installer/run-selected.sh` and `installer/profile-actions.sh` were written
  in the continuation after “replace the placeholders” and “ok. continue then”.
  They use Debian Installer's standard `preseed/late_command` to execute
  confirmed profiles, native cdebconf approvals, signed APT repositories,
  explicitly confirmed ZRAM conversion, OMV 8 and Docker safeguards. The seven
  `*.postinst` scripts now verify completion rather than duplicate the work.
  Their behavior remains **unverified on a running installer**.
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

## Authorized change: 2026-11-15 ZRAM selection correction

**Creation date:** 2026-11-15 (Europe/Berlin).
**Nearest user prompt:** “i authorise” after “I agree” and the detailed
new/reused swap and native GTK selection decisions.
**Base commit:** `df8ea81ea40a1131c8fd0fdb3e6ff9eaf82f61bf`.
**Working branch:** `fix/zram-backing-selection-20261115`.

- **New** `installer/zram-selection.sh`: collects GPT Linux-swap and prior
  validated raw `zram-writeback` candidates; identifies the unique swap
  assigned to the new target fstab or offers a Debconf `Choices-C` single
  select with safe default, including reused swap partitions.
- **Edited** `installer/profile-actions.sh`: exact selected identity and
  safety checks, independent destructive confirmation, targeted swapoff with
  memory reserve, removal of exact conventional swap fstab references,
  unchanged conversion-before-provisioning order.
- **Edited** `installer/profile-confirm.templates`: native select question,
  display of selected disk and provenance, warning on possible other-OS use.
- **Edited** `simple-cdd.conf`: ship the additional helper on install media.
- **Edited** `build.sh`: check executable hooks instead of changing Git
  checkout permissions. Tracked `build.sh` and all seven
  `profiles/*.postinst` modes changed to `100755`.
- **Updated** the related installation, profile, validation and source
  documentation. `scripts/zram-generator.conf.template` remains unchanged.

**Source-only:** No Debian Installer GTK/text execution, ISO build,
partition conversion, swapoff, first boot, or recovery test was performed.
Kernel Backports/profile-selection and full end-to-end diagnostic gates
remain open. The original embedded ZRAM source is retained.

## Authorized follow-up: apt CLI (2026-11-15)

**Nearest user prompt:** the user's earlier request to switch installer transactions to `apt` and attempt a Debian 13 chroot build.

- Replaced all legacy package-manager executable invocations with user-requested `apt` in
  `installer/profile-actions.sh` and `installer/run-selected.sh`, without
  changing package selections, simulations, approval gates or ordering.
- Confirmed that Debian 13 `apt -s install`, `apt -s full-upgrade` and
  `apt -s autoremove --purge` accept the existing simulation forms. Debian
  warns that `apt` does not have a stable scripting interface; runtime
  integration remains untested.
- Attempted an isolated Debian 13 chroot build but could not bootstrap a
  fresh Debian installation or install `simple-cdd`: package indexes were
  unavailable and both DNS and external network traffic failed.
  A minimal Debian 13 host-derived fallback chroot executed the original
  verified build wrapper; it stopped because `build-simple-cdd` was absent.
  **No ISO was built, no installer ran and no disk was modified.**

## Repository-wide APT naming follow-up (2026-11-15)

**Nearest user prompt (paraphrased):** Use `apt` throughout the repository, including documentation, and eliminate references to the old CLI spelling.

**Provenance:** The already-merged installer shell change was retained unchanged. Based on `main` commit `d5be1f583578ba2224a20e530dcb546b7ad8fa93`, this follow-up updates four planning documents and this manifest. All 61 tracked files were checked for remaining legacy command references. No package operations or installer build were performed for this wording-only update. The existing Debian warning about `apt` output instability in scripts still applies.

## Installer packaging defect and correction (2026-11-15)

- **Observed:** the user booted the generated 395 MiB Debian 13 installer-only ISO to the graphical Debian Installer, but at "Load debconf preconfiguration file" the preseeded command `/bin/sh /cdrom/simple-cdd/profile-confirm.sh && anna-install simple-cdd-profiles` exited with status **2**. The screenshot does not independently distinguish which subcommand failed.
- **Source-level finding:** `simple-cdd.conf` listed 13 installer assets as relative entries in `all_extras`. Upstream Simple-CDD's Debian-CD tool changes its working directory before copying these paths and skips files it cannot read. This is consistent with an omitted `/cdrom/simple-cdd/profile-confirm.sh` (running `/bin/sh` on a nonexistent script exits 2).
- **Correction:** `profiles/default.extra` now enumerates the original 13 assets. Simple-CDD resolves each relative entry against `simple_cdd_dir` before changing into the Debian-CD workspace. The old `all_extras` assignment was removed. `build.sh` verifies every staged asset's bytes against the source, plus the generated `simple-cdd.templates`.
- **Entry-point permissions:** `installer/profile-confirm.sh` and `installer/run-selected.sh` now have Git mode `100755`, because sourcing the Debconf `confmodule` may relaunch a script by pathname. `build.sh` also checks executable permissions in the staged ISO tree.
- **Validation boundary:** GitHub source contents, references and executable mode were checked; **a rebuilt ISO and successful graphical installation have not yet been demonstrated after the correction**. The original early Debconf method A remains unchanged. No disk operations were authorized or performed.

## Netinst base-system and interactive-defaults correction (2026-11-15)

- **Nearest user prompt:** “also you seem to have ignored me when i said that it also did not read any of the pre-set configurations. no locale, no keyboard etc; i don't have the shell access anymore so you'll have to make a guess”. This followed screenshots of failed base installation.
- **Observed:** the graphical installer successfully mounted `/target` (ample free space) and reached `bootstrap-base`, but debootstrap reported missing `/target/dev/*` paths and could not execute `/bin/true` in the target. The previous `INSTALLER_CD="1"` produced an installer-only ISO; `INSTALLER_CD="2"` includes Debian Installer **and the base system**. This is a source-backed correction and a likely resolution, not a proven diagnosis of every underlying debootstrap error.
- **Confirmed configuration omission:** `profile_defaults.conf` previously contained only symbolic planning defaults; neither `simple-cdd.conf` nor `default.preseed` applied its values, and ISO file preseeding occurs after language/keyboard prompts.
- **Correction:** `build.sh` sources `profile_defaults.conf` and validates values. It writes `tmp/generated/simple-cdd.conf` with early editable `?=` locale/language/country/keyboard kernel parameters and `tmp/generated/defaults.preseed` for hostname, administrator username, time zone, UTC and headless tasksel, with Debconf `seen false` resets. `profiles/default.preseed` includes the rendered defaults and `profiles/default.extra` packages the generated file. Normal DHCP and an empty domain remain native; passwords, device identifiers, disk changes, and optional profile selections are not preseeded.
- **Tests/boundary:** a representative preseed grammar sample was accepted by `debconf-set-selections --checkonly` in the assistant environment. The `build.sh` wrapper now validates generated preseed syntax and staged ISO inclusion, but **no Simple-CDD ISO build or live installer retest has yet been performed using these changes**. As before, selected-profile runtime, security and destructive operation behavior remains unverified.

## Historical single-invocation experiment (2026-11-15; reverted)

- **Nearest user prompt:** “now that you know what was hapenning, can you fix it without having to do a two stage build?”
- **Upstream behavior examined:** Simple-CDD 0.6.9/0.6.10 generates `UDebComponents: main` independently of `mirror_components`. The earlier split invocation first imported only `main` installer udebs, then explicitly changed the generated repository and imported `contrib` and `non-free-firmware`. Its next run could fail with a stale reprepro database target (`u|trixie|contrib|amd64`).
- **Historical implementation (now removed):** for one commit series, `build.sh` called `build-simple-cdd` once and installed the project-owned `scripts/reprepro-udeb-wrapper.sh` as a temporary `PATH` wrapper to change `UDebComponents` just before invoking `/usr/bin/reprepro`. This wrapper is no longer present or invoked.
- **Historical testing:** the wrapper passed a local simulation, but no live Simple-CDD build or installer boot using the wrapper was verified before it was removed.

## Restored two-stage build (2026-11-15)

- **Nearest user prompt:** “prioritize simplicity and maintainability over reducing two commands to one. remove the wrapper and leave the two stage build”.
- **Change:** deleted `scripts/reprepro-udeb-wrapper.sh` and removed all temporary PATH interception from `build.sh`. The build runs `build-simple-cdd --mirror-only`, expands the generated local `UDebComponents` to include `contrib` and `non-free-firmware`, runs `reprepro update`, checks both udeb indexes, and then runs `build-simple-cdd --build-only`. Separate `build-mirror-debug.log`, `build-debug.log` and combined `build-terminal.log` are retained.
- **Repeat-build cleanup:** if a previous build's reprepro database exists, the script accepts only the expected local `UDebComponents` configuration, resets it to `main` and invokes `reprepro --delete clearvanished` on `tmp/mirror` before Simple-CDD's first stage. It does not delete the mirror package cache. This cleanup has not been validated in a successful repeat build.
- **Unchanged:** `INSTALLER_CD="2"`, `profile_defaults.conf` and its generated editable boot/preseed files, all selected-profile scripts, ISO file comparisons, and executable-mode checks. The previously successful two-stage build used `INSTALLER_CD="1"`; the newly configured netinst still needs real build and installation tests.

## Missing `zstd` during base installation (2026-11-15)

- **Nearest user prompt:** uploaded two screenshots of the graphical Debian Installer and virtual console at “Install the base system,” showing `base-installer/kernel/failed-package-install` and `E: Package 'zstd' has no installation candidate`.
- **Observed:** the new two-stage `INSTALLER_CD="2"` netinst built successfully (408 MiB, 509 packages). During its VM installation, target APT installed `busybox` from `cdrom:` but could not find the distinct `zstd` command-line package. Earlier logs showed `libzstd1` and `libzstd1-udeb` downloads, neither of which substitutes for `zstd`. The official Debian 13 `zstd` package exists in `main`. The CD package subset omission is the evidence-backed immediate reason; no additional installer syslog was provided.
- **Initial source correction (later refined):** first appended `zstd` to `profiles/default.packages`. This ensured media inclusion but also queued its automatic installation with the always-present default profile, unnecessarily broadening the target baseline. The later correction moved it to `profiles/default.downloads`, documented separately below. After `--build-only`, `build.sh` reads the staged `CD1/dists/trixie/main/binary-amd64/Packages.gz`, extracts the exact `Package: zstd` record's `Filename`, and requires that the corresponding `.deb` exists and is nonempty.
- **Unchanged:** the documented two-stage mirror-build process, `INSTALLER_CD="2"`, editable installer defaults, seven unselected optional profiles and pre-existing ISO asset checks.
- **Validation boundary:** source-only changes; the corrected `zstd` ISO has not been rebuilt or install-tested. A successful rebuilt ISO/package check would not by itself prove the whole installation, including locale/keyboard GUI values and optional profiles.

## Installer-media `zstd` dependency refinement (2026-11-15)

- **Nearest user prompt:** “shouldn't zstd be a requirement in the zram profile and not in default?”
- **Evidence:** Debian Installer requested `zstd` during `base-installer/kernel` while performing the standard base installation, before any optional ZRAM work. The installed-target ZRAM code uses `systemd-zram-generator` with the Linux kernel's ZSTD compression algorithm; it does not directly invoke the user-space `zstd` command.
- **Simple-CDD semantics verified:** upstream 0.6.9 includes both `default.packages` and `default.downloads` in CD package selection. `*.packages` is automatically installed for a selected profile, while `*.downloads` places files on the media without automatically installing them through Simple-CDD (Debian Installer may still install them for its own reasons).
- **Revised implementation:** new `profiles/default.downloads` lists `zstd`. Removed `zstd` and its installation requirement comment from `profiles/default.packages`. The separate `build.sh` requirement for an actual `zstd` index entry and archive in staged CD1 remains; the optional `zram-writeback` profile package queue remains empty.
- **Validation boundary:** source changes checked, but not yet rebuilt or tested in a graphical installer. This change does not prove the installed system's final package set or successful base installation.

## Actual implementation state

**Not a validated ISO.** The seven optional profiles are described; their
`.packages` files intentionally do not queue unreviewed packages, and their
`.postinst` files verify installer-stage completion records. The approved
early confirmation and late ordered actions are connected in source but have
not been run inside Debian Installer. The existing original ZRAM assets and
all 37 firmware/microcode inventory names are unchanged.

Real APT transactions, native GTK/text prompts, destructive ZRAM conversion,
OMV/Docker package service behavior, boot-menu changes and first-boot
behavior remain unverified. That earlier source-writing turn did not perform an ISO build. Later on 2026-11-15, the user successfully built the ISO and tried the graphical installer, which failed at preseed loading. No installed-target package transaction or disk modification has been demonstrated. No mock/offline
test harness was added.

## Current tracked files (51)

- `.gitignore`
- `README.md`
- `SOURCE_MANIFEST.md`
- `build.sh`
- `installer/IMPLEMENTATION_GATES.md`
- `installer/README.md`
- `installer/ordered-selection.sh`
- `installer/profile-actions.sh`
- `installer/profile-confirm.sh`
- `installer/profile-confirm.templates`
- `installer/zram-selection.sh`
- `installer/run-selected.sh`
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
- `profiles/default.downloads`
- `profiles/default.extra`
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
