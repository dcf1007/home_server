#!/bin/sh
# my-cdd build entry point — source check, test image, then verified release.
# sh build.sh --check       non-destructive local source validation
# sh build.sh --test-build  create a disposable test ISO AFTER integration
# sh build.sh --release     create release ISO AFTER full functional validation
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fail() { printf >&2 'my-cdd: %s\n' "$*"; exit 1; }

command -v sh >/dev/null 2>&1 || fail "POSIX shell missing"
sh scripts/verify-source-layout.sh || fail "source layout validation failed"

# These are safe source-level checks. No APT install, GPT write, ISO or
# new user-facing policy is introduced by running them.
for script in build.sh installer/*.sh scripts/apt-simulate.sh scripts/inspect-zram-backing.sh scripts/verify-source-layout.sh profiles/*.postinst; do
  sh -n "$script" || fail "POSIX shell syntax error: $script"
done
command -v bash >/dev/null 2>&1 || fail "bash is required to syntax-check the approved ZRAM monitor source"
bash -n scripts/zram-pressure.sh || fail "Bash syntax error in extracted ZRAM monitor"
command -v python3 >/dev/null 2>&1 || fail "python3 is required by simple-cdd and source unit tests"
python3 -m unittest discover -s tests -p 'test_*.py' || fail "firmware planner offline tests failed"
sh installer/test-ordered-selection.sh || fail "profile selection source tests failed"

case "${1:-}" in
  --check)
    printf '%s\n' 'my-cdd: source checks passed; NOT evidence of working installer.'
    exit 0 ;;
  --test-build)
    # Test images must still contain all intended installer functionality
    # to exercise it meaningfully. Do not test a misleading partial image.
    [ -f installer/INTEGRATION_IMPLEMENTED ] || fail "early profile selection, custom-profile transactions and boot menu NOT IMPLEMENTED; refusing to build a misleading test ISO"
    ;;
  --release)
    [ -f installer/INTEGRATION_IMPLEMENTED ] || fail "integration not implemented"
    [ -f installer/INTEGRATION_VALIDATED ] || fail "GTK/text, package and installer integration not yet validated"
    [ -f installer/FIRST_BOOT_TESTED ] || fail "required first boot and functional tests not yet validated"
    ;;
  *) fail "usage: sh build.sh --check | --test-build | --release" ;;
esac

command -v build-simple-cdd >/dev/null 2>&1 || fail "install Debian 13 simple-cdd"
[ "$(id -u)" -ne 0 ] || fail "run the builder as a non-root user"

# The GitHub files API creates 0644 text files. Simple-CDD 0.6.9 only runs
# executable .postinst files. The integration MUST replace the current
# fail-closed placeholder hooks before setting INTEGRATION_IMPLEMENTED.
for p in profiles/*.postinst; do
  [ -f "$p" ] || continue
  chmod 0755 "$p"
done

exec build-simple-cdd --conf ./simple-cdd.conf --dist trixie
