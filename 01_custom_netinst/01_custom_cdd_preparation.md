# 01 — Customized netinst / Simple-CDD preparation

**Status (2026-11-15):** installer-only ISO successfully built (~395 MiB, 414,187,520 bytes); **not boot-tested or installation-validated**. **Original design recorded:** 2026-11-14. **Provenance:** custom server Debian 13 planning conversation, the request to document custom netinst preparation, and build logs supplied on 2026-11-15.

## Purpose

Build an amd64 Debian 13 (Trixie) installer USB using **Simple-CDD** (customized Debian installer). **Use Debian Installer's existing native interactive prompts and their normal persistence/handling for ordinary setup choices; do not recreate, duplicate or separately ask planning decisions for built-in installer behavior.** Package installation is interactive wherever possible and automated otherwise; only behavior unique to the custom selectable profiles or not covered by Debian Installer needs an additional reviewed confirmation mechanism.

The USB **supports UEFI and legacy BIOS**, but the server is intended to install in **UEFI/GPT** mode. Do **not** add an unsolicited BIOS-mode safeguard. The USB bootloader highlights **Graphical install** and waits indefinitely until Enter. Preserve text installer and rescue alternatives. The *installed* GRUB timeout is five seconds.

## Installer profile architecture

Simple-CDD supports selectable profiles, typically expressed using files such as `profiles/<name>.description`, `.packages`, `.preseed` and `.postinst`. The obligatory `default` profile contains common configuration; optional profiles should be independently selectable.

| Selectable profile | Guide | Scope |
|---|---|---|
| **Backports** | [02_backports_apt.md](02_backports_apt.md) | Enable Backports at **Debian default priority 100**; perform user-reviewed eligible-package upgrade and autoremove/purge cleanup |
| **Ensure 7.x kernel branch** | [09_ensure_7x_kernel.md](09_ensure_7x_kernel.md) | Use newest suitable Linux 7.x from standard repos, or request selective backported kernel packages when approved |
| **Extended device support** | [10_extended_device_support.md](10_extended_device_support.md) | Request **both Intel and AMD microcode** plus proactive device firmware; any unavailable/conflicting package requires individually approved omission |
| **ZSTD ZRAM writeback** | [03_zram_writeback.md](03_zram_writeback.md) | ZRAM with raw writeback backing and monitor; explicitly requires Ensure 7.x |
| **Debian tweaks** | [04_debian_tweaks.md](04_debian_tweaks.md) | Only non-default Debian operating-system adjustments; independent of Ensure 7.x |
| **OpenMediaVault 8** | [06_openmediavault.md](06_openmediavault.md) | Optional OMV installation, approved cron-apt shutdown |
| **Docker** | [07_docker.md](07_docker.md) | Official Docker packages, daemon and socket inactive |

**Backports** is an independently selectable profile described in [02_backports_apt.md](02_backports_apt.md). It enables the repo at default priority **100** and owns the explicitly confirmed upgrade of eligible installed packages followed by reviewed autoremove/purge cleanup. **Ensure 7.x kernel branch** is a separate profile described in [09_ensure_7x_kernel.md](09_ensure_7x_kernel.md), and prefers eligible Backports 7.x packages **when Backports is explicitly selected**, otherwise normal Debian 7.x candidates first (offering Backports if needed). Normal installer choices are in [05_base_installation.md](05_base_installation.md).

**Approved default profile selection:** all **seven** optional profiles (**Backports**, **Ensure 7.x kernel branch**, **Extended device support**, **ZSTD ZRAM writeback**, **Debian tweaks**, **OpenMediaVault 8**, **Docker**) start **unchecked**. The installer must show all options and require the user to explicitly select and confirm each desired profile. Selecting none means base Debian only; no profile is silently added.

**Exact optional profile menu/execution order:** **Backports → Ensure 7.x kernel branch → Extended device support → ZRAM → Debian tweaks → OMV 8 → Docker**, skipping profiles not selected. This is an intentional installer-menu order; existing numbered documentation filenames are historical and need not indicate the menu order. **Debian tweaks is independent of Ensure 7.x**: it must configure the selected tweaks on Debian's default kernel when Ensure 7.x is unchecked. No kernel-package installation is performed by Debian tweaks.

