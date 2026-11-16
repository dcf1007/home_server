# 01 — Recreate the Simple-CDD build project

**Outcome:** a working *build project* for Debian 13 amd64 containing the complete source of `simple-cdd.conf`, editable installer defaults and the guarded two-stage `build.sh`. This does **not** yet include the per-feature implementation; those are constructed in [00](profile_construction.md), [05](installer_framework.md) and the feature chapters.

## Step 1 — Prepare a Debian build computer

You need a Debian machine or VM with Internet access and enough free disk for a temporary Debian repository and an ISO. **Do not do this on the NAS disk you intend to install onto.**

~~~sh
sudo apt update
~~~

This downloads the latest Debian package indexes; it installs nothing.

~~~sh
sudo apt install git simple-cdd reprepro nano
~~~

This installs the Git client, the Simple-CDD ISO builder, the reprepro repository tool and the `nano` text editor used below. Read APT's proposed changes before accepting.

Choose **one** way to obtain a `home_server` working directory:

**Option A — Start from the existing reference project.** Clone it so you can work on one profile while the shared framework and other profiles remain available:

~~~sh
git clone https://github.com/dcf1007/home_server.git
~~~

This downloads the existing source. It does not install or run any NAS software. Use a separate test branch or working copy for your reconstruction.

**Option B — Rebuild everything from an empty directory.** Make a new source directory (do this **instead of**, not after, cloning it):

~~~sh
mkdir home_server
~~~

This creates an empty local folder. If you choose Option B, you must follow **all** base/framework and feature chapters; the shipped `simple-cdd.conf` expects seven optional profiles.

## Step 2 — Make the source tree

Enter the `home_server` directory created by **whichever option** you selected:

~~~sh
cd home_server
~~~

This changes only your terminal's working directory.

Create the source folder inside it:

~~~sh
mkdir -p 99_custom_netintst/my-cdd/profiles
~~~

This creates the source directories only; it does not start Simple-CDD.

Enter the project's build root:

~~~sh
cd 99_custom_netintst/my-cdd
~~~

Run this from the root of the `home_server` checkout, not from inside another `my-cdd` directory.

## Step 3 — Create these exact source files

| File | Why it is needed |
| --- | --- |
| `simple-cdd.conf` | Select Debian 13/Trixie, architecture, allowed profile IDs and separate build-only media inputs. |
| `profile_defaults.conf` | Keep editable locale, keyboard, network and account *suggestions* in one place. Never put passwords or disk selections here. |
| `build.sh` | Validate inputs and sources, generate preseed defaults, populate the two-stage mirror, build the ISO and verify package/media contents. |
| `profiles/installer-media.downloads` | Put regular `zstd` in the build-only media package list. |
| `profiles/installer-media.udebs` | Include native `parted-udeb` and `util-linux-udeb` for installer-side GPT work. |
| `.gitignore` | Avoid checking in generated build logs, images and temporary files. |

For **each file**, open it in an editor (`nano simple-cdd.conf`, then `nano profile_defaults.conf`, and so on), paste the **entire matching file listing** below, save, and close. Do not use abbreviated snippets from earlier versions of this guide: some were missing build guards.

Make the build entry point executable:

~~~sh
chmod +x build.sh
~~~

This changes file permission only, so `./build.sh` can run later.

## Step 4 — Know why the pieces fit

`simple-cdd.conf` offers seven optional features but starts none automatically. `build_profiles="installer-media"` is a separate *build input*, not another checkbox. `profile_defaults.conf` specifies suggestions for ordinary Debian Installer screens, not answers that suppress those screens.

The build wrapper runs **mirror-only** first, adjusts only its **generated local mirror** to include the installer udebs from required components, then runs **build-only**. Its source and ISO checks prevent reporting a successful build when key scripts or packages were omitted.

The project also depends on the official Simple-CDD `default.*` profile files. **Do not create local files named** `profiles/default.downloads`, `profiles/default.udebs` or `profiles/default.packages`; the wrapper explicitly refuses to shadow upstream ones.

## Step 5 — Check your build entry point

~~~sh
bash -n build.sh
~~~

This checks Bash syntax without running the builder. **Do not run `./build.sh` yet if you have not created** the common installer files and feature modules: its checks will stop on missing source.

