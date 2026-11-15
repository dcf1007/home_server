#!/bin/sh
# Build-local wrapper: fix Simple-CDD's generated reprepro component list
# before its first import. The real reprepro command still does the import.
# Invoked as tmp/generated/bin/reprepro, never installed system-wide.
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
conf="$project_dir/tmp/mirror/conf/distributions"

if [ ! -f "$conf" ]; then
    printf >&2 'my-cdd: reprepro configuration not generated: %s\n' "$conf"
    exit 1
fi

# Debian 13 amd64 uses one trixie distribution. Refuse unexpected layouts
# rather than rewriting arbitrary repository definitions.
udeb_line=$(grep '^UDebComponents:' "$conf" || true)
case "$udeb_line" in
    'UDebComponents: main')
        sed -i 's/^UDebComponents: main$/UDebComponents: main contrib non-free-firmware/' "$conf"
        printf >&2 'my-cdd: enabled contrib and non-free-firmware installer indexes in local mirror\n'
        ;;
    'UDebComponents: main contrib non-free-firmware')
        ;;
    *)
        printf >&2 'my-cdd: unexpected UDebComponents value; refusing to run reprepro: %s\n' "$udeb_line"
        exit 1
        ;;
esac

exec /usr/bin/reprepro "$@"
