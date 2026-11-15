#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

suite_version() {
    capture in-target apt-cache madison "$1" ||
        fatal "Unable to inspect APT candidates for $1"
    awk -F '|' -v s="$2" 'index($3,s"/") {
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit
    }' "$WORK/output"
}

normal_suite() {
    best_suite=''
    best_version=''
    for suite in trixie-security trixie-updates trixie; do
        v="$(suite_version "$1" "$suite")"
        [ -n "$v" ] || continue
        if [ -z "$best_version" ] ||
            in-target dpkg --compare-versions "$v" gt "$best_version"; then
            best_suite=$suite
            best_version=$v
        fi
    done
    [ -n "$best_suite" ] || return 1
    printf '%s\n' "$best_suite"
}

backports_is_selected() {
    case " $ordered " in *' backports '*) return 0;; *) return 1;; esac
}

update_signed_apt() {
    run_target apt-get update
    capture in-target apt-cache policy || fatal 'Cannot inspect APT priorities'
}

ensure_manual_updates() {
    capture in-target apt-config dump || fatal 'Cannot inspect automatic APT settings'
    if grep -Ei 'APT::Periodic::Unattended-Upgrade[[:space:]]+"?([1-9]|yes|true)' "$WORK/output" >/dev/null; then
        mkdir -p /target/etc/apt/apt.conf.d
        printf 'APT::Periodic::Unattended-Upgrade "0";\n' > \
            /target/etc/apt/apt.conf.d/99-my-cdd-manual-updates
        log 'Explicitly disabled an enabled unattended APT upgrade setting'
    fi
}