**Next:** [00 — Shared profile code](profile_construction.md), then [05 — Installer hooks and dispatcher](installer_framework.md), then one or more feature guides. When all media manifests and modules exist, run `./build.sh` from `my-cdd` and test the ISO in a disposable VM.

## Complete, copyable source files

Expand the file you want to create. **These are full files, not fragments.** Copy the contents between the code fences into the **exact path named in the heading**. After saving, use `git hash-object <path>` to calculate that file's Git blob SHA and compare it with the original SHA shown in the heading; a match proves a byte-for-byte copy. The command reads the file but makes no edits.


<details>
<summary><strong>Complete file: simple-cdd.conf</strong> (46 lines, original Git blob <code>64898be0b980c4d401af0c7607092cddc3f179d9</code>)</summary>

````text
# my-cdd Simple-CDD 0.6.9 build configuration for Debian 13 Trixie, amd64.
# Source: ../build_project.md and Debian Simple-CDD 0.6.9 variables.py
# Status: source configuration; not evidence of a validated ISO.
#
# These are INCLUDED / OFFERED profiles, NOT AUTO-SELECTED profiles.
profiles="backports ensure-7x-kernel extended-device-support zram-writeback debian-tweaks openmediavault docker"
auto_profiles=""
default_profiles=""
# Build-only media packages; never offered or auto-selected in the installer.
# Preserve upstream /usr/share/simple-cdd/profiles/default.downloads unchanged.
build_profiles="installer-media"

# Fixed target distribution and architecture; build-simple-cdd called with
# --dist trixie by build.sh. Do not take distribution from a newer build host.
CODENAME="trixie"
ARCH="amd64"
ARCHES="amd64"

# Netinst: include Debian Installer AND the base system; retrieve additional
# packages from the configured network mirror. INSTALLER_CD=1 omitted the base.
INSTALLER_CD="2"

# Debian 13 binary components. Backports is enabled only by its selected
# installed-target profile; this build setting does NOT enable it there.
mirror_components="main contrib non-free non-free-firmware"
# Debian-CD firmware component for installer media (not the package mirror).
export NONFREE_COMPONENTS="non-free-firmware"
debian_mirror="https://deb.debian.org/debian/"
updates_mirror="https://deb.debian.org/debian/"
security_mirror="https://security.debian.org/debian-security/"

# Supplementary ISO files, including rendered defaults.preseed, are listed in profiles/default.extra.
# Simple-CDD resolves its relative entries to absolute project paths before
# changing to the debian-cd working directory. Relative paths in all_extras
# would be silently skipped. The upstream simple-cdd-profiles udeb is unchanged.
# Runtime viability of the early GTK/text Debconf hook remains UNTESTED.

# build.sh derives editable boot and preseed defaults from profile_defaults.conf.
# No secret, disk target, or automatic profile selection is set here.
# Simple-CDD supplies its own required default.preseed boot reference.
#
# A zero boot timeout is the intended indefinite wait; validate the actual
# generated GRUB and ISOLINUX menus before allowing an installable image.
BOOT_TIMEOUT="0"
# Do not set proposed_updates, global Backports pins, auto_profiles or
# unapproved third-party package repositories.
````

</details>


<details>
<summary><strong>Complete file: profile_defaults.conf</strong> (46 lines, original Git blob <code>935cdf9d65372ebf9a683f11a36fe57a8fe117cf</code>)</summary>

````text
# profile_defaults.conf — Debian 13 Simple-CDD installation GUI suggested values
# Updated: 2026-11-15
# Provenance: user request to move all normal setup-GUI settings out of
# Debian tweaks into profile_defaults.conf; earlier user-approved defaults.
#
# This is the canonical BUILD INPUT for installer defaults, not itself
# a Debian Installer preseed file. build.sh converts it into:
#   tmp/generated/defaults.preseed (later editable Debconf questions)
#   tmp/generated/simple-cdd.conf (early locale/keyboard boot defaults)
# Both files are generated during each build; edit values HERE, not the outputs.
# Boot defaults use ?= and preseed defaults reset "seen" to false, preserving
# normal Debian Installer questions for the user to confirm or change.
# Runtime GUI/text behavior remains to be validated in a fresh ISO install.
#
# Never put user/root passwords, password hashes, hard-coded disk targets,
# or silent profile-selection flags in this file.

