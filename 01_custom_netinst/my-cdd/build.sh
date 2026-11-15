#!/bin/bash
# Build the Debian 13 Trixie amd64 Simple-CDD project.
# The seven optional profiles must be implemented before this can build an ISO.
# Keep build-simple-cdd's exit status when streaming output through tee.
set -euo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

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
for key in DEFAULT_HOSTNAME DEFAULT_ADMIN_USERNAME DEFAULT_LANGUAGE DEFAULT_LOCALE \
           DEFAULT_KEYBOARD_LAYOUT DEFAULT_KEYBOARD_VARIANT DEFAULT_TIMEZONE \
           DEFAULT_RTC_UTC DEFAULT_NETWORK_METHOD DEFAULT_TASKSEL_TASKS DEFAULT_DOMAIN; do
    [ "${!key+x}" = x ] || { printf >&2 'my-cdd: unset default %s\n' "$key"; exit 1; }
done
[[ "$DEFAULT_HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] &&
[[ "$DEFAULT_ADMIN_USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] &&
[[ "$DEFAULT_LANGUAGE" =~ ^[a-z]{2}$ ]] &&
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
default_country="${DEFAULT_LOCALE#*_}"
default_country="${default_country%%.*}"
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
    "$DEFAULT_LANGUAGE" "$default_country" "$DEFAULT_LOCALE" "$DEFAULT_KEYBOARD_LAYOUT" >> "$build_conf"

# A previous two-stage build leaves extra udeb targets in reprepro's database.
# Simple-CDD first recreates conf/distributions with UDebComponents: main, and
# then reprepro rejects those no-longer-configured targets. Reconcile only
# this generated mirror; keep its downloaded package cache.
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

# Simple-CDD's reprepro mirror otherwise limits installer udebs to main,
# while Debian-CD also checks contrib and non-free-firmware udeb indexes.
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

    # An ISO must not be reported as ready if an early/late installer
    # script was silently omitted from its staged /simple-cdd directory.
    iso_extras_dir="$PWD/tmp/cd-build/trixie/CD1/simple-cdd"
    while IFS= read -r asset || [ -n "$asset" ]; do
        case "$asset" in
            ''|\#*) continue ;;
        esac
        name="${asset##*/}"
        if [ ! -f "$iso_extras_dir/$name" ] ||
           ! cmp -s "$asset" "$iso_extras_dir/$name"; then
            printf >&2 'my-cdd: missing or mismatched ISO asset: %s\n' "$name"
            exit 1
        fi
    done < ./profiles/default.extra
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
    for script in profile-confirm.sh run-selected.sh; do
        [ -x "$iso_extras_dir/$script" ] || {
            printf >&2 'my-cdd: entry script not executable on ISO: %s\n' "$script"
            exit 1
        }
    done
} 2>&1 | tee ./build-terminal.log
