#!/bin/sh
# Debian Installer-side executor: native cdebconf, no patched udeb.
# Called at the existing preseed/late_command stage before 14simple-cdd.
set -eu
umask 077
MEDIA=/cdrom/simple-cdd
LOG_DIR=/target/var/log/installer
LOG="$LOG_DIR/my-cdd.log"
WORK=/tmp/my-cdd-install
CONFIRMED=/tmp/my-cdd-confirmed-profiles
mkdir -p "$WORK"
chmod 700 "$WORK"
[ -d /target/etc ] || { echo 'my-cdd: target missing' >&2; exit 1; }
mkdir -p "$LOG_DIR/my-cdd-completed"
chmod 700 "$LOG_DIR/my-cdd-completed"
touch "$LOG"
chmod 600 "$LOG"
log() { printf '%s\n' "$*" >> "$LOG"; }
capture() {
    log "COMMAND: $*"
    if "$@" > "$WORK/output" 2>&1; then rc=0; else rc=$?; fi
    cat "$WORK/output" >> "$LOG"
    return "$rc"
}
export_log() {
    # Never repartition, remount the ISO, or guess which device is the USB.
    usb=/cdrom/my-cdd-logs
    if [ -d "$usb" ] && [ -w "$usb" ]; then
        case "$(findmnt -n -o OPTIONS --target "$usb" 2>/dev/null)" in
            *rw*) cp -- "$LOG" "$usb/my-cdd.log" &&
                log "Copied log to $usb/my-cdd.log" ||
                log 'Failed to copy log to writable USB directory' ;;
            *) log 'No writable installer-USB log destination' ;;
        esac
    else
        log 'No pre-existing writable installer-USB log directory'
    fi
}
# Must load current Debian Installer's GTK or text cdebconf frontend.
. /usr/share/debconf/confmodule
review_serial=0
show_note() {
    name=$1
    file=$2
    review_serial=$((review_serial + 1))
    q="my-cdd/review-$review_serial"
    template="$WORK/review-$review_serial.templates"
    {
        printf 'Template: %s\nType: note\nDescription: %s\n' "$q" "$name"
        while IFS= read -r line || [ -n "$line" ]; do
            if [ -z "$line" ]; then echo ' .'; else printf ' %s\n' "$line"; fi
        done < "$file"
    } > "$template"
    debconf-loadtemplate my-cdd "$template" || return 1
    db_fset "$q" seen false || return 1
    db_input critical "$q" || return 1
    db_go || return 1
}
fatal() {
    log "FATAL: $*"
    {
        printf 'Installation stopped: %s\n' "$*"
        echo "Unredacted diagnostics: $LOG"
        echo 'The installer USB is not assumed writable.'
        echo 'Manual log export: use an installer shell and a verified,'
        echo 'already-mounted writable removable data location.'
        echo
        tail -n 70 "$LOG"
    } > "$WORK/failure"
    show_note 'Custom profile failure and recovery' "$WORK/failure" || true
    cat "$WORK/failure" >&2
    export_log || true
    exit 1
}
approve() {
    db_subst my-cdd/transaction-approve MYCDD_OPERATION "$1" ||
        fatal 'Cannot prepare transaction approval'
    db_set my-cdd/transaction-approve false ||
        fatal 'Cannot reset transaction approval'
    db_fset my-cdd/transaction-approve seen false ||
        fatal 'Cannot display transaction approval'
    db_input critical my-cdd/transaction-approve ||
        fatal 'Transaction approval cancelled or unavailable'
    db_go || fatal 'Transaction confirmation cancelled'
    db_get my-cdd/transaction-approve ||
        fatal 'Cannot read transaction confirmation'
    [ "$RET" = true ] || fatal "Transaction declined: $1"
    log "USER APPROVED TRANSACTION: $1"
}
yes_no() {
    db_set "$1" false || fatal "Cannot reset $1"
    db_fset "$1" seen false || fatal "Cannot display $1"
    db_input critical "$1" || fatal "Prompt unavailable: $1"
    db_go || fatal "Prompt cancelled: $1"
    db_get "$1" || fatal "Cannot read response: $1"
    [ "$RET" = true ]
}
review_plan() {
    [ -s "$2" ] || fatal "Missing complete plan: $1"
    cat "$2" >> "$LOG"
    show_note "Review: $1" "$2" ||
        fatal "Cannot display complete plan: $1"
    approve "$1"
}
run_target() {
    capture in-target "$@" || fatal "Target command failed: $*"
}
simulate_target() {
    capture in-target apt-get -s "$@" ||
        fatal "APT simulation failed: apt-get -s $*"
    cp "$WORK/output" "$WORK/plan"
}
check_critical_removals() {
    if grep -E '^Remv (linux-image|linux-headers|grub|openssh-server|sudo|systemd|apt |dpkg )' "$WORK/plan" > "$WORK/critical"; then
        cat "$WORK/critical" >> "$LOG"
        fatal 'Proposed removal of boot/essential administration packages; explicit manual resolution required'
    fi
}
review_install() {
    name=$1
    shift
    simulate_target install "$@"
    check_critical_removals
    review_plan "$name" "$WORK/plan"
    run_target apt-get -y install "$@"
    run_target dpkg --audit
}
reviewed_upgrade() {
    simulate_target full-upgrade
    check_critical_removals
    review_plan 'Backports: complete eligible-package full-upgrade' "$WORK/plan"
    run_target apt-get -y full-upgrade
    run_target dpkg --audit
    simulate_target full-upgrade
    if grep -E '^Inst |^Remv ' "$WORK/plan" >/dev/null; then
        fatal 'Eligible upgrades/removals remain following approved full-upgrade'
    fi
}
report_omission() {
    db_subst my-cdd/approve-omission MYCDD_PACKAGE "$1" ||
        fatal 'Cannot present named omission'
    db_subst my-cdd/approve-omission MYCDD_REASON "$2" ||
        fatal 'Cannot present omission reason'
    if yes_no my-cdd/approve-omission; then
        log "USER APPROVED OMISSION: $1; reason: $2"
    else
        fatal "Omission declined: $1"
    fi
}
mark_complete() {
    printf 'Completed: %s\n' "$1" > "$LOG_DIR/my-cdd-completed/$1"
    chmod 600 "$LOG_DIR/my-cdd-completed/$1"
    log "PROFILE COMPLETE: $1"
}
[ -r "$MEDIA/profile-actions.sh" ] || fatal 'Missing profile action source'
[ -r "$MEDIA/ordered-selection.sh" ] || fatal 'Missing selection validator'
[ -r "$CONFIRMED" ] || fatal 'No approved early profile selection was recorded'
. "$MEDIA/profile-actions.sh"
db_get simple-cdd/profiles || fatal 'Cannot read Simple-CDD profile selection'
ordered="$(/bin/sh "$MEDIA/ordered-selection.sh" "$RET")" ||
    fatal 'Invalid selected profiles or missing kernel prerequisite'
[ "$ordered" = "$(cat "$CONFIRMED")" ] ||
    fatal 'Selection changed after approval; do not run unapproved profiles'
db_get my-cdd/profile-confirm || fatal 'Missing early summary approval'
[ "$RET" = true ] || fatal 'The early profile summary was not approved'
log "CONFIRMED SELECTION: $ordered"
for profile in $ordered; do
    log "PROFILE BEGIN: $profile"
    case "$profile" in
        backports) profile_backports ;;
        ensure-7x-kernel) profile_kernel ;;
        extended-device-support) profile_firmware ;;
        zram-writeback) profile_zram ;;
        debian-tweaks) profile_tweaks ;;
        openmediavault) profile_omv ;;
        docker) profile_docker ;;
        *) fatal "Unknown selected profile: $profile" ;;
    esac
    mark_complete "$profile"
done
log 'All selected optional profiles completed.'
export_log
exit 0
