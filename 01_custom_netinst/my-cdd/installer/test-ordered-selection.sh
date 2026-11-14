#!/bin/sh
# Safe, read-only source-level smoke tests. Not a test of GTK/Debconf or ISO.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
actual="$(sh ./ordered-selection.sh 'docker, backports, ensure-7x-kernel, extended-device-support')"
expected='backports ensure-7x-kernel extended-device-support docker'
[ "$actual" = "$expected" ] || { echo 'Profile order failure' >&2; exit 1; }
[ -z "$(sh ./ordered-selection.sh '')" ] || { echo 'Zero-selection failure' >&2; exit 1; }
if sh ./ordered-selection.sh 'zram-writeback' >/dev/null 2>&1; then
  echo 'Unapproved ZRAM dependency wrongly accepted' >&2; exit 1
fi
if sh ./ordered-selection.sh 'unknown-package' >/dev/null 2>&1; then
  echo 'Unknown profile wrongly accepted' >&2; exit 1
fi
echo 'Pure selection tests passed; installer UI still untested.'