# Identity: initial editable suggestions, NOT fixed identifiers.
DEFAULT_HOSTNAME="dcf1007-server"
DEFAULT_ADMIN_USERNAME="david"
DEFAULT_DOMAIN="dcf1007-world"

# Localization/clock: values shown/confirmed in normal installer questions.
DEFAULT_LANGUAGE="en"
DEFAULT_COUNTRY="DE"
DEFAULT_LOCALE="en_US.UTF-8"
DEFAULT_KEYBOARD_LAYOUT="es"
DEFAULT_KEYBOARD_VARIANT=""  # Non-empty variant not supported by renderer yet
DEFAULT_TIMEZONE="Europe/Berlin"
DEFAULT_RTC_UTC="true"

# Installer networking and software-selection defaults.
# DHCP is left to Debian Installer's native setup. The build currently
# supports DHCP mode only; a static setting fails validation rather than being
# silently ignored. Any installer prompt must remain editable.
DEFAULT_NETWORK_METHOD="dhcp"
# Rendered into tasksel/first with its Debconf seen flag reset.
# Minimal/headless system: SSH server + Standard system utilities, no desktop.
DEFAULT_TASKSEL_TASKS="ssh-server,standard"

# Non-GUI policies stay in the appropriate selected profiles (e.g. GRUB,
# Debian tweaks' non-default mount/boot and update-policy changes;
# Extended device support supplies CPU microcode and additional firmware).
# Profile checkboxes themselves are ALL unchecked by default; do not hard-code
# selections or automatically add dependencies here.
# Time synchronization: keep Debian's native installed package/installer defaults.
````

</details>


<details>
<summary><strong>Complete file: build.sh</strong> (245 lines, original Git blob <code>65372c3ab5629006493032bf913ed0d814c8a903</code>)</summary>

````sh
#!/bin/bash
# Build the Debian 13 Trixie amd64 Simple-CDD project.
# The seven optional profiles must be implemented before this can build an ISO.
# Keep build-simple-cdd's exit status when streaming output through tee.
set -euo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# In Simple-CDD 0.6.9 the first matching profile file wins. Let the
# upstream default.downloads and default.udebs lists be used intact.
for name in default.downloads default.udebs default.packages; do
    [ ! -e "./profiles/$name" ] || {
        printf >&2 'my-cdd: local profiles/%s shadows upstream defaults.\n' "$name"
        exit 1
    }
    [ -r "/usr/share/simple-cdd/profiles/$name" ] || {
        printf >&2 'my-cdd: missing upstream Simple-CDD profile: %s\n' "$name"
        exit 1
    }
done
# Keep zstd in the ISO package pool and installer-native parted/blkid
# in the udeb pool. All belong to the existing build-only profile; never
# shadow upstream default.* lists or add a selectable installer profile.
[ "$(grep -xc 'zstd' ./profiles/installer-media.downloads)" -eq 1 ] &&
[ "$(grep -xc 'parted-udeb' ./profiles/installer-media.udebs)" -eq 1 ] &&
[ "$(grep -xc 'util-linux-udeb' ./profiles/installer-media.udebs)" -eq 1 ] &&
[ "$(grep -Fxc 'build_profiles="installer-media"' ./simple-cdd.conf)" -eq 1 ] || {
    printf >&2 'my-cdd: build-only installer-media zstd/parted/blkid inputs are misconfigured.\n'
    exit 1
}

