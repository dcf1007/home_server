#!/bin/sh
# Static policy validation, without writing to any installation disk.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "my-cdd verification failed: $*" >&2; exit 1; }
for file in simple-cdd.conf profile_defaults.conf profiles/default.preseed profiles/default.udebs installer/profile-confirm.templates; do
  [ -f "$file" ] || fail "missing $file"
done
order='backports ensure-7x-kernel extended-device-support zram-writeback debian-tweaks openmediavault docker'
grep -Fq "profiles=\"$order\"" simple-cdd.conf || fail 'incorrect profile order'
grep -Fxq 'auto_profiles=""' simple-cdd.conf || fail 'auto profiles must remain unchecked'
grep -Fxq 'default_profiles=""' simple-cdd.conf || fail 'default profile selections must be empty'
for p in $order; do
  for ext in description packages postinst; do
    [ -f "profiles/$p.$ext" ] || fail "missing $p.$ext"
  done
  # No auto queued optional packages: inspect non-comment, non-blank lines.
  if grep -Ev '^[[:space:]]*(#|$)' "profiles/$p.packages" | grep -q .; then
    fail "$p.packages queues packages before the review gate"
  fi
done
if grep -Eq 'partman/confirm |partman-auto/disk |passwd/(root|user)-password ' profiles/default.preseed; then
  fail 'default preseed contains forbidden automatic destructive/credential answers'
fi
echo 'my-cdd source layout checks passed. This is NOT a functioning installer/ISO test.'
