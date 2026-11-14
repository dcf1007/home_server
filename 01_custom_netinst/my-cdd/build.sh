#!/bin/sh
# my-cdd build entry point — never bypass the safety/integration gate.
# Run as: sh build.sh --check  (safe source preflight)
#         sh build.sh          (production build ONLY after integration gate)
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

profiles="backports ensure-7x-kernel extended-device-support zram-writeback debian-tweaks openmediavault docker"
fail() { printf >&2 'my-cdd: %s\n' "$*"; exit 1; }

[ -f simple-cdd.conf ] || fail "missing simple-cdd.conf"
[ -f profile_defaults.conf ] || fail "missing canonical profile_defaults.conf"
[ -f profiles/default.preseed ] || fail "missing default preseed"
[ -f profiles/default.udebs ] || fail "missing Simple-CDD default udeb"
case "${1:-}" in
  --check)
    for profile in $profiles; do
      [ -f "profiles/$profile.description" ] || fail "missing $profile.description"
      [ -f "profiles/$profile.packages" ] || fail "missing $profile.packages"
    done
    printf 'my-cdd: source layout is present; this is NOT installer validation.\n'
    exit 0 ;;
  '') ;;
  *) fail "usage: sh build.sh [--check]" ;;
esac

# A genuine release block, not a flag that permits untested media generation.
# The early GTK/text profile-summary gate, exact selected profile execution,
# dynamic package approval, ZRAM conversion, services and boot menu MUST
# be integrated and tested before this build may be enabled.
[ -e installer/INTEGRATION_TESTED ] || fail "UNSAFE TO BUILD: early installer integration, profile execution and boot menu have not been validated (see installer/IMPLEMENTATION_GATES.md)"
[ -e installer/FIRST_BOOT_TESTED ] || fail "UNSAFE TO BUILD: required first-boot and functional installer tests remain incomplete"
command -v build-simple-cdd >/dev/null 2>&1 || fail "simple-cdd build-simple-cdd is not installed"
command -v dpkg >/dev/null 2>&1 || fail "dpkg missing"
[ "$(id -u)" -ne 0 ] || fail "build-simple-cdd should be run as a non-root build user"

# GitHub's file-creation API stores text as non-executable; simple-cdd's
# finish-install hook executes ONLY .postinst files with the executable bit.
# Review the upstream integration AND chmod these after checkout.
for p in profiles/*.postinst; do
  [ -f "$p" ] || continue
  chmod 0755 "$p"
done

exec build-simple-cdd --conf ./simple-cdd.conf --dist trixie
