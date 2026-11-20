# 99 — Build the custom Debian 13 installer

**Current dialogue workflow — 2026-11-21:** Native cdebconf shows the profile multiselect and one combined default-No summary/confirmation. Real package-changing APT commands run once without `-y`; a temporary target-side helper under the existing `debconf-apt-progress` relays the actual APT prompt to a default-No native boolean question. When APT skips its prompt, a transaction-scoped `DPkg::Pre-Install-Pkgs` protocol 2 hook asks before dpkg acts (downloads and existing preconfiguration may precede approval). No repeat review prompt for already-approved transactions; no review-only simulations. Internal kernel/firmware compatibility simulations, named firmware omissions/licenses, ZRAM destructive/targeted swapoff consent, root recovery, signed APT, native stages and completion markers remain. Backports cleanup approval is per real transaction, not per package. The helper and its private state are temporary; no persistent APT configuration. GTK/text and integrated VM validation pending.

**Current lifecycle — 2026-11-20:** Native stages 10, 50, 55 and 60 run before the selected-profile executor at `61my-cdd`; the unmodified Simple-CDD verifier, custom status guard, unmodified CD-ROM eject and unmodified final message follow at `62simple-cdd`, `63my-cdd-status`, `64cdrom-detect` and `65final-message`. The early selector registers 61/63; `partman/early_command` calls `finish-order.sh` before partitioning, checks all three original native scripts and then renames them. Native udebs and script contents are unchanged. The CD-ROM APT-source preseed remains; no forced network backend or suppressed completion dialog. Relocation failure returns nonzero to native preseed error handling, which does not guarantee installation termination. No stage-00 guard or additional repeated-execution restriction is introduced. ISO/GTK/text/first-boot testing is pending.

This section teaches you **how to construct the Simple-CDD scripts**, not how to operate the finished installer. Each feature chapter explains its source files, why they exist, what the code does, and how to verify the resulting files. Full copyable source listings are included.

For manual configuration of a **normally installed Debian system**, use the corresponding [01–09 how-tos](../README.md). **09 is an optional post-install graphical-session guide, not a Simple-CDD profile or ISO feature.**

## Choose your starting point

**To work on one feature**, clone the existing repository and follow that feature's construction chapter. You already have the common dispatcher and the other profiles; use a test branch or copy to avoid changing your reference.

**To reconstruct the complete installer**, follow this order:

1. [Build project](build_project.md) — create Simple-CDD configuration, editable defaults, ISO media lists and the build wrapper.
2. [Shared profile helpers](profile_construction.md) — create selection validation and target-APT helper functions.
3. [Installer framework](installer_framework.md) — create native Debian Installer hooks, checkbox/confirmation templates, stage-61 dispatcher, root recovery preflight and single completion guard.
4. Create the **seven optional profile implementations**, in the logical order below. They are all offered but **none is selected automatically**.
5. [Validation and VM testing](validation_and_pending.md) — compare complete source hashes, build the ISO, exercise approvals and failure paths in a disposable VM.

A single feature's source module is **not** a complete ISO: it depends on the shared framework. The currently shipped Simple-CDD configuration includes all seven optional choices.

## Feature construction order

| Chapter | What you will create |
| --- | --- |
| [02 — Debian tweaks](02_debian_tweaks.md) | Selected-only GRUB, root-filesystem-aware mount options, native SSH and one-time automatic-update policy |
| [03 — Backports](03_backports_apt.md) | Signed Backports source, priority 100, reviewed upgrades and removals |
| [04 — Linux 7.x kernel](04_ensure_7x_kernel.md) | Eligible suite selection, image and matching headers, GRUB |
| [05 — Extended device support](05_extended_device_support.md) | Firmware manifest, microcode and configurable preauthorized/interactive vendor licenses |
| [06 — ZRAM writeback](06_zram_writeback.md) | Native udeb disk selector, safe confirmation, GPT conversion and ZRAM generator |
| [07 — OpenMediaVault 8](07_openmediavault.md) | One official signed APT source, reviewed package installation and native one-time first-boot OMV initialization |
| [08 — Docker](08_docker.md) | One official signed APT source, reviewed package set; independent of OMV |

The installer executes **selected features in this fixed order**. In particular, Debian tweaks must complete before ZRAM performs any destructive conversion. Choosing ZRAM separately requires the **Linux 7.x profile**; the installer never selects it for you.

## How to use the complete listings

Open the exact file path specified in the chapter **in any text editor**, copy the chapter's entire file listing, paste it, review what you entered, and save it at that path. Do not run the sourced installer module on the build host.

Each listing includes its expected **Git blob SHA**. The command `git hash-object <path>` reads the created file and prints its hash, which you can compare with the listed value. A mismatch means the file differs and should be reviewed before building. No package or disk changes are made by that command.

After all required files exist, use the guarded `./build.sh` wrapper to create the image. Building a valid ISO does **not** prove Debian Installer runtime compatibility: use the [VM checklist](validation_and_pending.md).

## Recent installer test and open blocker

The latest Debian 13 VM (16 November 2026) progressed through Debian tweaks and the approved ZRAM conversion to OMV's APT package simulation. The user-visible plan proposed replacing `systemd-timesyncd`; the project's unrequested hard-coded package blacklist incorrectly stopped the operation before user approval. The native GTK/text failure diagnostics are functioning, but OMV, Docker and first boot remain unverified.

The revised source removes the unrequested package-removal blacklist, APT operation restrictions, duplicate service and package-origin checks, Backports post-transaction purity gates, profile-conditional CD-ROM source gate, build-time refusal checks and unrelated swap restrictions. The runner unconditionally calls **Debian Installer's existing `10apt-cdrom-setup` hook** before selected profiles, even if none are selected, rather than maintaining a separate CD-ROM source editor. The native unconditional preseed setting remains. Debian normally invokes that same hook again later in finish-install. ZRAM no longer imposes an installer-only RAM reserve on targeted swapoff. APT still displays complete transactions and requests approval; genuine command failures and selected-ZRAM destructive confirmations remain. This refactor requires a fresh disposable-VM test.

Earlier design notes and test history remain under [history](history/). [Provenance](../GUIDE_PROVENANCE.md) records why the standalone and installer versions must be updated together.

**Current selected-profile verification (approved 2026-11-17):** The runner records individual successful profile completion, unmodified Simple-CDD stage 62 invokes the matching executable `.postinst` verifier, and stage 63 checks every selected record and overall status with an exit-10 failure response. Installer handler filenames share their Simple-CDD profile names. These source changes require fresh ISO and disposable-VM validation.

**OMV first-boot lifecycle correction (17 November 2026):** In the latest VM, OpenMediaVault package installation succeeded but the in-target `omv-confdbadm populate` failed because upstream OMV's timezone script required a running system bus. The OMV-only handler now schedules the same two official post-install commands for a one-time systemd service on first boot, with a retained initialization log as its sole durable record and boot console/journal progress/error messages; the temporary unit, symlink and runner remove themselves after execution. The Docker handler and native Simple-CDD completion checks are unchanged. VM verification remains pending.
