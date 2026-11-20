#!/bin/sh
# Approved method A (2026-11-14): run in preseed/early_command BEFORE
# anna-install simple-cdd-profiles. Do not patch the upstream udeb.
# This script handles selection and confirmation only; it changes no APT,
# target partition, installed user/account, or optional profile state.
set -eu

CDDIR=/cdrom/simple-cdd
ORDER_HELPER="$CDDIR/ordered-selection.sh"
TEMPLATE_SIMPLE="$CDDIR/simple-cdd.templates"
TEMPLATE_CONFIRM="$CDDIR/profile-confirm.templates"
FINISH_RUNNER="$CDDIR/run-selected.sh"
FINISH_GUARD="$CDDIR/63my-cdd-status"

stop() {
    printf >&2 'my-cdd early profile gate: STOP: %s\n' "$*"
    exit 1
}
for required in "$ORDER_HELPER" "$TEMPLATE_SIMPLE" "$TEMPLATE_CONFIRM" "$FINISH_RUNNER" "$FINISH_GUARD"; do
    [ -r "$required" ] || stop "missing installer-media source: $required"
done
command -v debconf-loadtemplate >/dev/null 2>&1 ||
    stop 'debconf-loadtemplate is not available in the installer'

# Use Debian Installer's existing finish-install hook order:
# 10apt-cdrom-setup -> 50/55 networking -> 60cleanup -> 61my-cdd.
# Native verification/eject/final-message are relocated separately by
# partman/early_command before partitioning.
# Register the selected-profile runner and final completion gate here,
# before finish-install enumerates its hooks. Do not patch upstream scripts.
mkdir -p /usr/lib/finish-install.d ||
    stop 'Cannot locate Debian Installer finish-install hook directory'
cp "$FINISH_RUNNER" /usr/lib/finish-install.d/61my-cdd ||
    stop 'Cannot register selected-profile finish-install hook'
chmod 755 /usr/lib/finish-install.d/61my-cdd ||
    stop 'Cannot make selected-profile hook executable'
cp "$FINISH_GUARD" /usr/lib/finish-install.d/63my-cdd-status ||
    stop 'Cannot register custom finish-install completion gate'
chmod 755 /usr/lib/finish-install.d/63my-cdd-status ||
    stop 'Cannot make finish-install completion gate executable'

# Generated simple-cdd.templates has the actual Choices and empty Defaults.
# Load both template families explicitly; the original profile udeb has NOT
# been installed, so we must not assume its template is already registered.
debconf-loadtemplate simple-cdd "$TEMPLATE_SIMPLE" ||
    stop 'could not load upstream Simple-CDD profile question'
debconf-loadtemplate my-cdd "$TEMPLATE_CONFIRM" ||
    stop 'could not load the optional-profile summary questions'
. /usr/share/debconf/confmodule

ask_profiles() {
    # Ensure a normal, explicit seven-choice multiselect is actually shown.
    # Do not silently leave a previously seen/auto-selected value.
    db_fset simple-cdd/profiles seen false || return 1
    db_input high simple-cdd/profiles || return 1
    db_go || return 1
}

status_of() {
    case " $ordered " in
        *" $1 "*) profile_status='Selected' ;;
        *) profile_status='Not selected' ;;
    esac
}

display_summary() {
    status_of debian-tweaks
    db_subst my-cdd/profile-confirm MYCDD_TWEAKS "$profile_status" || return 1
    status_of backports
    db_subst my-cdd/profile-confirm MYCDD_BACKPORTS "$profile_status" || return 1
    status_of ensure-7x-kernel
    db_subst my-cdd/profile-confirm MYCDD_KERNEL "$profile_status" || return 1
    status_of extended-device-support
    db_subst my-cdd/profile-confirm MYCDD_FIRMWARE "$profile_status" || return 1
    status_of zram-writeback
    db_subst my-cdd/profile-confirm MYCDD_ZRAM "$profile_status" || return 1
    status_of openmediavault
    db_subst my-cdd/profile-confirm MYCDD_OMV "$profile_status" || return 1
    status_of docker
    db_subst my-cdd/profile-confirm MYCDD_DOCKER "$profile_status" || return 1

    # All substitutions are single-line tokens: no embedded newline in
    # the line-oriented Debconf SUBST protocol.
    return 0
}

ask_profiles || stop 'selection screen unavailable or cancelled; no profile operations may start'
while :; do
    db_get simple-cdd/profiles || stop 'cannot read selected profiles'
    selected=$RET
    if ! ordered="$(/bin/sh "$ORDER_HELPER" "$selected")"; then
        db_fset my-cdd/profile-invalid seen false ||
            stop 'could not display the invalid-selection message'
        db_input critical my-cdd/profile-invalid ||
            stop 'invalid selection; profile question cannot be shown'
        db_go || stop 'invalid selection not acknowledged'
        ask_profiles || stop 'could not return to profile selection'
        continue
    fi

    display_summary || stop 'cannot prepare profile confirmation'
    db_set my-cdd/profile-confirm false || stop 'cannot set safe No default'
    db_fset my-cdd/profile-confirm seen false || stop 'cannot reset confirmation question'
    db_input critical my-cdd/profile-confirm || stop 'confirmation unavailable or cancelled'
    db_go || stop 'confirmation cancelled'
    db_get my-cdd/profile-confirm || stop 'cannot read confirmation'
    if [ "$RET" = true ]; then
        # The unmodified Simple-CDD udeb normally loads this template and
        # db_input's the same question after anna-install. Keep its already
        # answered value "seen" to avoid asking twice. This behavior must
        # be confirmed against actual Trixie GTK/text installer frontends.
        db_fset simple-cdd/profiles seen true ||
            stop 'cannot preserve approved selection for upstream Simple-CDD'
        # Preserve the exact user-approved set for the late native installer
        # executor; it must never reconstruct or expand selections by guesswork.
        umask 077
        printf '%s\n' "$ordered" > /tmp/my-cdd-confirmed-profiles ||
            stop 'Cannot persist the confirmed selection for finish-install'
        if [ -n "$ordered" ]; then
            printf '%s\n' "my-cdd early profile gate: confirmed profiles: $ordered"
        else
            printf '%s\n' 'my-cdd early profile gate: confirmed base Debian only'
        fi
        exit 0
    fi

    # An explicit No is a request to revisit the same original multiselect.
    # Never enable the kernel profile on ZRAM's behalf or add any profile.
    ask_profiles || stop 'could not return to profile selection'
done
