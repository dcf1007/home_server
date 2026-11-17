#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_backports() {
    [ -r "$MEDIA/debian-backports.sources" ] ||
        fatal 'Signed Backports repository template missing'
    mkdir -p /target/etc/apt/sources.list.d
    cp "$MEDIA/debian-backports.sources" /target/etc/apt/sources.list.d/debian-backports.sources
    chmod 644 /target/etc/apt/sources.list.d/debian-backports.sources
    update_signed_apt
    # Review this profile's complete Backports upgrade, then execute it.
    simulate_target dist-upgrade
    review_plan 'Backports: complete eligible-package full-upgrade' "$WORK/plan"
    run_target apt-get -y dist-upgrade
    run_target dpkg --audit
    simulate_target autoremove --purge
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
        run_target apt-get -y autoremove --purge
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
}

