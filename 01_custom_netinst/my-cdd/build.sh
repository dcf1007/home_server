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

# Simple-CDD's reprepro mirror otherwise limits installer udebs to main,
# while Debian-CD also checks contrib and non-free-firmware udeb indexes.
{
    build-simple-cdd \
        --conf ./simple-cdd.conf \
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
        --conf ./simple-cdd.conf \
        --dist trixie \
        --build-only \
        --debug \
        --logfile ./build-debug.log
} 2>&1 | tee ./build-terminal.log
