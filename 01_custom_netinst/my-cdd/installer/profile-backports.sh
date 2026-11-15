#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_backports() {
    [ -r "$MEDIA/debian-backports.sources" ] ||
        fatal 'Signed Backports repository template missing'
    [ ! -e /target/etc/apt/preferences.d/90-local-backports.pref ] ||
        fatal 'Unexpected old Backports pin; manual review required'
    mkdir -p /target/etc/apt/sources.list.d
    cp "$MEDIA/debian-backports.sources" /target/etc/apt/sources.list.d/debian-backports.sources
    chmod 644 /target/etc/apt/sources.list.d/debian-backports.sources
    update_signed_apt
    grep -E '^[[:space:]]*100[[:space:]].*trixie-backports' "$WORK/output" >/dev/null ||
        fatal 'Cannot confirm effective Backports priority 100'
    if grep -E '^[[:space:]]*[0-9]+[[:space:]].*trixie-backports' "$WORK/output" |
        grep -Ev '^[[:space:]]*100[[:space:]]' > "$WORK/pin-errors"; then
        cat "$WORK/pin-errors" >> "$LOG"
        fatal 'Backports repository has an unexpected effective priority'
    fi
    reviewed_upgrade
    simulate_target autoremove --purge
    check_critical_removals
    if grep -E '^Remv |^Purg ' "$WORK/plan" >/dev/null; then
        show_note 'Backports: review full autoremove/purge simulation' "$WORK/plan" ||
            fatal 'Could not display the complete cleanup plan'
        awk '/^Remv / || /^Purg / {print $2}' "$WORK/plan" |
            sort -u > "$WORK/removal-list"
        [ -s "$WORK/removal-list" ] ||
            fatal 'Cleanup simulation proposed changes but no package names could be identified'
        while IFS= read -r pkg; do
            db_subst my-cdd/approve-removal MYCDD_REMOVAL "$pkg" ||
                fatal "Could not show approval for removal of $pkg"
            yes_no my-cdd/approve-removal ||
                fatal "Individual removal not approved: $pkg"
            log "USER APPROVED REMOVAL: $pkg"
        done < "$WORK/removal-list"
        run_target apt -y autoremove --purge
    fi
    capture in-target dpkg -l || fatal 'Cannot list residual dpkg configuration'
    awk '$1=="rc" {print $2}' "$WORK/output" > "$WORK/residual"
    if [ -s "$WORK/residual" ]; then
        {
            echo 'The following exact residual configurations will be purged:'
            cat "$WORK/residual"
        } > "$WORK/residual-review"
        review_plan 'Backports: purge only explicitly reviewed residual configurations' "$WORK/residual-review"
        while IFS= read -r pkg; do
            case "$pkg" in
                ''|*[!a-zA-Z0-9.+:~-]*) fatal "Invalid residual package: $pkg";;
            esac
            run_target dpkg --purge "$pkg"
        done < "$WORK/residual"
    fi
    run_target dpkg --audit
    simulate_target autoremove --purge
    if grep -E '^Remv |^Purg ' "$WORK/plan" >/dev/null; then
        fatal 'Autoremove still proposes changes after approved cleanup'
    fi
}

