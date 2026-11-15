# my-cdd — Debian 13 (Trixie) amd64 custom Simple-CDD sources

**Stage (2026-11-15):** the prior **installer-only** ISO built at 395 MiB but failed in a graphical installer test (first at the early command, then at debootstrap/base installation). The source now targets a **netinst ISO with the base system** and generates editable installer defaults; **neither correction is yet validated in a rebuilt ISO**. Do not use on a real installation disk. Source development began 2026-11-14.

## Entry points

- [`simple-cdd.conf`](simple-cdd.conf) — Trixie/amd64 Simple-CDD configuration; seven optional profiles, no auto-selection, `INSTALLER_CD="2"`, official Debian mirror components and `NONFREE_COMPONENTS="non-free-firmware"`. The two-stage mirror fix works with the installed Simple-CDD tooling.
- [`build.sh`](build.sh) — two-stage Simple-CDD builder that extends reprepro's generated udeb components and verifies both extra installer indexes before constructing an ISO. Saves mirror/debug/terminal logs and propagates failures with Bash `pipefail`. A successful ISO build is **not** proof of installer correctness. The wrapper renders defaults from `profile_defaults.conf` at build time.
- [`profiles/`](profiles/) — native Simple-CDD profile descriptions, empty optional auto-package queues, and seven postinst **completion verifiers**. The actual selected-profile actions run in Debian Installer's normal late-command stage.
- [`installer/`](installer/) — approved early Debconf selection/confirmation, plus [`run-selected.sh`](installer/run-selected.sh) and [`profile-actions.sh`](installer/profile-actions.sh), invoked from the normal `preseed/late_command` with the agreed ordered operations and individual confirmations. **Actual GUI/installer behavior is untested.**
- [`scripts/`](scripts/) — approved firmware package inventory, selected-only Backports and ZRAM configuration inputs, and untested ZRAM source assets.
- [`profile_defaults.conf`](profile_defaults.conf) — single editable source used by `build.sh` to generate `tmp/generated/defaults.preseed` and boot-parameter defaults; passwords, disk choices and optional-profile flags are intentionally excluded.
- [`profile_defaults.conf.example`](profile_defaults.conf.example) — original example/reference, not another source of truth.
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

The build runs `--mirror-only`, patches the **generated local mirror** from `UDebComponents: main` to `UDebComponents: main contrib non-free-firmware`, runs `reprepro update`, requires the additional installer `Packages.gz` or `Packages.xz` indexes, then runs `--build-only`. This addresses the previously observed missing `amd64/contrib` and `amd64/non-free-firmware` installer-package messages; the 2026-11-15 VM run confirmed their disappearance. It does not add extra user-selected packages or silently enable Backports.

Build diagnostics are in `build-mirror-debug.log`, `build-debug.log`, `build-terminal.log`, and `tmp/log/`. Generated, disposable files in `tmp/generated/` are rebuilt on every run. The `default.preseed` includes `defaults.preseed` from the ISO. Language/locale and keyboard use early `?=` kernel arguments so the normal screens remain editable; hostname, username, timezone, UTC clock and tasksel choices use Debconf values with `seen false`. DHCP remains the native network method and an empty DNS domain is not forced. The build validates generated preseed syntax and ISO file packaging. For exact verification commands and the known nonfatal Debian-CD warnings, see the [preparation/build guide](../01_custom_cdd_preparation.md).

**Installer asset packaging (revised after first graphical boot):** `profiles/default.extra` now lists the supplementary installer assets, including generated `defaults.preseed`. Simple-CDD resolves its relative entries against the project before switching into the Debian-CD workspace. The earlier `all_extras="installer/..."` configuration could silently omit the scripts, consistent with an early-command exit status 2 when `/cdrom/simple-cdd/profile-confirm.sh` is absent. `build.sh` now compares each source asset to the staged `tmp/cd-build/trixie/CD1/simple-cdd/` file and rejects a mismatched build. **This correction has not yet been verified by a rebuilt and booted ISO.**

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
`installer/profile-actions.sh` performs confirmed conversion. The original
`scripts/zram-generator.conf.template` remains a source template; the
selected partition's PARTUUID is instantiated into the target's
`/etc/systemd/zram-generator.conf`. Missing backing stops safely; returning
to the earlier partitioner is **not implemented** in the late-stage hook.

**Do not assume this source is ready for real-disk installation.** Native
GTK/text dynamic choices, target fstab timing, block utilities, emergency
boot dependencies and complete installer runtime behavior remain untested.