**ZRAM is independent of Debian tweaks but depends on Ensure 7.x kernel branch:** if ZRAM is selected without Ensure 7.x, offer to **select Ensure 7.x** or **deselect ZRAM**. When Backports is already selected, Ensure 7.x prefers eligible **Backports 7.x** image/headers first, with normal-repository fallback if necessary. Otherwise Ensure 7.x checks normal Debian repositories first and, if none provides suitable 7.x, offers **explicit Backports selection** or cancellation. Never silently enable any profile. Backports is kept at priority 100; it performs the reviewed full-upgrade and cleanup, and the kernel profile requests only necessary backported kernel-related packages. Validate all transitions before producing the ISO.

## Final selected-profile summary and confirmation — approved Option A

**Decision recorded 2026-11-14:** Debian Installer's **GTK** frontend supports custom Debconf questions, and Simple-CDD has a native Debconf **multiselect** for profiles. Therefore show a **second, read-only summary and explicit confirmation** in the **ordinary graphical Debian Installer**, between completion of profile selection/dependency resolution and the **first selected-profile package or script operation**. This is a **custom integration requirement**, **not a built-in automatic Simple-CDD summary screen**. Its approved early-preseed hook is now present as source in [`my-cdd/`](my-cdd/README.md), but **has not been executed or validated in Debian Installer**.

