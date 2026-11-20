# Guide provenance and scope

## Standalone ZRAM diagnostic v1–v4 — 2026-11-20 (Europe/Berlin)

**Nearest user prompt:** “commit all the versions, one after the other, until you get to version 4. document the changes in the repo as well”

**Scope and approval:** Publish the previously saved drafts as separate sequential commits directly on main, without rewriting v1 or combining the revisions. Document the current manual diagnostic and its history in [06 — ZRAM writeback](06_zram_writeback/README.md). No changes to the production pressure monitor, generator configuration, installer profiles, or Simple-CDD source manifest; this Python tool is a standalone post-install VM diagnostic.

| Revision / commit | Originating request and implementation | SHA-256 of saved script |
| --- | --- | --- |
| [v1 / b01976e](https://github.com/dcf1007/home_server/commit/b01976e5b0923c5e939e261eb07ebca0d0e88853) | “go ahead and write it, but instead of doing args, test them sequentially. push to normal, then repush to emergency and finally readback. tell me how long will take to complete the test and if you can print to the screen duuring the test to know the status of everything.” Approved subsequent commit to main. Sequential standard-library Python test using bounded temporary systemd workers and service-journal/backing-counter evidence. | `019e397c641ec32fc55c163c38986cf343dc4c9a796cd9ccb5e6f8481da99078` |
| [v2 / c9356e6](https://github.com/dcf1007/home_server/commit/c9356e6d39e4e7f62d46537eff54841419bd77bb) | “try to make the results tabular, keep a log so one can review after and also the readback was inconclusive i assume because as the pages were not needded they remained wrotten back? can you add some operation on the oldest pages (the ones created initally) like rewritting the first bit or something to force the writeback and usage of those pages?” Adds tables, exclusive timestamped text/CSV output, explicit per-page bit flip/check/restore and FIFO block verification. Historical absolute readback allowance and 120-second watchdog superseded by v3. Draft created 2026-11-20 11:18:10 UTC. | `8a99360f7965f33a951c86921f3e3d7794fabb9acc9fe0f9c8f18fe36f553d23` |
| [v3 / aa76399](https://github.com/dcf1007/home_server/commit/aa7639974c8c1f6eac1962f9a0047d38203435ec) | “why do you put a readback deadline? can't you just let it readback until it finishes? only if there is no progress in x minutes then timeout”; then “also in the page retrieval, after the page has been succesfully worked on, discard it so it does not stay in memory and the memory gets slowly emptied. one more question, are the pages highlty compressible or incompressible? i would put half and half. can you also report how much they compressed?” Adds per-page digest and immediate MADV_DONTNEED, equal pattern/random populations, no total readback deadline or cold-worker lifetime limit, five-minute inactivity watchdog and compression reporting. Draft created 2026-11-20 11:23:36 UTC. | `9b5320ada2f2873864149496243d345aaae20144edcf1b33fd1acda72a0984fa` |
| [v4 / 2a6862f](https://github.com/dcf1007/home_server/commit/2a6862f9325f00f0e846b28f55311bfc205144df) | “you can add 33% of each and allocate 33% for ZRAM's special same-element to see how good the gains are.” Equal thirds of non-uniform repeated patterns, random bytes and nonzero same-element pages, per-class allocation/discard accounting and device-wide same-element statistics. Draft created 2026-11-20 11:25:41 UTC. | `ead0e545118c8d075f4dfa88d7f29370a3295eb87b790c41bb0b0f407fedea16` |

**Observed VM evidence:** The user-supplied v1 terminal screenshot shows normal and emergency PASS, readback INCONCLUSIVE at the 180-second deadline, total backing writes 2290.4 MiB, backing reads 396.8 MiB, verified 395.7 MiB, final resident 0 MiB and cleanup success. This does not prove complete integrity or identify the exact source of readback latency.

**Verification boundary:** Saved draft manifests record local syntax checks, anonymous mmap worker tests (including 261 page modifications in v2, 258 pages in v3, and 258 + 3 pages in v4), simulated accounting, compression comparability and logging tests. Each newly committed blob was fetched back and compared to its complete saved draft with its final newline restored. The revised versions have not been run on the configured ZRAM VM. Counters remain device-wide and cannot attribute all backing I/O to individual pages or populations. Compression ratios are only reported without backing entries. The earlier proposal to increase the allocation cap from three to six times the resident limit was not approved or implemented; it remains three times, bounded by 85% of initially free logical swap and rounded to page triplets. The new mixture may therefore produce an inconclusive pressure phase.

## Final six-package labwc selection and built-in minimized-window list — 2026-11-19

**Nearest user prompt:** “so in the end use geany, no shellcheck, lxpolkit, firefox, thunar and foot. for labwc, firefox and foot with recommended, for thunar, geany and lxpolkit just the bare minimum. Where do minimized windows go?”

**Implemented:** Retain a manual-only labwc installation chapter with two reviewed APT groups: labwc/firefox-esr/foot **with Recommends**, and thunar/geany/lxpolkit **without Recommends**. Do not install ShellCheck. Update the downloadable \`09_labwc/files/menu.xml\` to include Geany and labwc's built-in \`client-list-combined-menu\`, labelled Running Windows, which provides access to hidden/minimized windows without a taskbar or another service. Keep \`rc.xml\` deleted. Replace previous lxqt-policykit optional admin-backend guidance with the selected lxpolkit agent; keep GVfs admin browsing an explicit, separately reviewed option because gvfs-backends is **not** among the six packages.

**Basis and validation boundary:** Debian 13 Trixie package metadata for labwc/foot/Firefox ESR and lxpolkit, plus labwc's upstream menu.xml example and labwc-menu(5), support the package and menu semantics. Static repository inspection and source verification do **not** establish real APT solver results, the appearance of auth prompts or a successful live labwc session on the user's machine. Existing OpenMediaVault, Docker and Simple-CDD code is unchanged.


## Remove optional labwc keybinding file; document privileged browsing — 2026-11-19

**Nearest user prompt:** “erase the rc. with the menu is more than enough. how can i make it so i can explore root only folders in thunar?”

**Implementation:** Delete \`09_labwc/files/rc.xml\` from the public repository, eliminate its download/install instructions and shortcut claims from \`09_labwc/README.md\`, and keep \`menu.xml\` as the sole downloadable labwc configuration. No keybindings are installed or overridden. Add an optional, separate Thunar administrator-browsing section using the GVfs admin URI and an interactive Polkit agent, with APT simulation and an explicit warning that elevated browsing is **not read-only** and brings additional user-session integration. Do not add administrator Thunar commands to the menu or introduce GUI installer profiles.

**Observed context:** User supplied \`lspci\` showing VMware SVGA II Adapter (15ad:0405), \`/dev/dri/card0\` and \`/dev/dri/renderD128\`, and local \`tty1\` environment. Their prior attempt with \`WLR_RENDERER=pixman labwc\` worked. This identifies the current setup as a VMware virtual graphics environment; it does **not** prove the exact Mesa/EGL cause.

**Validation boundary:** GitHub repository content/deletion verification and upstream Debian package manifests support the documented paths; no live APT transaction, OMV compatibility test, Polkit prompt, or elevated filesystem access was performed. All installer implementation remains unchanged.


## Optional manual labwc configuration guide — 2026-11-19

**Nearest user prompt:** “read this whole repository and add this as an extra manual configuration guide, so i can wget or curl the config file from the repo from my headless setup. [https://github.com/dcf1007/home_server](https://github.com/dcf1007/home_server)”.

**Repository inspection:** Inspected the complete tracked 100-file tree on main (normal Debian 13 chapters, construction docs, current installer source, manifests and history). The repository is explicitly based on Debian 13/OMV 8 and keeps normally installed-server how-tos separate from the seven selected Simple-CDD profiles. No pre-existing labwc feature or installer profile was found.

**Implemented:** Add 09_labwc/README.md as an independent, opt-in manual configuration guide. Publish two plain-text files, 09_labwc/files/menu.xml and 09_labwc/files/rc.xml, for direct HTTPS curl/wget downloads into the regular user's ~/.config/labwc directory. The menu launches foot, Firefox ESR, optional Thunar, reconfiguration and session exit; the keybinding retains labwc defaults and binds Super+Enter to foot. Document safe downloads, backup of existing configuration, optional package simulation, local-console requirements, Pixman fallback after an EGL error, and OMV storage/network boundaries. Link chapter 09 in the root contents and clarify its exclusion from the Simple-CDD construction scope.

**Provenance/verification boundary:** Source syntax was compared with published labwc menu and keyboard documentation. Repository contents and links can be validated statically, but labwc/Firefox/Thunar runtime on a particular GPU, dependency plan, SSH context or OMV installation is not established by repository documentation. The software-rendering fallback was reported to start labwc in the conversation; no new first-boot, live OMV, ISO or graphical runtime test is claimed. No installer implementation, systemd unit, OMV source or profile was modified.


## Approved self-cleaning OMV first boot — 2026-11-17

**Nearest user prompt:** “i agree with the suggestion”, following the explicit request for a one-time script which leaves only logs and cleans up its own systemd files on success and failure.

**Observed cause:** The 2026-11-17 VM reached successful OMV 8 package installation then failed when the in-target `omv-confdbadm populate` called `timedatectl` without system D-Bus. The two OMV upstream commands and their original order remain unchanged.

**Implemented:** OMV package stage installs and registers a one-time first-boot service. It creates the private log before executing either command, records stdout/stderr, progress, final command/exit status, and then disables/removes its service, symlink and runner, retaining only `/var/log/installer/my-cdd-omv-firstboot.log`. On a later boot after an interrupted attempt, the existing log causes cleanup only. No status/attempt/MOTD files are retained. Console/journal reporting is transient; persistent failure details are in the log. Native completion markers still verify package+registration success rather than actual OMV runtime readiness.

**Boundaries:** No Docker modifications, extra OMV commands, NAS policies, APT changes or shared installer hook changes. Six isolated mocked shell cases passed; full ISO, Debian Installer and real first-boot verification are not yet established.

## Native per-profile verification restoration and naming — 2026-11-17

**Nearest user authorization:** “i agree. use A”, following explicit agreement on canonical installer filenames and unchanged feature scope.

In the open PR #24 branch, native Simple-CDD `.postinst` checks and seven per-profile completion markers were restored, along with the final selected-profile/overall-status exit-10 check. The seven installer handler filenames now match `profiles/` identifiers; ZRAM's dedicated selector uses the same stem with a `-selection` suffix. Corresponding complete source listings and Git blob hashes were synchronized in the current construction guides. Earlier dated records are retained as historical states. No successful fresh ISO build, disposable-VM end-to-end install or first boot is asserted.


## Reuse native finish-install and Simple-CDD lifecycle — 2026-11-17

**Nearest user prompt:** “implement”, following the upstream-reuse audit that identified redundant orchestration, seven marker-only postinst verifiers, the firmware-license template workaround and the manual mirror-udeb adaptation.

**Source implementation:** Keep the original Simple-CDD selection question and its explicit user-approved early Debconf summary. Replace the custom `preseed/late_command` entrypoint with early registration of the single dispatcher as native `/usr/lib/finish-install.d/11my-cdd`. Debian Installer performs native `10apt-cdrom-setup` **first**, once, using the retained unconditional `apt-setup/disable-cdrom-entries=true` setting, then custom selected operations at 11, upstream `14simple-cdd`, and our sole final `15my-cdd-status` check. No direct second CD-ROM hook call. No Simple-CDD or Debian Installer vendor source patch. Selected module order and all explicit APT/destructive/license approvals are unchanged.

**Removed duplication:** Delete all seven trivial `profiles/*.postinst` marker verifiers, per-profile marker writes, and the ZRAM `ensure-7x-kernel` marker check. The selection parser already enforces the independently selected kernel prerequisite; the approved dispatcher executes the successful kernel profile before ZRAM and aborts before ZRAM on any failure. Keep only the global runner status `INCOMPLETE`/ `COMPLETE` and the native exit-10 final completion gate, which is required because Debian Installer otherwise logs most nonzero finish-install script statuses and continues.

**Native limitations confirmed, not silently bypassed:** `apt-install` and `debconf-apt-progress` use native Debconf passthrough for *during-install* package questions, but do not establish the required **pre-install named-license consent and individual package omission** workflow. An earlier VM did fail on the original package license passthrough. The existing native-template extraction/preapproval remains until a verified replacement meets both requirements. Simple-CDD 0.6.9's mirror builder hard-codes `UDebComponents: main`; the project's two-stage local `reprepro` component adjustment remains until a native-only build demonstrates equivalent udeb/firmware coverage. Neither workaround is represented as eliminated.

**Verification boundary:** 43 surviving full source listings and Git blob SHA IDs in the construction guides match the current PR branch; the changed runner, early selector, preseed, final status hook and ZRAM handler match their embedded listings byte-for-byte. All seven deleted verifier listings were removed. No ISO build, full `sh -n`, Debconf VM test or first boot performed. Previous source/provenance entries below record historical stages and may mention deleted code; this section is the current state.

## Reuse Debian's native CD-ROM cleanup hook before profiles — 2026-11-17

**Nearest user instruction:** “isn't the early editor the one from cdd? just call the cdd one early and don't reinvent the wheel”.

**Verified upstream source:** Debian 13 Trixie's `apt-setup` package (version `1:0.198`) supplies the existing `/usr/lib/finish-install.d/10apt-cdrom-setup` shell hook. It is **Debian Installer's apt-cdrom-setup hook**, not a Simple-CDD editor. The unmodified script reads `apt-setup/disable-cdrom-entries`; when true it comments `^deb cdrom:` in target `/etc/apt/sources.list`, appends a source explanation and runs `chroot /target apt-get update` via `log-output`. Source: https://sources.debian.org/src/apt-setup/1:0.198/finish-install.d/10apt-cdrom-setup .

**Applied in PR #24:** Replace the bespoke `sed` source cleanup block with a single `capture /usr/lib/finish-install.d/10apt-cdrom-setup || fatal ...` call unconditionally after confirmed profile selection but before root recovery, the optional profile loop and any custom package transaction. Retain native `d-i apt-setup/disable-cdrom-entries boolean true`. No external mirror, source rewrite, package filtering or new helper is added.

**Upstream behavior and limitation:** The same native hook will ordinarily run again at its normal 10apt-cdrom-setup finish-install stage. Its Trixie source does not skip the later `apt-get update` or explanatory comment append when invoked twice with the true preseed; thus early reuse can duplicate that native work. This is documented rather than masked with a custom wrapper or upstream patch. Native `sed` handles the observed `^deb cdrom:` target `sources.list` lines only, not other source formats. Do not infer VM success until the next disposable-VM test.

## Corrected interpretation: unconditional CD-ROM cleanup before profiles — 2026-11-17

**Nearest user prompt:** “I wanted the CD-ROM cleanup to be non-conditional an happen before the custom profiles and therefore the custom apt transactions”.

**Previous error:** PR #24's interim revision deleted the only early source editor and left `apt-setup/disable-cdrom-entries=true` in the preseed, which cannot guarantee that cleanup precedes `preseed/late_command`: Debian's normal `10apt-cdrom-setup` stage runs after `07preseed`. This contradicted the user's requested ordering.

**Superseded intermediate implementation:** The runner temporarily restored a bespoke legacy CD-ROM entry edit. The current revision instead calls Debian's native hook as documented above. It runs with or without selected optional profiles, edits only active legacy `deb cdrom:`/`deb-src cdrom:` lines (and bracket-option forms), and leaves network APT source entries unchanged. Keep the native unconditional preseed option for later Debian Installer cleanup. No separate refusal checks, mirror changes, package blacklists or new helpers.

**Verification boundary:** Isolated sed fixture passed; CDD full listing/hash refreshed. Runtime behavior still needs the next disposable VM. Other changes in PR #24 remain unmerged.

## Final removal of discretionary origin, build and swapoff gates — 2026-11-17

**Nearest user instruction:** “remove 1,2,3 and 5. for 4, remove the conditional one and leave the unconditional cdrom entries . remove also the zram swapoff refusals, it is an installation environment ffs, of course the swap is going to be empty. talk me through what you call 'conditional manual-update policy.'”

**Implemented on PR #24:** Removed OMV's redundant `apt-cache policy`/URL package-origin gate and the analogous five-package Docker gate, without changing the one signed repository for each profile or their full APT simulation and default-No user approval. Removed the redundant end-of-ZRAM `passwd -S root` check; retained the already-approved shared local-root-recovery setup. This **intermediate PR revision** removed the conditional installer `run-selected.sh` CD-ROM APT source mutation and retained native `d-i apt-setup/disable-cdrom-entries boolean true`. That interpretation was **superseded by the corrected unconditional early cleanup** documented above. The earlier user-requested local-root-recovery setup was restored to the base-only path too, correcting an unapproved scope change introduced in the first PR #24 draft.

**Targeted swapoff:** Removed all installer-created RAM/swap-use reserve thresholds, 256 MiB/one-eighth-of-RAM refusal policies, and auxiliary memory-pressure sampling. Retained explicit default-No confirmation to deactivate the **exact previously confirmed partition** if active, actual targeted `swapoff` execution, success/continued-activity checks and the prohibition on overwriting an active swap signature. This is an actual operation requirement, not an estimated resource veto. Other devices remain untouched.

**Build wrapper:** Removed custom input/domain/keyboard/network regex validation, source shadow/placeholder preflights, `sh -n` build-stage refusal loop, package-pool and staged-ISO asset verification gates, and bespoke local mirror state refusals. Retained the exact two-stage Simple-CDD mirror/build commands, udeb-component preparation, canonical editable-preseed generation and ordinary command failures. Removed previously inert `DEFAULT_KEYBOARD_VARIANT` and `DEFAULT_NETWORK_METHOD` knobs from `profile_defaults.conf` rather than silently accepting values the renderer never used: the actual keyboard variant and networking method remain freely selectable in Debian Installer's native dialogs.

**Manual-update explanation (no change requested or made):** Only the explicitly selected Debian tweaks profile checks whether `unattended-upgrades` is installed and `APT::Periodic::Unattended-Upgrade` is enabled. It changes the latter to `"0"` once, in native `20auto-upgrades` when suitable, else via one `99-my-cdd-manual-updates` override. If absent or already disabled, it does nothing. No later profiles revisit the setting. This is not a restriction on manually running APT or on unrelated updater software.

**Important outstanding runtime caveat:** Debian's `apt-setup/disable-cdrom-entries` native cleanup is documented as running in a later finish-install stage than the custom preseed late command. The user clarified that the early source adjustment must run **unconditionally** before custom profiles. The current source restores that ordering, but a new ISO/VM run must still establish operational success. No new ISO or VM validation has been performed.

## Remove unapproved installer policy restrictions — 2026-11-17

**Nearest user instruction:** “it's none of your business what you consider risky or unexpectedd. If i have not asked something and approved it, you should not do it. remove them all. the user can see what the installer is going to do and decide on its own. keep only the things i asked and authorised”.

**Immediate evidence:** The latest Debian 13 VM reached OMV's APT simulation, which proposed removing `systemd-timesyncd` as part of installing OMV, but our project-defined `check_critical_removals` blocked approval. This was not a failure of APT's own dependency resolution. Proposed PR #23 added a package-specific exception, contrary to the user's requirement; it was **closed without merging**. The current branch replaces it with removal of the entire unrequested blacklist.

**Source corrections:** The shared package-removal blacklist and every call are deleted; kernel/firmware candidate selection no longer rejects APT-resolved transactions due to package-name filters. `run_target` and `simulate_target` no longer apply custom command-operation whitelists, but preserve the native Debian Installer progress UI, complete APT simulation, and explicit default-No user approval. Removed redundant service-start suppression preflight, speculative Deb822 CD-ROM source rejection/recheck, Backports old-pin and effective-priority refusal gates, and Backports extra post-upgrade/post-cleanup “nothing remains” simulations. The earlier PR revision alternately retained then removed the legacy CD-ROM source adjustment; the latest user clarification restores it **unconditionally before the profile loop**, as documented at the top of this record. APT continues to enforce its own dependency/signature rules.

**Selected partition scope:** ZRAM preserves other swap entries in the target's `fstab` rather than vetoing the install because they exist; it also no longer rejects unrelated `PARTLABEL` swap references. Its exact selected-device identity checks, mount/holder validation, separate destructive confirmation, bounded first-1-MiB signature erase, targeted swapoff and approved generator/pressure monitor remain. The selected partition's corresponding old swap entry alone is removed.

**Historical intermediate draft (superseded):** A first attempt scoped root emergency-password setup to selected profiles only. That unapproved change was corrected in the later user-directed revision above; the prior approved base-install recovery behavior is restored.

**Explicitly retained:** Selected-profile summary and consent, complete real APT transaction review and default-No approval, firmware vendor-license and omission consent, separately selected Linux 7.x prerequisite for ZRAM, local root recovery for selected profiles, exact partition identity and destructive confirmations, and genuine operation failure reporting. No OMV/Docker-specific SSH, groups, automatic-update, mirror or plugin policy is added.

**Source and runtime distinction:** The eight previously identified discretionary restriction categories are removed from this branch. No new ISO/VM test is claimed: OMV, Docker and compressed-writeback first boot still require verification. Updated the complete 99 construction guide listings/hashes to match the changed executable files.

## Official OMV signing keyring read permission — 2026-11-16

**Nearest user prompt:** Two screenshots of the Debian Installer GTK failure dialog showing `apt-get update` exit status 100 and `Permission denied (os error 13)` when `sqv` reads `/usr/share/keyrings/openmediavault-archive-keyring.gpg`.

**Observed:** The earlier diagnostics/UI change succeeded in surfacing APT's actual error. Repository metadata was fetched, but cryptographic verification could not read the dedicated OMV keyring. The error does not establish a bad repository signature or DNS failure.

**Source correction:** The installer keeps `umask 077` for private work/log files; the selected OMV handler changes the mode of only its new **public** APT keyring to `0644` immediately after dearmor, before refreshing package indexes. This fulfills Debian APT's `Signed-By` requirement that `_apt` can read the keyring. The standalone OMV 07 guide and the full CDD 07 construction source listing/hash are synchronized. The one official signed APT source and vendor-only OMV installation scope remain unchanged.

**Validation boundary:** Source inspection and synchronized listings do not prove a successful ISO build, OMV installation or first boot. A fresh disposable-VM run must verify APT signature validation succeeds, before subsequent profiles and services are considered functional.

## Native installer error reporting — 2026-11-16

**Nearest user prompt:** “make the actual errors pop in the interface if you want to get them”, following screenshots of the Debian Installer's OMV `apt-get update` failure without the underlying APT stderr.

**Observed VM evidence:** The latest installer run progressed through Debian tweaks and the approved selected ZRAM partition conversion, and reached OMV. OMV's signed key was downloaded/inspected/imported. The next `apt-get update` failed and stopped the installation; the native error dialog showed only the generic failure and unrelated prior log output, so no repository/DNS/signature cause has been established. Docker and first boot were not reached.

**Implementation:** In the shared installer `capture()`, Debian Installer's `in-target --pass-stdout` retains its native target setup and Debconf passthrough. The target program's stderr is redirected to stdout **inside the target shell**, avoiding Debian Installer's stderr-to-syslog routing. The command's original exit code and complete stdout/stderr are recorded in `my-cdd.log`; the existing GTK/text `fatal()` note now prioritizes the actual failing command, exit status, recognizable APT/dpkg error lines and last 100 command-output lines. If the command emits no captured output, it shows a short installer-syslog fallback. No additional debug UI or one-time helper is added.

**Scope:** Generic shared diagnostic path only, plus matching full source listing, validation and provenance. No change to the OMV repository, signing key, packages, SSH, automatic-update policies or ZRAM destructive conversion. A new ISO/VM test must confirm the real diagnostic is visible; this remains source-level only.

## Root-filesystem policy and one-use helper simplification — 2026-11-16

**Nearest user prompt:** “the noatime and errors=panic should be set no matter the filesystem of the root partition ... ensure_manual_updates sounds like a helper used only once. i prefer readable code that does not jump to useless one time helpers. review all code for that kind of useless helpers”, followed by “i agree” to the examined changes.

**Latest VM evidence:** The newer installer run established the local root password, completed GRUB generation, then failed during Debian tweaks' former `sshd -t` test. The installer syslog explicitly reports `Missing privilege separation directory: /run/sshd`. No ZRAM conversion occurred in that latest run. Earlier screenshots established a ZRAM GPT conversion under the old execution order; no successful complete install or first-boot writeback has been shown.

**Selected Debian tweaks:** `profile-tweaks.sh` edits only the single target root `fstab` entry and preserves `/target/etc/fstab.before-tweaks`: generic `noatime` for all root filesystem types, ext2/3/4 `errors=panic`, Btrfs `fatal_errors=panic`, and no unsupported panic option for XFS/other types. Main `/etc/ssh/sshd_config` gets `PermitRootLogin no` before `Include`/`Match`; no additional SSH drop-in, `sshd -t`, `sshd -T` or transient `/run/sshd` directory. `unattended-upgrades` policy is configured **once** if enabled, using native `20auto-upgrades` where present and one fallback override otherwise. No post-edit or later-profile rechecks.

**Function audit:** Removed single-use `ensure_manual_updates`, `verify_target_sshd`, `reviewed_upgrade`, `zram_check_utilities`, `mark_complete`, and pass-through `zram_blkid`. Inlined their operations at their callers, except for SSH runtime validation, which was removed entirely. Moved repeated `normal_suite` selection into the only profile that needs it (firmware). Retained shared `capture`, approval, transaction and target-execution interfaces; complex root recovery, firmware licensing and ZRAM selection/revalidation routines stay separate. No other feature semantics were intentionally changed.

**Verification:** Update both standalone and CDD instructions and refresh full source listings/hashes. Static source checks do not constitute an ISO build, graphical installer execution or first-boot validation.

## Approved OMV installation boundary and ZRAM consolidation — 2026-11-16

**Nearest user instruction:** “omv cdd should do nothing about ssh, that will be dealt later. the only things omv cdd is allowed to do at max are the ones done in the install script ... nothing more”; approval of the single-override ZRAM approach, followed by “go ahead”.

**Current OMV contract (supersedes earlier OMV-specific CDD policies):** The selected OMV profile must perform **only** the official OpenMediaVault 8 `install.sh` operations: validate a supported Debian/architecture/desktop environment, obtain the official signing key, configure **only the first official signed APT repository in OMV 8's manual Debian installation guide** (`http://packages.openmediavault.org/public/ synchrony main`), install OMV through an explicitly reviewed/default-No package transaction, run `omv-confdbadm populate`, and run `omv-salt deploy run hosts`. Do **not** configure SSH, root login, user groups, automatic updates, notifications, OMV-Extras, Compose, Docker, storage or other policies in this profile. The official quick installer's permissive APT downgrade/held-package flags are deliberately not used. The shared CDD installer framework's existing root-recovery preflight remains separate and unchanged. The normal OMV how-to follows the same signed-APT and initialization sequence. OMV and Docker now share the selected-only signed-APT / reviewed-transaction pattern, with independent package sets and OMV-only database/hosts initialization. No fallback-mirror list is created.

**Current ZRAM contract:** Keep the generator-supported size/compression/backing settings, selected-only `vm.swappiness=100`, existing pressure monitor and restart policy. Replace the two setup drop-ins with one `override.conf` containing the compressed-writeback pre-initialization step plus emergency-mode-on-setup-failure policy; use the short `90-zram.conf` asset. The generator cannot replace the compressed-writeback pre-initialization action. Partition selection, confirmations, bounded erase and first-boot validation gates remain unchanged.

**Verification boundary:** Source/listing synchronization, structural checks and source-file presence can be checked without booting. **No successful new ISO build, Debian Installer VM execution, compressed writeback or OMV first-boot result is established by this change.** The most recent user VM evidence still ends at the old Debian-tweaks SSH failure. See [validation](99_custom_netintst/validation_and_pending.md).

## Current synchronization contract — approved 2026-11-16

**Nearest user instruction:** “when there is a change in a section, the changes have to be reflected in the cdd as well. leave this recorded in your provenance/memory files ...” followed by approval and five screenshots from the latest generated ISO.

**Mandatory change rule:** A feature change must update **both** its ordinary Debian how-to and its matching CDD construction tutorial **and source code**, where behavior changes are applicable. Differences necessary for installer-only udebs, cdebconf or `/target` must be documented. When CDD code changes, update its **complete embedded file listings and Git blob hashes** in the same change. Check chapter numbers, internal links, dispatcher order, selection summary and VM validation together. Record the user prompt, revision date, tests, and any still-open gates. Never infer successful runtime behavior from a shell syntax check or ISO build.

**Approved new sequence:** 01 Base Debian → 02 Debian tweaks → 03 Backports → 04 Linux 7.x → 05 Firmware/microcode → 06 ZRAM → 07 OMV → 08 Docker. The CDD profile IDs remain their original stable names; only the offered/validated/executed **order** changes. CDD shared build/framework/validation tutorials are now unnumbered.

**Identity and recovery:** In the native Debian installation, leave both initial root-password fields empty to enable sudo administration for the first regular user. The ordinary [base guide](01_base_debian/README.md) sets a local root recovery password **after** confirming sudo works. The CDD instead verifies the sudo account during the late installation stage and asks for the separate recovery password **before** any selected destructive or package operations, protecting first boot.

**Automatic upgrades:** `unattended-upgrades` may be installed and enabled on some Debian 13 installations; do not assume a universal default. The standalone [tweaks guide](02_debian_tweaks/README.md) checks package presence and effective APT settings and uses Debian's own interactive reconfiguration only when needed. The CDD shared helper makes a target override **only when that package is installed and automatic installation is enabled**. Older OMV update/notification policy statements below are historical; current OMV configuration is left to the user.

**User's latest ISO evidence:** The five screenshots supplied on 2026-11-16 show a default-No ZRAM partition conversion dialog, user-approved conversion of a VM partition's first 1 MiB and GPT type/name, a reviewed `systemd-zram-generator` package transaction, and an explicit later failure: `OpenSSH configuration invalid` at `sshd -T` in Debian tweaks. They do **not** establish successful first-boot ZRAM writeback. The current CDD source now prepares a possible missing **transient** `/run/sshd` directory for target config checking, records the actual stderr when failing and runs tweaks **before** the destructive ZRAM stage. The missing-directory cause is a hypothesis, **not confirmed** by those screenshots; rerun in a disposable VM.

**Scope and static verification of this revision:** Ordinary guide numbering/content, matching CDD developer chapter paths, source order, sudo/SSH/update checks, synchronized embedded source copies, validation and provenance. Independently recomputed **all 50 embedded complete source-file Git blob hashes** against current tracked CDD files; all matched. All six relocated firmware/ZRAM assets retain their original Git content and modes. Restored the executable modes of the early/late installer entry points and verified no remaining code-file mode drift. Checked local documentation links, including the archive. No new ISO, shell syntax run, or first-boot test was executed by the assistant for this revision.

## Historical provenance (earlier revisions; superseded where noted)

**Latest construction-manual revision:** 2026-11-16 (Europe/Berlin).

**Nearest user prompt:** “i still would not be able to take one of the guides, understand what i have to do, and recreate it. they are still confusing.”

**Change in response:** The 99_custom_netintst build chapters now specify **prerequisites, exact source paths, the purpose of each file, exact text-editor commands, full file listings for every non-document file needed by the current Simple-CDD project, Git blob SHA provenance and a syntax/build/VM checklist**. The listings are byte-for-byte copies of source at commit `bf5090eb37338d9304be7e7c88fcd063b5db7b0e` (before this documentation update). The project source and normal post-install guides remain unchanged. The guide makes explicit that one optional profile needs the shared framework, whereas the current full ISO contains seven profile choices.

**Static validation performed:** All **50** complete source listings were extracted from these Markdown guides and independently recomputed as Git blob SHA-1 objects. Each matched both its displayed hash and the corresponding source blob in the pre-change repository. All changed active Markdown links resolve, Markdown source-listing fences are balanced, and all **56** tracked files under `99_custom_netintst/my-cdd/` retain their original Git blob IDs and modes. **Runtime validation remains open:** no new ISO build, installer execution, partition conversion or first-boot test was performed.

**Current update date:** 2026-11-16 (Europe/Berlin).

**Nearest user prompt:** “you're messing everything up. the netinst sections should describe how to build the custom script for the section. i don't know what you did but it's useless”.

**Correction:** PR #15 and preceding documentation revisions treated the `99_custom_netintst` chapters as a walk-through of operating the **finished installer**, which was not what the user requested. This revision reorients `99_custom_netintst` into a **developer-facing construction guide**: which scripts, manifests, sources, Debconf templates and build settings to create or modify; the actual implementation mechanics; annotated code excerpts; hook integration; and source/VM validation.

**Source basis:** `dcf1007/home_server` at the current `main` before this revision, including `99_custom_netintst/my-cdd/build.sh`, `simple-cdd.conf`, `profiles/default.preseed`, all seven `profile-*.sh` modules, `zram-selection.sh`, `profile-confirm.sh`, `run-selected.sh`, `profile-common.sh`, `15my-cdd-status`, the package manifests, license handling and archived historical plans. The actual Simple-CDD project files remain **unchanged**; this change edits only its documentation.

**Structure:** [ordinary installed-Debian guides 01–08](README.md) remain end-user operational procedures. [custom netinst](99_custom_netintst/README.md) is now a source-construction manual with [00 — common profile wiring](99_custom_netintst/profile_construction.md), [01 — ISO build](99_custom_netintst/build_project.md), [05 — installer framework](99_custom_netintst/installer_framework.md), each feature's construction chapter and [08 — developer validation](99_custom_netintst/validation_and_pending.md).

The earlier standalone OMV helper was removed. The current [OMV how-to](07_openmediavault/README.md) and installer profile both use direct signed APT and OMV's two official initialization commands; the former inline JSON update/notification policy code was removed from the current CDD profile.

**Accuracy boundary:** annotated snippets show portions of the currently tracked implementation; snippets explicitly labelled illustrative or excerpts are **not** complete scripts to execute independently. The linked existing code is the complete implementation being explained—not a substitute for these instructions. This revision does **not** claim a new ISO build, runtime installer test, physical disk operation or first-boot validation. The required tests remain in the [developer validation guide](99_custom_netintst/validation_and_pending.md).
