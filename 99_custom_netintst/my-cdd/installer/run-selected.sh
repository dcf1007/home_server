#!/bin/sh
# Debian Installer-side executor: native cdebconf, no patched udeb.
# Registered at 11my-cdd in Debian Installer finish-install, after native CD-ROM cleanup.
set -eu
umask 077
MEDIA=/cdrom/simple-cdd
LOG_DIR=/target/var/log/installer
LOG="$LOG_DIR/my-cdd.log"
STATUS="$LOG_DIR/my-cdd-status"
WORK=/tmp/my-cdd-install
CONFIRMED=/tmp/my-cdd-confirmed-profiles
mkdir -p "$WORK"
chmod 700 "$WORK"
[ -d /target/etc ] || { echo 'my-cdd: target missing' >&2; exit 1; }
touch "$LOG"
chmod 600 "$LOG"
printf "INCOMPLETE\n" > "$STATUS"
chmod 600 "$STATUS"
log() { printf '%s\n' "$*" >> "$LOG"; }
FAILED_CAPTURE_COMMAND=''
FAILED_CAPTURE_STATUS=''
capture() {
    # in-target uses log-output: --pass-stdout forwards stdout, but stderr
    # goes to installer syslog. Redirect stderr *inside* the target so both
    # streams reach our command log and can be shown in the GTK/text dialog.
    FAILED_CAPTURE_COMMAND=''
    FAILED_CAPTURE_STATUS=''
    if [ "$1" = in-target ]; then
        shift
        command_label="in-target --pass-stdout $*"
        set -- in-target --pass-stdout /bin/sh -c 'exec "$@" 2>&1' my-cdd "$@"
    else
        command_label="$*"
    fi
    log "COMMAND: $command_label"
    if "$@" > "$WORK/output" 2>&1; then rc=0; else rc=$?; fi
    cat "$WORK/output" >> "$LOG"
    if [ "$rc" -ne 0 ]; then
        FAILED_CAPTURE_COMMAND=$command_label
        FAILED_CAPTURE_STATUS=$rc
    fi
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
    printf "FAILED\n" > "$STATUS"
    log "FATAL: $*"
    {
        printf 'Installation stopped: %s\n' "$*"
        if [ -n "$FAILED_CAPTURE_COMMAND" ]; then
            printf '\nFAILED COMMAND: %s\nEXIT STATUS: %s\n' \
                "$FAILED_CAPTURE_COMMAND" "$FAILED_CAPTURE_STATUS"
            printf '\nACTUAL COMMAND OUTPUT (including stderr; last 100 lines):\n'
            if [ -s "$WORK/output" ]; then
                # Put recognizable APT/dpkg errors at the top of the dialog
                # before any lengthy contextual output.
                if grep -E '^(Err:|E:|W:|Error:|ERROR:|dpkg: error:|fatal:)' \
                    "$WORK/output" > "$WORK/errors"; then
                    echo 'Reported error/warning lines:'
                    tail -n 30 "$WORK/errors"
                    echo
                fi
                tail -n 100 "$WORK/output"
            else
                echo 'No output was captured from the failed command.'
                if [ -r /var/log/syslog ]; then
                    echo 'Recent installer syslog entries:'
                    tail -n 30 /var/log/syslog
                fi
            fi
        else
            echo
            echo 'RECENT INSTALLER LOG:'
            tail -n 70 "$LOG"
        fi
        echo
        echo "Full unredacted diagnostics: $LOG"
        echo 'The installer USB is not assumed writable.'
        echo 'Manual log export: use an installer shell and a verified,'
        echo 'already-mounted writable removable data location.'
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
    # Retain the native Debian Installer APT progress UI. Profile calls and
    # the complete reviewed plan determine which operation executes.
    if [ "$1" = apt-get ]; then
        capture in-target debconf-apt-progress --logstderr -- "$@" ||
            fatal "Target APT transaction failed: $*"
    else
        capture in-target "$@" || fatal "Target command failed: $*"
    fi
}
simulate_target() {
    capture in-target apt-get -s "$@" ||
        fatal "APT simulation failed: apt-get -s $*"
    cp "$WORK/output" "$WORK/plan"
}
review_install() {
    name=$1
    shift
    simulate_target install "$@"
    review_plan "$name" "$WORK/plan"
    run_target apt-get -y install "$@"
    run_target dpkg --audit
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
[ -r "$MEDIA/profile-common.sh" ] || fatal 'Missing shared profile helpers'
[ -r "$MEDIA/ordered-selection.sh" ] || fatal 'Missing selection validator'
[ -r "$CONFIRMED" ] || fatal 'No approved early profile selection was recorded'
. "$MEDIA/profile-common.sh"

# No unconditional target policy changes in the base-only installation.
# Optional changes run only after explicitly selected profile confirmation.
# Check rescue/emergency-console access BEFORE running any selected profile.
# Debian Installer may create a sudo-capable user while leaving root locked.
# A local root password is needed by the normal sulogin recovery console.
# Use the existing Debian Installer password-type Debconf questions; never
# log or write a password to a preseed, the ISO, or a command argument.
ensure_root_recovery() {
    # Debian's initial root password should be left blank to give the
    # first ordinary account sudo. Verify it rather than granting sudo
    # to an unexpected account silently.
    db_get passwd/username || fatal 'Cannot read the native installer username'
    recovery_user=$RET
    [ -n "$recovery_user" ] || fatal 'Missing installer-created admin account'
    capture in-target id -nG "$recovery_user" ||
        fatal 'Installer-created admin account is unavailable'
    case " $(cat "$WORK/output") " in
        *' sudo '*) log 'Verified native sudo administrator account' ;;
        *) fatal 'Installer-created user is not in sudo group; leave initial root-password fields empty during Debian setup' ;;
    esac
    capture in-target sh -c 'command -v sudo >/dev/null 2>&1' ||
        fatal 'sudo is not available in the installed target'
    capture in-target passwd -S root ||
        fatal 'Cannot inspect installed root account for emergency recovery'
    root_state="$(awk '$1 == "root" { print $2 }' "$WORK/output")"
    case "$root_state" in
        P)
            log 'Emergency recovery preflight: local root password already configured'
            return 0 ;;
        L|NP)
            log 'Emergency recovery preflight: root is locked or has no password' ;;
        *)
            fatal 'Unrecognized root account password state; refusing optional operations' ;;
    esac

    # These are native user-setup-udeb templates, not project custom files.
    # Native user-setup clears them after initial account creation; clear them
    # again before and immediately after each attempt.
    for recovery_question in passwd/root-password passwd/root-password-again; do
        db_set "$recovery_question" '' ||
            fatal 'Cannot clear temporary root-password question'
    done
    while :; do
        for recovery_question in passwd/root-password passwd/root-password-again; do
            db_fset "$recovery_question" seen false ||
                fatal 'Cannot show the native root-password prompt'
            db_input critical "$recovery_question" ||
                fatal 'Native root-password prompt unavailable'
        done
        db_go || fatal 'Root-password prompt was cancelled'
        db_get passwd/root-password || fatal 'Cannot read the new root password'
        root_password=$RET
        db_get passwd/root-password-again || fatal 'Cannot read the confirmation password'
        root_confirmation=$RET
        # Never leave credentials in the installer Debconf database.
        db_set passwd/root-password '' || fatal 'Cannot clear root password from Debconf'
        db_set passwd/root-password-again '' || fatal 'Cannot clear root password confirmation'

        recovery_error=''
        if [ -z "$root_password" ]; then
            recovery_error='A non-empty local root password is required for rescue and emergency access.'
        elif [ "$root_password" != "$root_confirmation" ]; then
            recovery_error='The two root passwords did not match. Please re-enter both values.'
        elif printf '%s' "$root_password" | LC_ALL=C grep -q '[[:cntrl:]]'; then
            recovery_error='The password contains unsupported control characters. Please choose another.'
        fi
        root_confirmation=''
        if [ -n "$recovery_error" ]; then
            root_password=''
            printf '%s\n' "$recovery_error" > "$WORK/root-recovery-explanation"
            show_note 'Local emergency recovery password required' "$WORK/root-recovery-explanation" ||
                fatal 'Cannot display password correction request'
            continue
        fi
        # in-target reserves stdin for its Debconf passthrough. Feed chpasswd
        # through a direct target chroot instead; no secret enters argv, a
        # temporary file, or the custom installer logs.
        if printf 'root:%s\n' "$root_password" | capture chroot /target /usr/sbin/chpasswd; then
            password_changed=true
        else
            password_changed=false
        fi
        root_password=''
        [ "$password_changed" = true ] ||
            fatal 'Failed to establish local root recovery password'
        capture in-target passwd -S root ||
            fatal 'Cannot verify new local root password'
        grep -E '^root[[:space:]]+P[[:space:]]' "$WORK/output" >/dev/null ||
            fatal 'Root account remains locked after password setup'
        log 'Emergency recovery preflight: usable local root password confirmed'
        return 0
    done
}

