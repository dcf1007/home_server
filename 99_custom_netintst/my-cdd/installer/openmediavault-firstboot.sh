#!/bin/sh
# Run official OMV initialization once on a normally booted Debian system.
# Never install packages or alter other OMV configuration policy here.
set -eu
umask 077

STATE_DIR=/var/lib/my-cdd
STATUS="$STATE_DIR/omv-firstboot.status"
ATTEMPTED="$STATE_DIR/omv-firstboot.attempted"
LOG=/var/log/installer/my-cdd-omv-firstboot.log
NOTICE=/etc/motd.d/90-my-cdd-omv

step='Preparing initialization'
mkdir -p "$STATE_DIR" /var/log/installer /etc/motd.d

# Never repeat an earlier attempt automatically, even if it failed.
if [ -e "$ATTEMPTED" ]; then
    printf '%s\n' 'OMV initialization was already attempted; no commands rerun.'
    exit 0
fi

on_failure() {
    rc=$1
    [ "$rc" -ne 0 ] || return 0
    trap - 0

    {
        printf 'FAILED\n'
        printf 'command=%s\n' "$step"
        printf 'exit_status=%s\n' "$rc"
    } > "$STATUS" || :

    {
        printf '%s\n' 'WARNING: OpenMediaVault initialization FAILED.'
        printf 'Failed step: %s\n' "$step"
        printf 'Exit status: %s\n' "$rc"
        printf '%s\n' 'The initialization will NOT retry automatically.'
        printf 'Log: %s\n' "$LOG"
        printf '%s\n' \
            'Service: systemctl status my-cdd-omv-firstboot.service'
    } > "$NOTICE" || :
    chmod 0644 "$NOTICE" || :

    printf 'FAILED: %s (exit %s)\n' "$step" "$rc" >> "$LOG" || :
    printf >&2 'ERROR: OMV initialization failed at %s (exit %s)\n' \
        "$step" "$rc" || :
    printf >&2 'Read %s for diagnostics.\n' "$LOG" || :
}

trap 'on_failure "$?"' 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'RUNNING\n' > "$STATUS"
{
    printf '%s\n' 'OpenMediaVault first-boot initialization has started.'
    printf '%s\n' \
        'If this notice persists after boot, initialization may have been interrupted.'
    printf 'Log: %s\n' "$LOG"
} > "$NOTICE"
chmod 0644 "$NOTICE"

# Set the one-time latch BEFORE either upstream command runs.
: > "$ATTEMPTED"

printf '%s\n' 'Starting OpenMediaVault first-boot initialization.' > "$LOG"
printf '%s\n' 'OpenMediaVault first-boot initialization started.'

run_step() {
    step=$1
    shift

    printf 'RUNNING: %s\n' "$step"
    printf '\nRUNNING: %s\n' "$step" >> "$LOG"

    "$@" >> "$LOG" 2>&1

    printf 'COMPLETED: %s\n' "$step"
    printf 'COMPLETED: %s\n' "$step" >> "$LOG"
}

# Exactly the two commands in OpenMediaVault's upstream install.sh.
run_step 'omv-confdbadm populate' omv-confdbadm populate
run_step 'omv-salt deploy run hosts' omv-salt deploy run hosts

step='Recording successful initialization'
printf 'COMPLETE\n' > "$STATUS"
{
    printf '%s\n' 'OpenMediaVault initialization completed successfully.'
    printf '%s\n' 'Both official initialization commands succeeded.'
    printf 'Log: %s\n' "$LOG"
} > "$NOTICE"
chmod 0644 "$NOTICE"

printf '%s\n' 'OpenMediaVault initialization COMPLETE.' >> "$LOG"
printf '%s\n' 'OpenMediaVault initialization completed successfully.'
trap - 0
exit 0
