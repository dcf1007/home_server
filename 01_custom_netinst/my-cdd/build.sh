#!/bin/sh
# Build the Debian 13 Trixie amd64 Simple-CDD project.
# The seven optional profiles must be implemented before this can build an ISO.
set -eu
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

exec build-simple-cdd --conf ./simple-cdd.conf --dist trixie