db_get simple-cdd/profiles || fatal 'Cannot read Simple-CDD profile selection'
ordered="$(/bin/sh "$MEDIA/ordered-selection.sh" "$RET")" ||
    fatal 'Invalid selected profiles or missing kernel prerequisite'
[ "$ordered" = "$(cat "$CONFIRMED")" ] ||
    fatal 'Selection changed after approval; do not run unapproved profiles'
db_get my-cdd/profile-confirm || fatal 'Missing early summary approval'
[ "$RET" = true ] || fatal 'The early profile summary was not approved'
log "CONFIRMED SELECTION: $ordered"

ensure_root_recovery

for profile in $ordered; do
    log "PROFILE BEGIN: $profile"
    case "$profile" in
        debian-tweaks) module=tweaks; handler=profile_tweaks ;;
        backports) module=backports; handler=profile_backports ;;
        ensure-7x-kernel) module=kernel; handler=profile_kernel ;;
        extended-device-support) module=firmware; handler=profile_firmware ;;
        zram-writeback) module=zram; handler=profile_zram ;;
        openmediavault) module=omv; handler=profile_omv ;;
        docker) module=docker; handler=profile_docker ;;
        *) fatal "Unknown selected profile: $profile" ;;
    esac
    [ -r "$MEDIA/profile-$module.sh" ] || fatal "Missing selected module: $module"
    . "$MEDIA/profile-$module.sh"
    "$handler"
    log "PROFILE COMPLETE: $profile"
done
log 'All selected optional profiles completed.'
printf 'COMPLETE\n' > "$STATUS"
export_log
exit 0
