#!/bin/sh
# Debconf GTK/text confirmation gate source for Simple-CDD 0.6.9.
# NOT YET WIRED INTO A UDEB. MUST run after the Simple-CDD multiselect
# and before the upstream postinst loads any profile preseed or queues
# udebs/packages. This script performs no package or disk operation.
set -eu
. /usr/share/debconf/confmodule

# Shipped to /cdrom/simple-cdd via Simple-CDD all_extras once integrated.
ORDER_HELPER=/cdrom/simple-cdd/ordered-selection.sh
[ -r "$ORDER_HELPER" ] || {
    printf >&2 'STOP: ordered profile selection helper not on installer media\n'
    exit 1
}

# All templates must be loaded by the early udeb integration BEFORE entry.
# Never silently proceed if a question is missing/hidden.
review_statuses() {
    db_subst my-cdd/profile-summary MYCDD_BACKPORTS "$backports_state"
    db_subst my-cdd/profile-summary MYCDD_KERNEL "$kernel_state"
    db_subst my-cdd/profile-summary MYCDD_FIRMWARE "$firmware_state"
    db_subst my-cdd/profile-summary MYCDD_ZRAM "$zram_state"
    db_subst my-cdd/profile-summary MYCDD_TWEAKS "$tweaks_state"
    db_subst my-cdd/profile-summary MYCDD_OMV "$omv_state"
    db_subst my-cdd/profile-summary MYCDD_DOCKER "$docker_state"
    db_fset my-cdd/profile-summary seen false
    db_input critical my-cdd/profile-summary || return 1
    db_go || return 1
}

get_status() {
    p=$1
    case " $ordered " in
        *" $p "*) status=Selected ;;
        *) status='Not selected' ;;
    esac
}

return_to_selection() {
    # Simple-CDD originally asked this using db_input high.
    # Reopen it explicitly; NO checkboxes are changed in the script.
    db_fset simple-cdd/profiles seen false
    db_input high simple-cdd/profiles || return 1
    db_go || return 1
}

while :; do
    db_get simple-cdd/profiles || exit 1
    raw=$RET
    if ! ordered="$(sh "$ORDER_HELPER" "$raw")"; then
        db_fset my-cdd/profile-invalid seen false
        db_input critical my-cdd/profile-invalid || exit 1
        db_go || exit 1
        return_to_selection || exit 1
        continue
    fi

    get_status backports
    backports_state=$status
    get_status ensure-7x-kernel
    kernel_state=$status
    get_status extended-device-support
    firmware_state=$status
    get_status zram-writeback
    zram_state=$status
    get_status debian-tweaks
    tweaks_state=$status
    get_status openmediavault
    omv_state=$status
    get_status docker
    docker_state=$status

    review_statuses || exit 1
    db_set my-cdd/profile-confirm false
    db_fset my-cdd/profile-confirm seen false
    db_input critical my-cdd/profile-confirm || exit 1
    db_go || exit 1
    db_get my-cdd/profile-confirm || exit 1

    if [ "$RET" = true ]; then
        # The calling udeb may now safely continue loading the approved
        # profile files, but any separate package/destructive approvals
        # are still mandatory. Do not write a "success" marker here.
        printf '%s\n' "my-cdd: user confirmed selected profiles: $ordered"
        exit 0
    fi
    # No => allow new manual selection. Back/cancel => return failure;
    # the caller MUST NOT swallow that failure and queue packages.
    return_to_selection || exit 1
done
