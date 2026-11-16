# 99 — Build the custom Debian 13 installer

This section teaches you **how to construct the Simple-CDD scripts**, not how to operate the finished installer. Each feature chapter explains its source files, why they exist, what the code does, and how to verify the resulting files. Full copyable source listings are included.

For manual configuration of a **normally installed Debian system**, use the corresponding [01–08 how-tos](../README.md).

## Choose your starting point

**To work on one feature**, clone the existing repository and follow that feature's construction chapter. You already have the common dispatcher and the other profiles; use a test branch or copy to avoid changing your reference.

**To reconstruct the complete installer**, follow this order:

1. [Build project](build_project.md) — create Simple-CDD configuration, editable defaults, ISO media lists and the build wrapper.
2. [Shared profile helpers](profile_construction.md) — create selection validation and target-APT helper functions.
3. [Installer framework](installer_framework.md) — create native Debian Installer hooks, checkbox/confirmation templates, dispatcher, root recovery preflight and completion guard.
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
| [07 — OpenMediaVault 8](07_openmediavault.md) | One official signed APT source, reviewed installation and required OMV initialization |
| [08 — Docker](08_docker.md) | One official signed APT source, reviewed package set; independent of OMV |

The installer executes **selected features in this fixed order**. In particular, Debian tweaks must complete before ZRAM performs any destructive conversion. Choosing ZRAM separately requires the **Linux 7.x profile**; the installer never selects it for you.

## How to use the complete listings

Open the exact file path specified in the chapter **in any text editor**, copy the chapter's entire file listing, paste it, review what you entered, and save it at that path. Do not run the sourced installer module on the build host.

Each listing includes its expected **Git blob SHA**. The command `git hash-object <path>` reads the created file and prints its hash, which you can compare with the listed value. A mismatch means the file differs and should be reviewed before building. No package or disk changes are made by that command.

After all required files exist, use the guarded `./build.sh` wrapper to create the image. Building a valid ISO does **not** prove Debian Installer runtime compatibility: use the [VM checklist](validation_and_pending.md).

## Recent installer test and open blocker

The latest Debian 13 VM (16 November 2026) progressed through the fixed Debian tweaks stage, the selected ZRAM swap conversion and generator installation, and OMV's signing-key import. The OMV profile then stopped at `apt-get update`; the native failure dialog omitted the actual APT error because `in-target` logged its stderr only to the installer syslog. Docker and first boot were not reached.

The current shared installer source redirects the target program's stderr to captured stdout **inside** `in-target`, and presents the failing command, exit code, recognized error lines and actual command output in the same GTK/text failure note. OMV's official repository and installation behavior are unchanged pending the actual error. **This logging fix is not yet VM-validated.**

Earlier design notes and test history remain under [history](history/). [Provenance](../GUIDE_PROVENANCE.md) records why the standalone and installer versions must be updated together.