# Fail before a costly mirror/ISO build if any installer entry point or
# sourced profile module has invalid POSIX-shell syntax.
for script in installer/*.sh profiles/*.postinst; do
    sh -n "$script" || {
        printf >&2 'my-cdd: invalid shell syntax: %s\n' "$script"
        exit 1
    }
done
# The finish-install status guard is intentionally named for the native
# numbered hook order, not with a .sh suffix.
sh -n installer/15my-cdd-status || {
    printf >&2 'my-cdd: invalid finish-install status-hook syntax\n'
    exit 1
}

# Debian tasksel 3.81 resets tasksel/first to its own defaults when unseen.
# Preserve its ordinary editable GUI rather than pre-mark it seen (which can
# suppress the prompt). This is a visible build-time warning, not a claim that
# an installer default is applied.
printf >&2 'my-cdd: NOTE: At Software selection, manually uncheck Desktop/GNOME and check SSH server + standard utilities; tasksel ignores the custom unseen defaults.\n'

# Never generate an apparently installable image containing unfinished hooks.
for hook in profiles/*.postinst; do
    [ -f "$hook" ] || continue
    if grep -q '^# Fail-closed placeholder' "$hook"; then
        printf >&2 'my-cdd: %s is not implemented; ISO build stopped.\n' "$hook"
        exit 1
    fi
    [ -x "$hook" ] || {
        printf >&2 'my-cdd: %s must be executable in Git; ISO build stopped.\n' "$hook"
        exit 1
    }
done

# Derive both the early boot defaults and later editable Debconf answers from
# the single canonical profile_defaults.conf. Do not modify tracked source files.
. ./profile_defaults.conf
for key in DEFAULT_HOSTNAME DEFAULT_ADMIN_USERNAME DEFAULT_LANGUAGE DEFAULT_COUNTRY DEFAULT_LOCALE \
           DEFAULT_KEYBOARD_LAYOUT DEFAULT_KEYBOARD_VARIANT DEFAULT_TIMEZONE \
           DEFAULT_RTC_UTC DEFAULT_NETWORK_METHOD DEFAULT_TASKSEL_TASKS DEFAULT_DOMAIN; do
    [ "${!key+x}" = x ] || { printf >&2 'my-cdd: unset default %s\n' "$key"; exit 1; }
done
[[ "$DEFAULT_HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] &&
[[ "$DEFAULT_ADMIN_USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] &&
[[ "$DEFAULT_LANGUAGE" =~ ^[a-z]{2}$ ]] &&
[[ "$DEFAULT_COUNTRY" =~ ^[A-Z]{2}$ ]] &&
[[ "$DEFAULT_LOCALE" =~ ^[a-z]{2}_[A-Z]{2}\.UTF-8$ ]] &&
[[ "$DEFAULT_KEYBOARD_LAYOUT" =~ ^[a-z]{2}$ ]] &&
[[ -z "$DEFAULT_KEYBOARD_VARIANT" ]] &&
[[ "$DEFAULT_TIMEZONE" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)+$ ]] &&
[[ "$DEFAULT_RTC_UTC" == true || "$DEFAULT_RTC_UTC" == false ]] &&
[[ "$DEFAULT_NETWORK_METHOD" == dhcp ]] &&
[[ "$DEFAULT_TASKSEL_TASKS" =~ ^[a-z0-9-]+(,[a-z0-9-]+)*$ ]] &&
[[ -z "$DEFAULT_DOMAIN" || "$DEFAULT_DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || {
    printf >&2 'my-cdd: invalid installer defaults (or unsupported keyboard variant/network mode)\n'
    exit 1
}
[ "$DEFAULT_LANGUAGE" = "${DEFAULT_LOCALE%%_*}" ] || {
    printf >&2 'my-cdd: language and locale do not agree\n'
    exit 1
}
mkdir -p ./tmp/generated
{
    printf '# Generated from profile_defaults.conf; questions remain editable.\n'
    printf 'd-i netcfg/get_hostname string %s\n' "$DEFAULT_HOSTNAME"
    printf 'd-i netcfg/get_hostname seen false\n'
    if [ -n "$DEFAULT_DOMAIN" ]; then
        printf 'd-i netcfg/get_domain string %s\n' "$DEFAULT_DOMAIN"
        printf 'd-i netcfg/get_domain seen false\n'
    fi
    printf 'd-i passwd/username string %s\n' "$DEFAULT_ADMIN_USERNAME"
    printf 'd-i passwd/username seen false\n'
    printf 'd-i clock-setup/utc boolean %s\n' "$DEFAULT_RTC_UTC"
    printf 'd-i clock-setup/utc seen false\n'
    printf 'd-i time/zone string %s\n' "$DEFAULT_TIMEZONE"
    printf 'd-i time/zone seen false\n'
    printf 'tasksel tasksel/first multiselect %s\n' "${DEFAULT_TASKSEL_TASKS//,/, }"
    printf 'tasksel tasksel/first seen false\n'
} > ./tmp/generated/defaults.preseed
debconf-set-selections --checkonly ./tmp/generated/defaults.preseed

# Locale and keyboard are asked before an ISO-based preseed can be loaded.
# Debian Installer's ?= boot syntax supplies a default WITHOUT hiding the UI.
build_conf=./tmp/generated/simple-cdd.conf
cp ./simple-cdd.conf "$build_conf"
printf '\n# Generated from profile_defaults.conf for early editable prompts.\nexport KERNEL_PARAMS="debian-installer/language?=%s debian-installer/country?=%s debian-installer/locale?=%s keyboard-configuration/xkb-keymap?=%s"\n' \
    "$DEFAULT_LANGUAGE" "$DEFAULT_COUNTRY" "$DEFAULT_LOCALE" "$DEFAULT_KEYBOARD_LAYOUT" >> "$build_conf"

# On repeat builds, the previous run leaves contrib/non-free-firmware udeb
# targets in the local reprepro database. The first Simple-CDD mirror stage
# starts from UDebComponents: main, so reconcile stale targets before it runs.
# Restrict all changes to the generated local mirror; preserve its package cache.
mirror_conf=./tmp/mirror/conf/distributions
if [ -d ./tmp/mirror/db ]; then
    [ -f "$mirror_conf" ] || {
        printf >&2 'my-cdd: mirror database exists without conf/distributions; stop.\n'
        exit 1
    }
    if grep -qx 'UDebComponents: main contrib non-free-firmware' "$mirror_conf"; then
        sed -i 's/^UDebComponents: main contrib non-free-firmware$/UDebComponents: main/' "$mirror_conf"
    fi
    [ "$(grep -cx 'UDebComponents: main' "$mirror_conf")" -eq 1 ] || {
        printf >&2 'my-cdd: unexpected local mirror components; not cleaning.\n'
        exit 1
    }
    GNUPGHOME="$PWD/tmp/gpg-keyring" \
        reprepro -V --basedir "$PWD/tmp/mirror" --delete clearvanished
fi

# Simple-CDD's generated mirror initially limits installer udebs to main.
# Mirror first, then extend that local mirror with the component indexes
# needed by debian-cd, and finally build the netinst ISO.
{
    build-simple-cdd \
        --conf "$build_conf" \
        --dist trixie \
        --mirror-only \
        --debug \
        --logfile ./build-mirror-debug.log

    mirror_conf=./tmp/mirror/conf/distributions
    if [ ! -f "$mirror_conf" ] || [ "$(grep -cx 'UDebComponents: main' "$mirror_conf")" -ne 1 ]; then
        printf >&2 'my-cdd: unexpected reprepro UDebComponents configuration; refusing to modify.\n'
        exit 1
    fi
    sed -i 's/^UDebComponents: main$/UDebComponents: main contrib non-free-firmware/' "$mirror_conf"
    GNUPGHOME="$PWD/tmp/gpg-keyring" reprepro -V --basedir "$PWD/tmp/mirror" update

    for component in contrib non-free-firmware; do
        index_dir="$PWD/tmp/mirror/dists/trixie/$component/debian-installer/binary-amd64"
        if [ ! -f "$index_dir/Packages.gz" ] && [ ! -f "$index_dir/Packages.xz" ]; then
            printf >&2 'my-cdd: missing Debian Installer package index after mirror update: %s\n' "$component"
            exit 1
        fi
    done

    build-simple-cdd \
        --conf "$build_conf" \
        --dist trixie \
        --build-only \
        --debug \
        --logfile ./build-debug.log

    # Debian-CD's base-installable check did not catch zstd: base-installer
    # installs it while APT can still see only the CD. Check both the on-CD
    # package index entry and the referenced .deb before declaring success.
    cd1_dir="$PWD/tmp/cd-build/trixie/CD1"
    binary_index="$cd1_dir/dists/trixie/main/binary-amd64/Packages.gz"
    [ -s "$binary_index" ] || {
        printf >&2 'my-cdd: ISO main package index missing: %s\n' "$binary_index"
        exit 1
    }
    zstd_path="$(gzip -cd "$binary_index" | awk '
        /^Package: / { selected = ($2 == "zstd") }
        selected && /^Filename: / { print $2; selected = 0 }
    ')"
    if [ -z "$zstd_path" ] || [ ! -s "$cd1_dir/$zstd_path" ]; then
        printf >&2 'my-cdd: base-installer package zstd absent from ISO index or pool.\n'
        exit 1
    fi

    # ZRAM loads parted-udeb and util-linux-udeb in the installer, not /target.
    # Verify the staged index and archive for both native utilities.
    udeb_index="$cd1_dir/dists/trixie/main/debian-installer/binary-amd64/Packages.gz"
    [ -s "$udeb_index" ] || {
        printf >&2 'my-cdd: main Debian Installer udeb index missing from ISO.\n'
        exit 1
    }
    for native_udeb in parted-udeb util-linux-udeb; do
        native_udeb_path="$(gzip -cd "$udeb_index" | awk -v package="$native_udeb" '
            /^Package: / { selected = ($2 == package) }
            selected && /^Filename: / { print $2; selected = 0 }
        ')"
        if [ -z "$native_udeb_path" ] || [ ! -s "$cd1_dir/$native_udeb_path" ]; then
            printf >&2 'my-cdd: %s absent from ISO installer index or pool.\n' "$native_udeb"
            exit 1
        fi
    done

    # An ISO must not be reported as ready if an early/late installer
    # script was silently omitted from its staged /simple-cdd directory.
    iso_extras_dir="$PWD/tmp/cd-build/trixie/CD1/simple-cdd"
    # All profile-specific .extra manifests are native Simple-CDD inputs.
    for manifest in profiles/*.extra; do
        [ -f "$manifest" ] || continue
        while IFS= read -r asset || [ -n "$asset" ]; do
            case "$asset" in
                ''|\#*) continue ;;
            esac
            name="${asset##*/}"
            if [ ! -f "$iso_extras_dir/$name" ] ||
               ! cmp -s "$asset" "$iso_extras_dir/$name"; then
                printf >&2 'my-cdd: missing or mismatched ISO asset in %s: %s\n' "$manifest" "$name"
                exit 1
            fi
        done < "$manifest"
    done
    [ -s "$iso_extras_dir/simple-cdd.templates" ] || {
        printf >&2 'my-cdd: generated Simple-CDD Debconf template missing from ISO tree.\n'
        exit 1
    }
    # Ensure the booted default preseed will actually load the generated values.
    [ -f "$iso_extras_dir/default.preseed" ] &&
    grep -Fqx 'd-i preseed/include string defaults.preseed' "$iso_extras_dir/default.preseed" || {
        printf >&2 'my-cdd: generated defaults are not included by default.preseed.\n'
        exit 1
    }
    # confmodule may re-execute these scripts through the cdebconf frontend.
    for script in profile-confirm.sh run-selected.sh 15my-cdd-status; do
        [ -x "$iso_extras_dir/$script" ] || {
            printf >&2 'my-cdd: entry script not executable on ISO: %s\n' "$script"
            exit 1
        }
    done
} 2>&1 | tee ./build-terminal.log
````

