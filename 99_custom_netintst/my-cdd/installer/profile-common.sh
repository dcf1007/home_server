#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

suite_version() {
    capture in-target apt-cache madison "$1" ||
        fatal "Unable to inspect APT candidates for $1"
    awk -F '|' -v s="$2" 'index($3,s"/") {
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit
    }' "$WORK/output"
}

backports_is_selected() {
    case " $ordered " in *' backports '*) return 0;; *) return 1;; esac
}

update_signed_apt() {
    run_target apt-get update
}

