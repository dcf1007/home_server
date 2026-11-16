# 01 — Build the Simple-CDD project and its custom ISO

**What you are constructing:** a Debian 13 (Trixie) amd64 netinst ISO containing the **unmodified Debian Installer**, seven selectable Simple-CDD profiles, staged installer-side shell modules, and the minimal extra udebs those modules require.

This is a **source/build guide**. For the corresponding normal Debian installation process, see [01 — Base Debian](../01_base_debian/README.md).

## Step 1 — Prepare the build host

Use a Debian machine or VM with network access and disk space for the local mirror. Refresh APT package indexes (no packages upgraded yet):

~~~sh
sudo apt update
~~~

Install Git (source checkout), Simple-CDD (ISO generation) and reprepro (local mirror indexes). Review APT's proposed changes:

~~~sh
sudo apt install git simple-cdd reprepro
~~~

Obtain the current project source:

~~~sh
git clone https://github.com/dcf1007/home_server.git
~~~

Enter its actual build root; all following paths are relative to this directory:

~~~sh
cd home_server/99_custom_netintst/my-cdd
~~~

If you already have a checkout, update it in the normal way rather than cloning a second copy.

## Step 2 — Construct simple-cdd.conf

Open `simple-cdd.conf`. Use Debian 13 Trixie and amd64 and make the seven features *available*, not *preselected*. These are the important project settings:

~~~sh
profiles="backports ensure-7x-kernel extended-device-support zram-writeback debian-tweaks openmediavault docker"
auto_profiles=""
default_profiles=""
build_profiles="installer-media"
CODENAME="trixie"
ARCH="amd64"
INSTALLER_CD="2"
~~~

**Why:** `profiles` generates choices; `auto_profiles` and `default_profiles` would silently alter those choices. `INSTALLER_CD="2"` includes the base Debian system. The build-only `installer-media` group is for packages needed during installation, not an eighth checkbox. The complete file also fixes mirror components, firmware, boot timeout and distribution.

Do **not** shadow upstream Simple-CDD `profiles/default.downloads`, `default.udebs` or `default.packages`. The build script rejects such overrides so the normal Debian Installer continues to have its standard tools.

## Step 3 — Describe the optional choices

In `profiles/`, create one `<name>.description` per choice and one `<name>.extra` per profile, following [00 — Profile construction](00_profile_construction.md). These source assets are copied to `/cdrom/simple-cdd` inside the booted image.

Use `profiles/default.extra` for shared inputs such as:

~~~text
tmp/generated/defaults.preseed
installer/profile-confirm.sh
installer/profile-confirm.templates
installer/ordered-selection.sh
installer/run-selected.sh
installer/profile-common.sh
installer/15my-cdd-status
~~~

Use individual `.extra` files for optional modules, such as `installer/profile-backports.sh` and the signed Backports template. Merely staging a script must not run it.

## Step 4 — Preserve Debian's normal dialogs

Do not write a custom disk-partitioning or user-creation wizard. The normal installer already asks for disk layout, network, accounts, language, mirror and tasksel choices.

Create the single editable source `profile_defaults.conf`. Its variables include sample hostname, admin username, locale, Spanish keyboard, Germany, Europe/Berlin, DHCP and headless tasksel choices. **No passwords, disk paths or auto-selected optional profiles belong here.**

The `build.sh` renderer creates `tmp/generated/defaults.preseed` for later normal questions and adds early locale/keyboard `?=` defaults to the generated Simple-CDD configuration. A typical generated editability pair is:

~~~text
d-i netcfg/get_hostname string example-host
d-i netcfg/get_hostname seen false
~~~

The word `example-host` is explanatory; the real build substitutes the chosen source value. The `seen false` value is intended to keep the question editable. **Tasksel's own logic may reset defaults**, so the build prints a warning to inspect headless/SSH choices manually.

## Step 5 — Hook the custom profiles into unmodified Debian Installer

Edit `profiles/default.preseed` to include the generated defaults and connect *two* installer hooks:

~~~text
d-i preseed/include string defaults.preseed
d-i preseed/early_command string /bin/sh /cdrom/simple-cdd/profile-confirm.sh && anna-install simple-cdd-profiles
d-i apt-setup/disable-cdrom-entries boolean true
d-i preseed/late_command string /bin/sh /cdrom/simple-cdd/run-selected.sh
~~~

The **early** hook loads the real Simple-CDD choices and asks for a default-No summary confirmation **before** the upstream Simple-CDD profile udeb is loaded. The **late** hook applies only the approved profiles after Debian has prepared `/target`. The finish-install status hook prevents a misleading success message after a failure.

Building those three scripts and their integration is explained in [05 — Base installer framework](05_base_installation.md). Don't patch the upstream Debian Installer udeb.

## Step 6 — Stage installer-only native packages

Add the following to `profiles/installer-media.udebs`:

~~~text
parted-udeb
util-linux-udeb
~~~

They provide native GPT editing and probing needed by [03 — ZRAM](03_zram_writeback.md). Add `zstd` to `profiles/installer-media.downloads`; the current build retains it as a base-installer media prerequisite. These are **build inputs**, not selectable user profiles, and cannot simply be replaced by installed-target `.deb` binaries.

## Step 7 — Implement the two-stage build.sh

The current `build.sh` is a guarded Bash build entry point. Its important phases are:

1. Check upstream default profiles, executable postinst hooks, every profile's POSIX shell syntax, and the build-only package lists.
2. Render user-editable preseed suggestions from `profile_defaults.conf`.
3. Build the local Trixie mirror with `build-simple-cdd --mirror-only`.
4. In the *generated local* reprepro configuration only, extend `UDebComponents` from `main` to `main contrib non-free-firmware`, refresh the local indexes, then build with `build-simple-cdd --build-only`.
5. Verify the generated ISO staging tree actually contains `zstd` and `parted-udeb`/`util-linux-udeb` **in indexes and package pools**.
6. Compare staged `/simple-cdd` assets byte for byte with every `profiles/*.extra` source and check that the entry-point scripts are executable.

**Why two stages?** Simple-CDD's initial mirror generation starts with installer udebs from `main`; building immediately can omit firmware-component udeb indexes. The explicit second local-index stage repairs this without overwriting upstream installer files.

This is the actual structure of the build command invocations:

~~~sh
build-simple-cdd --conf "$build_conf" --dist trixie --mirror-only --debug --logfile ./build-mirror-debug.log
~~~

~~~sh
build-simple-cdd --conf "$build_conf" --dist trixie --build-only --debug --logfile ./build-debug.log
~~~

These are **source excerpts**, not substitute commands for users to run alone. The build wrapper creates `$build_conf`, updates the local mirror and performs checks between them. **Run the wrapper** for a real build.

## Step 8 — Validate syntax and make the ISO

You can parse the main dispatcher for syntax errors without executing it:

~~~sh
sh -n installer/run-selected.sh
~~~

The same check must be run on every profile module and completion verifier; the wrapper does this automatically.

Now run the complete build process:

~~~sh
./build.sh
~~~

A successful run should produce `images/debian-13-amd64-CD-1.iso`. Read `build-terminal.log`, `build-mirror-debug.log` and `build-debug.log` if the process fails. **The source exists but this refactor did not build an ISO.**

## Step 9 — Validate the result, not just the files

Boot the ISO in a throwaway VM and follow [08 — Validation](08_validation_and_pending.md). Verify early checkbox/summary dialogs, standard Debian disk/tasksel screens, selected-only operations, cancellations, finish-install status and first boot. Build checks cannot confirm installer-native `anna-install`, Debconf, GPT operations or OMV/Docker service behavior.

**Implementation:** [build.sh](my-cdd/build.sh), [simple-cdd.conf](my-cdd/simple-cdd.conf), [profiles](my-cdd/profiles/), [installer defaults](my-cdd/profile_defaults.conf).