</details>


<details>
<summary><strong>Complete file: profiles/installer-media.downloads</strong> (4 lines, original Git blob <code>f3f73480cd2d78ea0e10e1940c4bcf808fd37168</code>)</summary>

````text
# Build-only additional media packages, not installed by Simple-CDD.
# This profile is included via build_profiles, never offered in the GUI.
# Let the unmodified upstream default.downloads supply standard installer tools.
zstd
````

</details>


<details>
<summary><strong>Complete file: profiles/installer-media.udebs</strong> (6 lines, original Git blob <code>80147f01a637a38b4fbd29a0355fb9776f0a870a</code>)</summary>

````text
# Build-only Debian Installer package. Never installed into /target.
# Official Trixie udebs supply parted for GPT editing and blkid for native
# partition probing; anna-install loads them only for selected ZRAM.
# Version-matched .udeb dependencies are resolved by native anna.
parted-udeb
util-linux-udeb
````

</details>


<details>
<summary><strong>Complete file: .gitignore</strong> (7 lines, original Git blob <code>bcd348176f87c516f9b6a0c98d6020a949aae341</code>)</summary>

````text
# Local Simple-CDD build artifacts
/images/
/tmp/
*.iso
/build-mirror-debug.log
/build-debug.log
/build-terminal.log
````

</details>
