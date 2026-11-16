# 99 — Rebuild the custom Debian installer from the guides

**This directory is a developer's construction manual.** It tells you exactly **which files to make, what each file does, its full contents, how it connects to Simple-CDD and how to check the result**. It is not a guide to clicking through the finished installer.

The [ordinary Debian guides 01–08](../README.md) are for installing each feature **manually on a running Debian server**. The documents here are for creating the **custom Debian Installer scripts** that automate those operations.

## Choose the task you are doing

### A. Recreate or modify just one feature in the existing project

This is the easiest way to study **one** feature, because the shared installer framework and the other six profiles already exist.

First, download a separate working copy:

~~~sh
git clone https://github.com/dcf1007/home_server.git
~~~

This copies the project files onto your build computer. It **does not install the NAS or execute any installer code**.

Move into the installer source project:

~~~sh
cd home_server/99_custom_netintst/my-cdd
~~~

Then open the chapter for your chosen feature in the table below. **Follow its steps in order.** You will be told the exact filename to open with `nano`, why it exists, how it works, and where to find its **complete file contents** in that same chapter.

The repository already contains those files. To practise recreating them without losing the reference, make your edits on a test Git branch or in a separate scratch checkout, and compare each recreated file's Git blob hash with the original shown in the guide.

### B. Recreate the entire current installer from an empty directory

You must create the **shared framework first**. The seven selectable profiles depend on it, and the current `simple-cdd.conf` lists **all seven**. A single profile file is **not a bootable ISO**.

The complete build order is:

1. [01 — Build project](01_custom_cdd_preparation.md): create `simple-cdd.conf`, editable defaults, `build.sh` and build-only package lists.
2. [00 — Common helpers](00_profile_construction.md): create the selection order and APT helper functions.
3. [05 — Installer framework](05_base_installation.md): create the early and late preseed hooks, Debconf templates, dispatcher and finish-install guard.
4. Create **each profile** below, one at a time. Each page includes **all of its feature-specific source files**.
5. [08 — Validate and build](08_validation_and_pending.md): syntax checks, complete ISO build, VM installation and first boot.

**Every non-document source file in the tracked `my-cdd` project is represented by a complete listing** in one of the build chapters. Each listing gives the expected original Git blob hash so you can detect a missing line or incorrect copy.

If you only want to implement **one** feature from scratch, begin with an existing clone (approach A). The current shared configuration is deliberately fixed to seven choices; creating just one profile from an empty directory without adjusting the shared configuration **will not produce a complete image**. That would be a separate, explicitly designed variant, not the currently documented build.

## The profile-by-profile construction chapters

| Build chapter | What source files you recreate |
| --- | --- |
| [02 — Backports](02_backports_apt.md) | Choice/manifest/verifier, complete target APT profile and signed Debian source |
| [09 — Linux 7.x](09_ensure_7x_kernel.md) | Choice/manifest/verifier, complete kernel image/header selection and install module |
| [10 — Firmware](10_extended_device_support.md) | Choice/manifest/verifier, full package inventory, license/omission handling module |
| [03 — ZRAM writeback](03_zram_writeback.md) | Choice/manifest/verifier, native disk selector and conversion code, all five ZRAM assets |
| [04 — Debian tweaks](04_debian_tweaks.md) | Choice/manifest/verifier and complete target GRUB/fstab/SSH/APT tweaks |
| [06 — OpenMediaVault 8](06_openmediavault.md) | Choice/manifest/verifier and complete signed OMV installation/policy module |
| [07 — Docker](07_docker.md) | Choice/manifest/verifier and complete official Docker installation module |

Follow this order when building the full project, because the dispatcher executes the selected features in that order.

## How to use the complete file listings

Each chapter follows the same pattern:

1. **Read the prerequisite and filename table.** Do not guess a path or function name.
2. Use the supplied `nano <path>` command to create that exact file **inside `my-cdd`**.
3. Expand **Complete file: ...** at the bottom of the chapter. Copy the **entire contents** between the code fences, including comments and final newline. The listing is actual source, **not an abbreviated example**.
4. Save the file. If the chapter instructs you to use `chmod +x`, do so for the **entry point or verifier only**; sourced `profile-*.sh` files are not independent programs.
5. Run the displayed `sh -n` / `bash -n` checks; those parse code **without executing APT or disk operations**.
6. To check for a copy error, run `git hash-object <path>` (with the real filename) and compare its output to the **original blob SHA** shown in the expanded listing. This command reads the file; it does not modify it.
7. Only after **all shared and selected source files** are present, run `./build.sh` from `my-cdd`, then boot the ISO with a **disposable VM disk** for the tests in [08](08_validation_and_pending.md).

**Never execute `installer/profile-zram.sh`, `installer/profile-omv.sh` or any other sourced installer module directly on the build host or running NAS.** The modules assume they are loaded by Debian Installer and that `/target` is the new operating system.

## Why even the full source listing is not a runtime test

The complete listings reproduce the tracked code **as-is**. They do not certify that its current Debian Installer integration works. The native ZRAM conversion, selected-profile Debconf flow, OMV networking/Salt, and first-boot writeback still require VM validation. The earlier design history and failure reports are under [history](history/).

**Provenance:** these full-file listings are copied from source revision `bf5090eb37338d9304be7e7c88fcd063b5db7b0e` (the `main` branch before this documentation rewrite). If implementation code changes later, the complete listings and their blob hashes must be updated together.
