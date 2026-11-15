# my-cdd — Debian 13 (Trixie) amd64 custom Simple-CDD sources

**2026-11-15 VM failure and targeted fix:** The latest ISO successfully installed and booted base Debian after the earlier `zstd` failure. The user's graphical installer log recorded `COMMAND: in-target passwd -S root`, followed by `Unrecognized root account password state`; no optional profile ran and no completion markers were written. Debian Installer 1.155's `in-target` suppresses stdout by default; the common runner now inserts `--pass-stdout` for all captured target commands, including APT simulations and security/SSH checks. Root `chpasswd` uses direct `chroot /target /usr/sbin/chpasswd` with credentials exclusively on stdin rather than `in-target`'s Debconf-reserved stdin. A persistent `/var/log/installer/my-cdd-status` records `INCOMPLETE`, `FAILED`, or `COMPLETE`. **Source-level fix only; installer retesting required.**

**Tasksel limitation:** Debian 13 tasksel 3.81 resets `tasksel/first` to computed GNOME/desktop defaults when `seen=false`, overwriting the requested `ssh-server, standard` values. Conversely `seen=true` can suppress the native editable software-selection screen. The project preserves that native editable screen; select **SSH server** and **standard system utilities**, and deselect **Debian desktop environment** and **GNOME** manually in the next VM test. An automatic default-plus-visible-screen solution remains unresolved without more invasive tasksel integration. Do not report the displayed defaults as fixed or quietly skip the screen.


**Latest service policy:** Docker and OMV remain independent; their installed services follow vendor defaults during install and first boot. No Docker masks/disables and no automatic OMV-Extras/Compose installation. The approved OMV scheduled-update restriction now uses OMV 8's apt/apticron configuration; manual updates remain possible. Source-only; not installer-tested.

**Current review-branch policy (2026-11-15):** The unselected base uses native Debian account, privilege, SSH and update defaults **except for a mandatory recovery preflight**: a locked/passwordless root account is securely given a locally usable root password before optional profiles run (also when none are selected). `profiles/default.packages` is no longer overridden; Simple-CDD supplies the upstream list. Optional profiles have separate source modules and `.extra` manifests. The seven profile IDs are unchanged; labels have been clarified. The revised source has not been built or install-tested.

**Stage (2026-11-15):** the corrected two-stage **netinst** ISO built successfully (408 MiB, 509 packages). A graphical VM test progressed past the earlier incomplete debootstrap stage, installed `busybox`, but failed because the target's CD-only APT sources offered **no `zstd` installation candidate**. The project now **inherits Simple-CDD's full upstream `default.downloads` and `default.udebs`**, and a separate `build_profiles="installer-media"` profile adds `zstd` to the medium without automatically installing it as a profile package. `build.sh` verifies the upstream fallback and the staged ISO's `zstd` index entry and `.deb`. **This specific correction has not yet been rebuilt or tested in the installer.** The profile workflow and end-to-end install are not validated; do not use on a real installation disk. Source development began 2026-11-14.

## Entry points

- [`simple-cdd.conf`](simple-cdd.conf) — Trixie/amd64 Simple-CDD configuration; seven optional profiles, no auto-selection, `INSTALLER_CD="2"`, official Debian mirror components and `NONFREE_COMPONENTS="non-free-firmware"`. The proven two-stage mirror/index procedure has been restored; the corrected netinst ISO built, but a new `zstd` base-installation defect requires rebuilding.
- [`build.sh`](build.sh) — **two-stage Simple-CDD builder**: mirror-only, explicitly extend the generated local udeb components and run reprepro, then build-only. On repeat builds, it first reconciles stale local reprepro database targets. It verifies installer indexes, ISO assets and executable entry points, retains mirror/build/terminal logs and propagates the real exit status with Bash `pipefail`. A successful ISO build is **not** proof of installer correctness. Build-time editable defaults are rendered from `profile_defaults.conf`.
- [`profiles/`](profiles/) — native Simple-CDD profile descriptions, empty optional auto-package queues, and seven postinst **completion verifiers**. The actual selected-profile actions run in Debian Installer's normal late-command stage.
- [`installer/`](installer/) — approved early Debconf selection/confirmation, plus [`run-selected.sh`](installer/run-selected.sh), shared [`profile-common.sh`](installer/profile-common.sh) and selected-only `installer/profile-*.sh` modules, invoked from the normal `preseed/late_command` with the agreed ordered operations and individual confirmations. **Actual GUI/installer behavior is untested.**
- [`scripts/`](scripts/) — approved firmware package inventory, selected-only Backports and ZRAM configuration inputs, and untested ZRAM source assets.
- [`profiles/installer-media.downloads`](profiles/installer-media.downloads) — build-only extra ISO package list (`zstd`). The standard upstream `default.downloads` is not overridden; no extra installer checkbox is added.
- [`profile_defaults.conf`](profile_defaults.conf) — single editable source used by `build.sh` to generate `tmp/generated/defaults.preseed` and boot-parameter defaults; passwords, disk choices and optional-profile flags are intentionally excluded.
- [`SOURCE_MANIFEST.md`](SOURCE_MANIFEST.md) — creation provenance, source categories and current blocked implementation status.

## Build from a Git checkout

On a compatible Debian build host, install `git`, `simple-cdd` and `reprepro` with `apt`. To obtain the project for the first time:

```sh
cd ~/Desktop
git clone https://github.com/dcf1007/home_server.git
cd home_server/01_custom_netinst/my-cdd
./build.sh
```

