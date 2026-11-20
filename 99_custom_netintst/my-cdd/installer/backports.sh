#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_backports() {
    [ -r "$MEDIA/debian-backports.sources" ] ||
        fatal 'Signed Backports repository template missing'
    mkdir -p /target/etc/apt/sources.list.d
    cp "$MEDIA/debian-backports.sources" /target/etc/apt/sources.list.d/debian-backports.sources
    chmod 644 /target/etc/apt/sources.list.d/debian-backports.sources
    update_signed_apt
    # APT resolves and presents each real transaction once.
    APT_REVIEW_LABEL='Backports: full upgrade' run_target apt-get dist-upgrade
    run_target dpkg --audit
    APT_REVIEW_LABEL='Backports: remove unused packages and their configuration' \
        run_target apt-get autoremove --purge
    capture in-target dpkg -l || fatal 'Cannot list residual dpkg configuration'
    awk '$1=="rc" {print $2}' "$WORK/output" > "$WORK/residual"
    if [ -s "$WORK/residual" ]; then
        {
            echo 'The following exact residual configurations will be purged:'
            cat "$WORK/residual"
        } > "$WORK/residual-review"
        cat "$WORK/residual-review" >> "$LOG"
        show_dialog 'Purge these residual package configurations?' "$WORK/residual-review" boolean ||
            fatal 'Residual configuration purge declined or unavailable'
        log 'USER APPROVED RESIDUAL CONFIGURATION PURGE'
        while IFS= read -r pkg; do
            case "$pkg" in
                ''|*[!a-zA-Z0-9.+:~-]*) fatal "Invalid residual package: $pkg";;
            esac
            run_target dpkg --purge "$pkg"
        done < "$WORK/residual"
    fi
    run_target dpkg --audit
}