**Display:** in this exact seven-profile order, list every option and **Selected**/**Not selected** state: Backports, Ensure 7.x kernel branch, Extended device support, ZRAM, Debian tweaks, OpenMediaVault 8, Docker. Clearly state any dependencies, such as selected ZRAM requiring explicitly selected Ensure 7.x, and explicitly selected Backports enabling its separately reviewed repository/upgrade path. If no optional profiles were selected, show that the installation is **base Debian only**. This summary **does not select, deselect or silently correct** any profile.

**Prompt:** use a custom cdebconf template such as **`Type: note`** for summary text and/or **`Type: boolean`** (default **false**) for **"Proceed with these selected installation profiles?"**. A debconf script invokes the current frontend via the normal `db_input`, `db_go` and `db_get` flow; the GTK installer renders its own native question/confirmation widgets. The user must explicitly confirm; returning, declining, cancelling or an unresolved dependency must **not launch profile operations**. Where supported, navigate back to the selectable profile question, show the updated summary, and reconfirm. Do not assume the GTK frontend supports arbitrary custom tables or a new full-page GUI design; a text-formatted Debconf summary is sufficient.

**Critical execution gate:** the Simple-CDD profile-selection udeb reads the selected profile value then normally loads profile preseeds and queues udeb/package installation **within its own `postinst`**. Accordingly, the summary must be integrated **after the actual `simple-cdd/profiles` Debconf selection and before its first preseed/package/script side effect**, with profile dependency resolution as an appropriate preceding gate. An ordinary **`profiles/*.postinst`** or `preseed/late_command` is **too late** to guard that queuing phase. **Authorized implementation A (2026-11-14):** invoke [`my-cdd/installer/profile-confirm.sh`](my-cdd/installer/profile-confirm.sh) from `profiles/default.preseed`'s `preseed/early_command`, before `anna-install simple-cdd-profiles`; load the original generated multiselect and the seven-item Debconf summary in that hook, then set the selected question's `seen` state after approval so the **unmodified** upstream udeb can continue. This is implemented as source only, and all ordering/duplicate-prompt behavior must be validated on Debian 13 before it is treated as working. Do not merely draw a summary after work has already begun and call it confirmation.

**Text/rescue compatibility:** the normal text frontend must use equivalent Debconf question/confirmation semantics; the installer is not allowed to require GTK exclusively. Rescue mode should retain its normal distinct behavior, not accidentally run optional installation profiles. The final summary is **additional** to and does **not replace** any mandatory manual disk/partition, targeted `swapoff`, firmware omission, APT transaction, package-removal or destructive conversion approvals.

**Technical validation gate:** establish the precise integration stage, access to the user-selected profile set, rendering of a dynamic seven-item summary in GTK and text frontends, a reliable negative-default confirmation, ability to return to profile selection and re-confirm, no side effects before approval, and correct behavior for zero/all/some selected profiles. If the approved preseed integration cannot actually run **before** profile actions, do not claim that it works, do not substitute a custom udeb, and do not automatically remove the confirmation; **stop and ask the user** before changing the method or requirement.

**Sources:** [Debian Installer UI frontends](https://sources.debian.org/src/installation-guide/20250803%2Bdeb13u1/en/boot-installer/parameters.xml); [Debconf protocol and supported question types](https://www.debian.org/doc/packaging-manuals/debconf_specification.html); [Debian 13 Simple-CDD package 0.6.9](https://packages.debian.org/trixie/simple-cdd); [Simple-CDD profile selection script](https://sources.debian.org/src/simple-cdd/0.6.9/debian/simple-cdd-profiles.postinst).

## Canonical editable installer GUI defaults

The normal Debian Installer questions use **[profile_defaults.conf](my-cdd/profile_defaults.conf)** as the planning source of suggested defaults. It now contains:

- Editable example **hostname** and administrator **username**; an empty DNS domain.
- **English** installer language, **`en_US.UTF-8`** locale and **Spanish (Spain)** keyboard.
- **`Europe/Berlin`** time zone with the hardware real-time clock in **UTC**.
- Wired **DHCP** networking and the minimal/headless software selection: **SSH server + Standard system utilities**, no desktop.

The matching [`profile_defaults.conf.example`](my-cdd/profile_defaults.conf.example) is a reference example, not a second source of truth. No GUI-editable setting should be implemented only inside Debian tweaks. Prompt the user on the normal installer screens, allow edits, require confirmation, and propagate the confirmed values throughout the installed system. **Do not silently preseed answers, bypass installer screens or freeze values in profile post-install scripts**; the exact mapping from these symbolic config names to Debian Installer questions requires engineering validation.

**Do not store passwords, hashes, disk targets or selected-profile flags** in either defaults file. Only non-default boot, filesystem, recovery, SSH and update-policy settings remain in the optional Debian tweaks profile. Both Intel/AMD microcode packages and additional proactive firmware belong to the separate optional [Extended device support](10_extended_device_support.md) profile. When Backports is already selected, prefer eligible Backports firmware and **both** microcode package versions first through selective per-package requests, and fall back to normal repository candidates if needed. Keep global Backports priority **100**; simulate the full package set and require individual, explicitly approved omissions.

## Build-host setup and reproducible ISO build

On a compatible Debian build machine, install the build tools (using `apt` consistently):

```sh
sudo apt update
sudo apt install git simple-cdd reprepro
build-simple-cdd --help
```

Clone the repository **once** (or skip the clone if it is already present):

```sh
cd ~/Desktop
git clone https://github.com/dcf1007/home_server.git
cd home_server/01_custom_netinst/my-cdd
./build.sh
```

For subsequent repository updates and builds:

```sh
cd ~/Desktop/home_server
git pull --ff-only
cd 01_custom_netinst/my-cdd
./build.sh
```

The resulting installer-only image is `my-cdd/images/debian-13-amd64-CD-1.iso` relative to `01_custom_netinst/`. `INSTALLER_CD="1"` keeps the image small and obtains the target system's packages from the network mirror. This is **not** an offline full-installation ISO. The build requires working network access and Debian archive availability.

### Why the build wrapper has two stages

Simple-CDD 0.6.9 and 0.6.10 can generate a local reprepro mirror with `UDebComponents: main` despite `mirror_components="main contrib non-free non-free-firmware"`. Debian-CD then checks the additional **Debian Installer udeb** indexes and prints:

```text
Missing package file for amd64/contrib.
Missing package file for amd64/non-free-firmware.
```

These are **udeb** indexes under `dists/trixie/<component>/debian-installer/binary-amd64/`, not the ordinary `binary-amd64/Packages.gz` indexes. The fix does not depend on downgrading Simple-CDD.

The repository's `my-cdd/build.sh` performs the following sequence, preserving its fail-closed selected-profile checks:

1. Run `build-simple-cdd --mirror-only` to create the local mirror.
2. Verify the expected reprepro configuration, then change `UDebComponents: main` to `UDebComponents: main contrib non-free-firmware` **in that generated local mirror only**.
3. Run `reprepro update` and require existing `Packages.gz` or `Packages.xz` installer indexes for both additional components; otherwise stop without building the ISO.
4. Run `build-simple-cdd --build-only` to assemble the ISO.

The ordinary mirror components remain `main contrib non-free non-free-firmware`. The Debian-CD firmware component is set separately in `simple-cdd.conf` using `export NONFREE_COMPONENTS="non-free-firmware"`. Both build stages run with `--debug`; Bash `pipefail` ensures a failing stage is not hidden by `tee`.

### Logs and checks after a build

All paths below are relative to `my-cdd/`:

| Path | Purpose |
|---|---|
| `build-mirror-debug.log` | Simple-CDD mirror-stage debug output |
| `build-debug.log` | Simple-CDD ISO-stage debug output |
| `build-terminal.log` | Combined terminal output, including the explicit reprepro update |
| `tmp/log/mirror-reprepro` and `tmp/log/build-debian-cd` | Individual underlying tool logs; upload the `.log` copies if that is how they were exported |
| `images/debian-13-amd64-CD-1.iso` | Generated installer-only ISO |

```sh
cd ~/Desktop/home_server/01_custom_netinst/my-cdd
grep '^UDebComponents:' tmp/mirror/conf/distributions
for component in contrib non-free-firmware; do
    ls -lh "tmp/mirror/dists/trixie/$component/debian-installer/binary-amd64"/Packages.*
done
grep -F 'Missing package file for' build-terminal.log || true
ls -lh images/debian-13-amd64-CD-1.iso
```

**Observed on 2026-11-15 (user's Debian VM logs):** both stages completed, both previously missing installer-component messages were absent, and Debian-CD wrote an image of **414,187,520 bytes (395 MiB)** with exit status **0**. This verifies **build and index generation**, not BIOS/UEFI boot, profile-selection GUI, preseed timing, package installation, ZRAM safety or first boot.

**Separate warnings remain** in the successful build: unavailable `task-desktop` causing repeated `default_desktop` messages, missing `installation-guide-amd64`, missing installer-source `MD5SUMS`, and nonfatal ISO filesystem warnings. These must be assessed independently; they are not evidence that the installer-component fix failed. Do not add a desktop or disable checks merely to silence warnings.

**Implementation source progress (2026-11-15):** [`my-cdd/`](my-cdd/README.md) contains the seven selectable profiles, early profile-summary hook, late-command ordered executor, package/ZRAM/OMV/Docker routines and completion checks. **An ISO now builds**, but the full installer workflow is **not validated**. Early/late Debconf timing, ZRAM conversion, OMV networking, package transactions, boot menu and first-boot behavior remain engineering checks.

Source layout (the release tests and verified target-side installer behavior are still missing):

```text
my-cdd/
  README.md
  profile_defaults.conf
  profile_defaults.conf.example
  simple-cdd.conf
  profiles/
    default.description
    default.preseed
    backports.description
    backports.postinst
    ensure-7x-kernel.description
    ensure-7x-kernel.postinst
    debian-tweaks.description
    debian-tweaks.packages
    debian-tweaks.postinst
    extended-device-support.description
    extended-device-support.packages
    extended-device-support.postinst
    openmediavault.description
    openmediavault.postinst
    docker.description
    docker.postinst
    zram-writeback.description
    zram-writeback.packages
    zram-writeback.postinst
  scripts/
  installer/
  build.sh
```

Verify actual Simple-CDD profile questions and integration inside a disposable VM before treating the generated ISO as ready for installation. **The user creates or reuses an existing GPT swap partition manually in ordinary Debian Installer partitioning.** **At the start of the selected ZRAM profile execution**, its first task is to identify the uniquely assigned swap partition in the installed target's `/etc/fstab`, or offer a native GTK/text Debconf selection of verified eligible partitions when that mapping is ambiguous; **immediately after explicit confirmation**, convert only that partition to GPT **8300**, PARTLABEL **`zram-writeback`**, raw/unformatted writeback backing, with no independent swap activation. **If the selected partition is already active as swap, request explicit consent for a targeted `swapoff` after checking memory safety and proceed only upon successful, verified deactivation; otherwise stop before changing the partition.** Do this before other ZRAM provisioning or first boot, not in the normal partitioner. When ZRAM is not selected, the partition remains ordinary swap. The target example is 16 GB, but use the actual user-confirmed capacity and PARTUUID rather than requiring an automatically created partition. If ZRAM is selected and **no** eligible partition exists, the late-stage profile currently stops without disk modification; actual native navigation back to partitioning or deselection remains an unverified release gate. Never silently add/repartition a disk or proceed with ZRAM using no backing partition. Validate the menu navigation, partman formatting/activation timing, fstab treatment and explicit consent before implementation.

## Non-negotiable safeguards

1. **No unattended disk actions:** present OS installation target identification, partition creation, filesystem operations and final commit for manual confirmation. Never hard-code a device path such as `/dev/sda`.
2. **Interactive passwords:** prompt for the installer-confirmed administrator account's password; configure and verify sudo; then prompt for a **separate root password before first reboot**. No password or hash stored in the media.
3. **Repository trust:** official Debian binary repositories use signed Release metadata. Third-party sources must use verified, narrowly scoped signing keys. Do not bypass signature checks.
4. **Fail closed on selected profile errors:** a critical dependency, OMV, ZRAM, SSH/network or validation failure prevents successful completion. **Use Debian Installer's existing network, mirror and package-retrieval prompts wherever they already apply; do not introduce duplicate custom screens.** For later custom-profile package operations, reuse an existing native recovery facility when available, or stop with diagnostics and manual intervention if recovery cannot be safely integrated. No selected profile is silently skipped and no false success is reported. **No installer-managed snapshots, backup images, automatic rollback or automatic restoration.** Recovery is explicitly manual, including repair or reinstallation.
5. **No unexpected configuration:** the user will manage OMV itself after first boot, except for the explicitly approved disabling of OMV's scheduled cron-apt job and preserving agreed SSH access controls.
6. **Reboot:** show Debian's standard completion screen, require manual **Continue** before first reboot.

## Network and repository errors — reuse native Debian Installer behavior

**Clarification recorded 2026-11-14:** Standard network setup, repository mirror selection, package-retrieval retries, and ordinary Debian Installer configuration persistence **belong to Debian Installer**. Do **not** implement an extra custom **Retry / Change mirror / Stop** screen where Debian Installer already supplies the interaction; do **not** ask the user to pre-decide whether a chosen mirror survives installation. **Decision 118 is withdrawn as redundant.** Retain the earlier preference for user-directed recovery **only where a genuinely custom-profile stage lacks a native equivalent**.

**Custom-profile errors:** if a selected optional profile experiences a recoverable network or download failure after the normal installer stage, first reuse the current supported installer recovery/navigation facilities if practical and verified. If a native recovery prompt is unavailable at that stage, **stop the selected profile with diagnostics and clear manual-repair guidance** rather than inventing a separate mirror-management workflow. Do not automatically retry in a loop, change repository sources, skip a selected profile, accept unsigned metadata, or declare a partially installed profile successful. The existing requirement for signed Debian/third-party repositories and individually reviewed package transactions remains in force. If an explicitly approved repair changes package candidates, re-simulate and reapprove affected transactions.

**Engineering boundary:** verify exactly which Debconf/apt-setup/net-retriever interactions remain available during Simple-CDD optional-profile execution. This is an implementation compatibility gate, **not a request for more pre-installation user decisions**. Retain graphical and text installer paths; default to the built-in workflow whenever possible.

## Installation failure and recovery boundary

- **Approved policy:** installer does not create snapshots, full-system backups, restore points or automatic rollback logic before, during or after optional-profile installation. It must not request backup destinations or secretly allocate rollback storage.
- On critical failure, **stop with an unambiguous failure message**, **always display diagnostics and offer manual log export**, persist the custom-installation logs to **`/target/var/log/installer/` if the installed target filesystem is safely mounted and writable**, and **also save a second copy onto the installer USB if a suitable writable area is safely available**. Independently report the success or failure of each destination. Allow manual recovery or reinstallation; a partially installed target is **not** represented as successful or automatically recoverable.
- Preserve existing special-case behavior: failure of **ZRAM initialization on first boot** must enter emergency mode; failure of the running ZRAM monitor should be logged/restarted without emergency mode. Neither exception constitutes automatic rollback.
- **Storage safeguards:** do not assume hybrid ISO USB boot media is writable; use only a positively identified, already writable **data area on the same installer USB**. Never remount immutable ISO content read-write, repartition, format, overwrite the boot image, use an unrelated removable disk, or make USB logging a reason to modify the installation target. If the USB is read-only, full, absent or unsafe, note that the USB copy was not made; **keep displaying diagnostics and offering manual export**.
- **Target logging:** verify `/target` is the *correct* mounted installation filesystem and is writable before creating the controlled directory `/target/var/log/installer/`. Do not write to an unintended mount, mount disks speculatively, or change installation partitioning to enable logging. If the target is inaccessible, save no target copy and state this openly.
- **Full, unredacted diagnostic logs (explicitly approved):** preserve the complete available Debian Installer and custom-profile logs, APT transaction simulations/outputs, error states, decisions and exit codes **without filtering, sanitizing, redacting or selectively omitting existing diagnostic content in either automatic copy**. Never deliberately emit or collect passwords or hashes that the installer would not normally log, and never write credentials into installer scripts; nevertheless **existing logs may contain credentials or other secrets**, so do not promise they are safe to disclose. Keep complete copies on both the installed target and installer USB when safely writable, rather than producing a sanitized USB variant. Use a **root-owned, restrictive directory and file permissions (e.g., 0700 and 0600)** wherever supported; some removable filesystems cannot enforce POSIX permissions, so do not claim they can. **Always show a clear warning before exposing/exporting logs to removable storage and in the error summary** that logs may include usernames, device/network information, tokens, passwords or other sensitive material. Manual export also preserves the unredacted content with an explicit warning. Never weaken other security controls to make logging possible.
- **Always-visible diagnostics:** display a concise failure summary, the exact operation/status, an explicit **sensitive-log warning**, where each **complete** copy was saved (or why it failed), and a **manual export** option even if both automatic copies succeeded. Integrate with Debian Installer's existing **Save debug logs** capability when available; do not depend on an automatic copy succeeding.
- **Implementation gate:** test log collection before and after target mounting, on unsuccessful package/profile operations, on read-only/full USB media, and at early failures when neither persistent destination exists. Never promise log persistence if both destinations are unavailable, and never create snapshots, a system backup, or rollback logic.

## Build and release gates

- Test **full/unredacted** log persistence attempts to the **confirmed** `/target/var/log/installer/` and, independently, a **safe writable section of the same installer USB**. Verify restrictive permissions where supported, warnings where USB filesystems cannot provide them, sensitive-content warnings, and that failures do not hide on-screen diagnostics/manual export or trigger media repartitioning/formatting.

- **No installer-media verification:** as explicitly requested, do not require source-image checksum/signature checks, generated-ISO hashing, USB read-back/comparison, or a verification-only boot test. This does not change signed APT repository enforcement or the separate functional requirements of the installer.
- **Build completed; USB and runtime tests pending:** the customized ISO was generated successfully on 2026-11-15, but USB writing and functional tests of UEFI, BIOS, graphical, text and rescue modes remain pending. Do not add a separate media-integrity verification procedure.
- Test each optional profile alone and in permitted combinations, including **fail-stop behavior**, diagnostic availability and manual recovery paths. **Do not build or imply rollback functionality**.
- Test offline/failed repository behavior, third-party key checks, package resolution, root and sudo login, GRUB settings and correct target-disk selection.
- Confirm OMV does not reinstate root SSH access and does not block the installer-confirmed administrator account access.
- Test target-disk selection and destructive-operation confirmation in disposable virtual machines.
- Install Linux 7.x **in the target OS**, not necessarily in the running installer. Test the ZRAM kernel interfaces on the installed system.
- Do not call the image ready until [08_validation_and_pending.md](08_validation_and_pending.md) has been resolved.

## References

- [Simple-CDD package](https://packages.debian.org/trixie/simple-cdd)
- [Simple-CDD profiles explained](https://www.debian.org/doc/manuals/debian-handbook/sect.automated-installation.en.html)
- [Debian 13 installation manual](https://www.debian.org/releases/trixie/installmanual)
