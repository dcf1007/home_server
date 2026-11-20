#!/bin/bash
# Build the Debian 13 Trixie amd64 Simple-CDD project.
# The seven optional profiles must be implemented before this can build an ISO.
# Keep build-simple-cdd's exit status when streaming output through tee.
set -euo pipefail
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# Debian tasksel 3.81 resets tasksel/first to its own defaults when unseen.
# Preserve its ordinary editable GUI rather than pre-mark it seen (which can
# suppress the prompt). This is a visible build-time warning, not a claim that
# an installer default is applied.
printf >&2 'my-cdd: NOTE: At Software selection, manually uncheck Desktop/GNOME and check SSH server + standard utilities; tasksel ignores the custom unseen defaults.\n'

# Derive both the early boot defaults and later editable Debconf answers from
# the single canonical profile_defaults.conf. Do not modify tracked source files.
. ./profile_defaults.conf
mkdir -p ./tmp/generated
case "${AUTO_ACCEPT_FIRMWARE_LICENSES:-}" in
    true|false) ;;
    *) printf >&2 '%s\n' 'AUTO_ACCEPT_FIRMWARE_LICENSES must be true or false'; exit 1 ;;
esac
# Data only, never a sourced shell file in the installer.
printf '%s\n' "$AUTO_ACCEPT_FIRMWARE_LICENSES" > ./tmp/generated/firmware-license-policy
{
    printf '# Generated from profile_defaults.conf; questions remain editable.\n'
    printf 'd-i netcfg/get_hostname string %s\n' "$DEFAULT_HOSTNAME"
    printf 'd-i netcfg/get_hostname seen false\n'
    if [ -n "$DEFAULT_DOMAIN" ]; then
        printf 'd-i netcfg/get_domain string %s\n' "$DEFAULT_DOMAIN"
        printf 'd-i netcfg/get_domain seen false\n'
    fi
    # Intentionally suppress the initial root question; preserve native sudo setup.
    printf 'd-i passwd/root-login boolean false\n'
    printf 'd-i passwd/username string %s\n' "$DEFAULT_ADMIN_USERNAME"
    printf 'd-i passwd/username seen false\n'
    printf 'd-i clock-setup/utc boolean %s\n' "$DEFAULT_RTC_UTC"
    printf 'd-i clock-setup/utc seen false\n'
    printf 'd-i time/zone string %s\n' "$DEFAULT_TIMEZONE"
    printf 'd-i time/zone seen false\n'
    printf 'tasksel tasksel/first multiselect %s\n' "${DEFAULT_TASKSEL_TASKS//,/, }"
    printf 'tasksel tasksel/first seen false\n'
} > ./tmp/generated/defaults.preseed

# Locale and keyboard are asked before an ISO-based preseed can be loaded.
# Debian Installer's ?= boot syntax supplies a default WITHOUT hiding the UI.
build_conf=./tmp/generated/simple-cdd.conf
cp ./simple-cdd.conf "$build_conf"
printf '\n# Generated from profile_defaults.conf for early editable prompts.\nexport KERNEL_PARAMS="debian-installer/language?=%s debian-installer/country?=%s debian-installer/locale?=%s keyboard-configuration/xkb-keymap?=%s"\n' \
    "$DEFAULT_LANGUAGE" "$DEFAULT_COUNTRY" "$DEFAULT_LOCALE" "$DEFAULT_KEYBOARD_LAYOUT" >> "$build_conf"

# On repeat builds, reconcile Simple-CDD's previously generated local
# udeb mirror configuration so the normal mirror/build steps can run again.
mirror_conf=./tmp/mirror/conf/distributions
if [ -d ./tmp/mirror/db ] && [ -f "$mirror_conf" ]; then
    sed -i 's/^UDebComponents: main contrib non-free-firmware$/UDebComponents: main/' "$mirror_conf"
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
    sed -i 's/^UDebComponents: main$/UDebComponents: main contrib non-free-firmware/' "$mirror_conf"
    GNUPGHOME="$PWD/tmp/gpg-keyring" reprepro -V --basedir "$PWD/tmp/mirror" update

    build-simple-cdd \
        --conf "$build_conf" \
        --dist trixie \
        --build-only \
        --debug \
        --logfile ./build-debug.log

} 2>&1 | tee ./build-terminal.log
