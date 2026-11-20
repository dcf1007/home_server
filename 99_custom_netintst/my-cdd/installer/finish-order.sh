#!/bin/sh
# Installed by the early profile gate into pre-pkgsel.d and finish-install.d.
# pkgsel 0.85 executes its hooks before tasksel; all paths are in the d-i
# ramdisk, not /target or /cdrom. finish-install 2.124 snapshots its glob
# before the first hook, so the finish-install copy only checks, never moves.
set -eu
HOOK_DIR=/usr/lib/finish-install.d
case "${0##*/}" in
    00my-cdd-order) mode=check; failure=10 ;;
    90my-cdd-order) mode=move; failure=1 ;;
    *) echo 'my-cdd: invalid hook entry point' >&2; exit 1 ;;
esac
stop() {
    logger -t my-cdd "Hook order: $*" || :
    printf >&2 'my-cdd: %s\n' "$*"
    exit "$failure"
}
exists() { [ -e "$1" ] || [ -L "$1" ]; }
pair() {
    old="$HOOK_DIR/$1"
    new="$HOOK_DIR/$2"
    if exists "$old"; then
        [ "$mode" = move ] || stop "Old native hook still exists: $old; rerun software selection before finish-install."
        [ -f "$old" ] && [ -x "$old" ] && [ ! -L "$old" ] ||
            stop "Invalid native hook: $old"
        if exists "$new"; then
            stop "Conflicting native hook destinations: $old and $new"
        fi
    else
        [ -f "$new" ] && [ -x "$new" ] && [ ! -L "$new" ] ||
            stop "Missing relocated native hook: $new"
    fi
}
# Validate all pairs before moving any of them. A later unpack/reinstall
# restoring an old filename is a hard error, not a duplicate execution.
pair 14simple-cdd 62simple-cdd
pair 15cdrom-detect 64cdrom-detect
pair 20final-message 65final-message
for required in 10apt-cdrom-setup 50config-target-network 55netcfg-copy-config 60cleanup 61my-cdd 63my-cdd-status; do
    [ -x "$HOOK_DIR/$required" ] || stop "Missing required hook: $required"
done
if [ "$mode" = move ]; then
    for mapping in 14simple-cdd:62simple-cdd 15cdrom-detect:64cdrom-detect 20final-message:65final-message; do
        old="$HOOK_DIR/${mapping%:*}"
        new="$HOOK_DIR/${mapping#*:}"
        if exists "$old"; then
            mv "$old" "$new" || stop "Cannot relocate $old"
            logger -t my-cdd "Relocated ${old##*/} to ${new##*/}" || :
        fi
    done
else
    # A second finish pass would rerun netcfg after optional dependencies
    # were installed, and may replay a destructive ZRAM operation. Stop
    # before ANY native finalization on a repeat, including Back at stage 65.
    [ ! -e /tmp/my-cdd-custom-started ] ||
        stop 'Custom finalization has already started. Do not rerun finish-install; inspect the installer log and recover manually or restart installation.'
    [ -r /cdrom/simple-cdd/run-selected.sh ] ||
        stop 'Installation media is unavailable.'
    logger -t my-cdd 'Verified native hook sequence 10, 50, 55, 60, 61, 62, 63, 64, 65' || :
fi
