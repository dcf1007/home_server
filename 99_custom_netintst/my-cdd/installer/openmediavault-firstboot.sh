#!/bin/sh
# Official OMV initialization on the first real systemd boot, then self-delete.
# Only the root-readable log is retained; never retry the OMV commands.
set -eu
umask 077

SERVICE=my-cdd-omv-firstboot.service
UNIT=/etc/systemd/system/my-cdd-omv-firstboot.service
LINK=/etc/systemd/system/multi-user.target.wants/my-cdd-omv-firstboot.service
SCRIPT=/usr/local/sbin/my-cdd-omv-firstboot.sh
LOG=/var/log/installer/my-cdd-omv-firstboot.log
step='preparing first-boot initialization'

mkdir -p /var/log/installer

cleanup() {
    cleanup_rc=0
    # Do not stop the running service: disable, never disable --now.
    if ! systemctl disable "$SERVICE" >> "$LOG" 2>&1; then
        printf '%s\n' 'WARNING: systemctl disable failed; removing the link directly' >> "$LOG" || :
    fi
    for file in "$LINK" "$UNIT" "$SCRIPT"; do
        if ! rm -f -- "$file" >> "$LOG" 2>&1; then
            printf 'CLEANUP FAILED: %s\n' "$file" >> "$LOG" || :
            cleanup_rc=1
        fi
    done
    if ! systemctl daemon-reload >> "$LOG" 2>&1; then
        printf '%s\n' 'CLEANUP FAILED: systemctl daemon-reload' >> "$LOG" || :
        cleanup_rc=1
    fi
    return "$cleanup_rc"
}

finish() {
    rc=$1
    trap - 0 HUP INT TERM
    if [ "$rc" -eq 0 ]; then
        printf '%s\n' 'RESULT: COMPLETE (both OMV commands succeeded)' >> "$LOG" || :
        printf '%s\n' 'OpenMediaVault first-boot initialization completed successfully.'
    else
        printf 'RESULT: FAILED; command=%s; exit_status=%s\n' \
            "$step" "$rc" >> "$LOG" || :
        printf >&2 'OpenMediaVault initialization FAILED: %s (exit %s).\n' "$step" "$rc" || :
        printf >&2 'Details: %s\n' "$LOG" || :
    fi

    # Perform the same cleanup on success and failure.
    # Keep the log so the reason for failure survives self-removal.
    if ! cleanup; then
        printf >&2 'OMV first-boot cleanup FAILED; see %s\n' "$LOG" || :
        [ "$rc" -ne 0 ] || rc=1
    fi
    exit "$rc"
}

# If a previous attempt was interrupted before cleanup, leave its log
# intact and clean up ONLY. Never rerun either OMV command.
if [ -e "$LOG" ]; then
    if grep -q '^RESULT: ' "$LOG"; then
        printf '%s\n' 'RECOVERY: removing leftover one-time service files; OMV commands not rerun.' >> "$LOG" || :
    else
        printf '%s\n' 'RESULT: INTERRUPTED; previous attempt did not finish; OMV commands not rerun.' >> "$LOG" || :
    fi
    printf 'Prior OMV attempt detected. Cleaning up without rerunning. Log: %s\n' "$LOG"
    cleanup
    exit $?
fi

# The log is the sole durable attempt record; create it before any OMV command.
# noclobber makes creation exclusive even if called outside systemd.
if ! (set -C; : > "$LOG") 2>/dev/null; then
    printf >&2 'Cannot create OMV attempt log: %s\n' "$LOG"
    exit 1
fi
printf '%s\n' 'STARTED: one-time OMV first-boot initialization' >> "$LOG"
# Flush the attempt record before making changes to minimize reboot replay risk.
sync "$LOG" || :

trap 'finish "$?"' 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

run_step() {
    step=$1
    shift
    printf 'RUNNING: %s\n' "$step" >> "$LOG"
    printf 'RUNNING: %s\n' "$step"
    "$@" >> "$LOG" 2>&1
    printf 'COMPLETED: %s\n' "$step" >> "$LOG"
    printf 'COMPLETED: %s\n' "$step"
}

# Exactly the two upstream install.sh initialization commands, unchanged.
run_step 'omv-confdbadm populate' omv-confdbadm populate
run_step 'omv-salt deploy run hosts' omv-salt deploy run hosts