On subsequent runs, update the existing checkout and build:

```sh
cd ~/Desktop/home_server
git pull --ff-only
cd 01_custom_netinst/my-cdd
./build.sh
```

The generated netinst ISO is written to `images/debian-13-amd64-CD-1.iso`. With `INSTALLER_CD="2"`, it includes Debian Installer **and the base system**, retrieving additional packages from the network. It will be **larger than the earlier 395 MiB installer-only image**.

Simple-CDD 0.6.9 generates `UDebComponents: main` even when the normal binary mirror enables additional components. The build now uses two **documented** Simple-CDD stages. After `--mirror-only`, `build.sh` updates the *generated local mirror* to `UDebComponents: main contrib non-free-firmware` and runs `reprepro update`; it checks both installer indexes before invoking `--build-only`. A guarded `reprepro --delete clearvanished` step reconciles leftover udeb targets from earlier builds. No installed package files or executable wrappers are modified. The latest two-stage netinst build successfully produced both indexes and reached graphical base installation; the `zstd` package-availability repair remains untested.

**Profile summary formatting:** the custom Debconf template uses double-indented status lines so GTK/text frontends should retain one line per profile; verify in the next ISO. **Upstream profile protection:** `build.sh` stops if a project-local `default.downloads` or `default.udebs` file would shadow Simple-CDD's built-in lists, and checks that the build-only media profile is enabled.

Build diagnostics are in `build-mirror-debug.log` (mirror stage), `build-debug.log` (ISO stage), `build-terminal.log` (combined output) and `tmp/log/` (underlying tool logs). Generated, disposable files in `tmp/generated/` are rebuilt on every run. The `default.preseed` includes `defaults.preseed` from the ISO. Language/locale and keyboard use early `?=` kernel arguments so the normal screens remain editable; hostname, username, timezone, UTC clock and tasksel choices use Debconf values with `seen false`. DHCP remains the native network method; Germany (`DE`) and domain `dcf1007-world` are editable suggestions. The build validates generated preseed syntax and ISO file packaging. It also refuses to report a successful ISO if `zstd` is missing from the staged `main` APT package index or the referenced package archive. For exact verification commands and the known nonfatal Debian-CD warnings, see the [preparation/build guide](../01_custom_cdd_preparation.md).

**Installer asset packaging (revised after first graphical boot):** `profiles/default.extra` lists common installer assets, including generated `defaults.preseed`; profile-specific assets are declared in each optional `profiles/*.extra`. Simple-CDD resolves its relative entries against the project before switching into the Debian-CD workspace. The earlier `all_extras="installer/..."` configuration could silently omit the scripts, consistent with an early-command exit status 2 when `/cdrom/simple-cdd/profile-confirm.sh` is absent. `build.sh` now checks assets from all profile-specific `.extra` manifests against the staged `tmp/cd-build/trixie/CD1/simple-cdd/` file and rejects a mismatched build. **This correction has not yet been verified by a rebuilt and booted ISO.**

## Important engineering boundaries

**Do not run an installable test image on a real OS installation disk from this tree.** Building a reliable final ISO still requires **runtime verification** of the early summary, native late-command execution, package transactions and individual approvals, safe ZRAM conversion, OMV 8 installation/network behavior, Docker daemon suppression, log export and USB boot menu. The source routines are written but must not be represented as tested or guaranteed to work.

The minimal default preseed only bootstraps Simple-CDD and deliberately leaves **normal Debian Installer prompts native** (hostname, language/locale, keyboard, time, accounts, selected OS installation disk and partitions, networking, tasksel). Canonical default suggestions have not yet been mapped to real installer Debconf questions in a tested manner. Neither the planned kernel 7.x nor its ZRAM features have been shown to be available at image-build time.

In the installed system, **both microcode packages** and broad firmware would be evaluated when Extended device support is selected. With Backports selected, targeted Backports package versions take precedence under global priority **100**; incompatible/missing firmware requires an explicitly approved individual omission, and Stable fallbacks are listed in the final APT transaction.

An ISO image **has** been produced (2026-11-15), but no successful USB boot or end-to-end installation test has been demonstrated. Follow the [preparation guide](../01_custom_cdd_preparation.md), [validation checklist](../08_validation_and_pending.md) and [implementation gates](installer/IMPLEMENTATION_GATES.md). No source-image/output-ISO hash or USB read-back/integrity-only test has been introduced.

## ZRAM backing selection (source implementation, not installer-validated)

The selected ZRAM profile now reads the installed target's `/etc/fstab` to
automatically identify its single assigned, eligible GPT swap partition,
whether newly created or reused from an older installation. If none is
uniquely assigned, a native GTK/text Debconf single-select prompt lists
verified swap and prior raw `zram-writeback` candidates with a safe
stop-without-changes default. Each selection still needs separate destructive
confirmation, plus separately approved memory-checked targeted `swapoff`
if Debian Installer has activated it. No partition is selected by its order
or by sharing a disk with the new OS.

`installer/zram-selection.sh` implements discovery, while
`installer/profile-zram.sh` performs confirmed conversion. The original
`scripts/zram-generator.conf.template` remains a source template; the
selected partition's PARTUUID is instantiated into the target's
`/etc/systemd/zram-generator.conf`. Missing backing stops safely; returning
to the earlier partitioner is **not implemented** in the late-stage hook.

**Do not assume this source is ready for real-disk installation.** Native
GTK/text dynamic choices, target fstab timing, block utilities, emergency
boot dependencies and complete installer runtime behavior remain untested.
