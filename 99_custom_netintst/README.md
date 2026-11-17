# 99 — Build the custom Debian 13 installer

This section teaches you **how to construct the Simple-CDD scripts**, not how to operate the finished installer. Each feature chapter explains its source files, why they exist, what the code does, and how to verify the resulting files. Full copyable source listings are included.

For manual configuration of a **normally installed Debian system**, use the corresponding [01–08 how-tos](../README.md).

## Choose your starting point

**To work on one feature**, clone the existing repository and follow that feature's construction chapter. You already have the common dispatcher and the other profiles; use a test branch or copy to avoid changing your reference.

**To reconstruct the complete installer**, follow this order:

1. [Build project](build_project.md) — create Simple-CDD configuration, editable defaults, ISO media lists and the build wrapper.
2. [Shared profile helpers](profile_construction.md) — create selection validation and target-APT helper functions.
3. [Installer framework](installer_framework.md) — create native Debian Installer hooks, checkbox/confirmation templates, stage-11 dispatcher, root recovery preflight and single completion guard.
4. Create the **seven optional profile implementations**, in the logical order below. They are all offered but **none is selected automatically**.
5. [Validation and VM testing](validation_and_pending.md) — compare complete source hashes, build the ISO, exercise approvals and failure paths in a disposable VM.

A single feature's source module is **not** a complete ISO: it depends on the shared framework. The currently shipped Simple-CDD configuration includes all seven optional choices.

## Feature construction order

| Chapter | What you will create |
| --- | --- |
| [02 — Debian tweaks](02_debian_tweaks.md) | Selected-only GRUB, root-filesystem-aware mount options, native SSH and one-time automatic-update policy |
| [03 — Backports](03_backports_apt.md) | Signed Backports source, priority 100, reviewed upgrades and removals |
| [04 — Linux 7.x kernel](04_ensure_7x_kernel.md) | Eligible suite selection, image and matching headers, GRUB |
| [05 — Extended device support](05_extended_device_support.md) | Firmware manifest, microcode and original vendor-license dialogs |
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

**Current selected-profile verification (approved 2026-11-17):** The runner records individual successful profile completion, unmodified Simple-CDD stage 14 invokes the matching executable `.postinst` verifier, and stage 15 checks every selected record and overall status with an exit-10 failure response. Installer handler filenames share their Simple-CDD profile names. These source changes require fresh ISO and disposable-VM validation.

**OMV first-boot lifecycle correction (17 November 2026):** In the latest VM, OpenMediaVault package installation succeeded but the in-target `omv-confdbadm populate` failed because upstream OMV's timezone script required a running system bus. The OMV-only handler now schedules the same two official post-install commands for a one-time systemd service on first boot, with a retained initialization log as its sole durable record and boot console/journal progress/error messages; the temporary unit, symlink and runner remove themselves after execution. The Docker handler and native Simple-CDD completion checks are unchanged. VM verification remains pending.
