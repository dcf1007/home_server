#!/bin/sh
# Real installer-side implementations, sourced by run-selected.sh.
# These functions operate only after an approved native Simple-CDD selection.

suite_version() {
    capture in-target apt-cache madison "$1" ||
        fatal "Unable to inspect APT candidates for $1"
    awk -F '|' -v s="$2" 'index($3,s"/") {
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit
    }' "$WORK/output"
}
normal_suite() {
    for suite in trixie-security trixie-updates trixie; do
        v="$(suite_version "$1" "$suite")"
        if [ -n "$v" ]; then printf '%s\n' "$suite"; return 0; fi
    done
    return 1
}
backports_is_selected() {
    case " $ordered " in *' backports '*) return 0;; *) return 1;; esac
}
update_signed_apt() {
    run_target apt-get update
    capture in-target apt-cache policy || fatal 'Cannot inspect APT priorities'
}
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
        review_plan 'Backports: review all proposed autoremove/purge entries' "$WORK/plan"
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
    simulate_target autoremove --purge
    if grep -E '^Remv |^Purg ' "$WORK/plan" >/dev/null; then
        fatal 'Autoremove still proposes changes after approved cleanup'
    fi
}
is_7x_metapackage() {
    [ -n "$2" ] || return 1
    capture in-target apt-cache show "$1=$2" || return 1
    case "$1" in
        linux-image-amd64) grep -E '^Depends: .*linux-image-7\.[0-9]' "$WORK/output" >/dev/null;;
        linux-headers-amd64) grep -E '^Depends: .*linux-headers-7\.[0-9]' "$WORK/output" >/dev/null;;
        *) return 1;;
    esac
}
try_kernel_suite() {
    ks=$1
    iv="$(suite_version linux-image-amd64 "$ks")"
    hv="$(suite_version linux-headers-amd64 "$ks")"
    [ -n "$iv" ] && [ -n "$hv" ] || return 1
    is_7x_metapackage linux-image-amd64 "$iv" || return 1
    is_7x_metapackage linux-headers-amd64 "$hv" || return 1
    if capture in-target apt-get -s install "linux-image-amd64/$ks" "linux-headers-amd64/$ks"; then
        cp "$WORK/output" "$WORK/plan"
        if grep -E '^Remv (linux-image|linux-headers|grub)' "$WORK/plan" >/dev/null; then
            log "Rejected candidate kernel suite: $ks would remove initial fallback/boot support"
            return 1
        fi
        KERNEL_SUITE=$ks
        KERNEL_IMAGE_VERSION=$iv
        KERNEL_HEADERS_VERSION=$hv
        return 0
    fi
    log "Rejected candidate kernel suite: $ks did not resolve safely"
    return 1
}
profile_kernel() {
    update_signed_apt
    if backports_is_selected; then
        try_kernel_suite trixie-backports ||
            try_kernel_suite trixie-security ||
            try_kernel_suite trixie-updates ||
            try_kernel_suite trixie ||
            fatal 'No compatible moving 7.x kernel image+headers in selected repositories'
    else
        try_kernel_suite trixie-security ||
            try_kernel_suite trixie-updates ||
            try_kernel_suite trixie ||
            fatal 'No normal-repository 7.x kernel: explicitly select Backports or stop/deselect this profile'
    fi
    {
        echo "Chosen kernel suite: $KERNEL_SUITE"
        echo "linux-image-amd64: $KERNEL_IMAGE_VERSION"
        echo "linux-headers-amd64: $KERNEL_HEADERS_VERSION"
        if backports_is_selected && [ "$KERNEL_SUITE" != trixie-backports ]; then
            echo 'Stable fallback to a viable 7.x pair; rejected Backports reasons in full log'
        fi
        cat "$WORK/plan"
    } > "$WORK/kernel-review"
    review_plan 'Linux 7.x image, matching headers and complete APT simulation' "$WORK/kernel-review"
    run_target apt-get -y install "linux-image-amd64/$KERNEL_SUITE" "linux-headers-amd64/$KERNEL_SUITE"
    run_target update-initramfs -u -k all
    run_target update-grub
    [ -n "$(find /target/boot -maxdepth 1 -name 'vmlinuz-7.*' -print -quit)" ] ||
        fatal 'Linux 7.x boot image not found after installation'
    [ -n "$(find /target/usr/src -maxdepth 1 -name 'linux-headers-7.*' -print -quit)" ] ||
        fatal 'Matching Linux 7.x headers not found after installation'
    run_target dpkg --audit
}
profile_firmware() {
    update_signed_apt
    [ -r "$MEDIA/firmware-candidates.txt" ] || fatal 'Required firmware inventory missing'
    : > "$WORK/firmware-selectors"
    : > "$WORK/firmware-fallbacks"
    : > "$WORK/firmware-omissions"
    for pkg in $(grep -Ev '^[[:space:]]*(#|$)' "$MEDIA/firmware-candidates.txt"); do
        case "$pkg" in
            ''|*[!a-zA-Z0-9.+-]*) fatal "Unsafe inventory package: $pkg";;
        esac
        stable="$(normal_suite "$pkg")" || stable=''
        bpo=''
        if backports_is_selected; then bpo="$(suite_version "$pkg" trixie-backports)"; fi
        selector=''
        reason=''
        if [ -n "$bpo" ]; then
            candidate="$pkg/trixie-backports"
            if capture in-target apt-get -s install $(cat "$WORK/firmware-selectors") "$candidate"; then
                if ! grep -E '^Remv (linux-image|linux-headers|grub|openssh-server|sudo|systemd|apt |dpkg )' "$WORK/output" >/dev/null; then
                    selector=$candidate
                fi
            fi
            [ -n "$selector" ] ||
                reason='Backports candidate incompatible with existing requested set; details in complete APT log'
        fi
        if [ -z "$selector" ] && [ -n "$stable" ]; then
            candidate="$pkg/$stable"
            if capture in-target apt-get -s install $(cat "$WORK/firmware-selectors") "$candidate"; then
                if ! grep -E '^Remv (linux-image|linux-headers|grub|openssh-server|sudo|systemd|apt |dpkg )' "$WORK/output" >/dev/null; then
                    selector=$candidate
                    if backports_is_selected; then
                        [ -n "$reason" ] || reason='No published Backports version'
                        printf '%s/%s: %s\n' "$pkg" "$stable" "$reason" >> "$WORK/firmware-fallbacks"
                    fi
                fi
            fi
        fi
        if [ -z "$selector" ]; then
            reason='No compatible package candidate or simulated conflict; exact diagnostic recorded in log'
            report_omission "$pkg" "$reason"
            printf '%s: %s\n' "$pkg" "$reason" >> "$WORK/firmware-omissions"
        else
            printf '%s\n' "$selector" >> "$WORK/firmware-selectors"
        fi
    done
    [ -s "$WORK/firmware-selectors" ] || fatal 'No approved firmware packages remain'
    simulate_target install $(cat "$WORK/firmware-selectors")
    check_critical_removals
    {
        echo 'All chosen firmware/microcode package selectors:'
        cat "$WORK/firmware-selectors"
        echo 'Normal source fallbacks and specific reasons:'
        cat "$WORK/firmware-fallbacks"
        echo 'Individually approved package omissions:'
        cat "$WORK/firmware-omissions"
        echo 'Complete final joint APT simulation:'
        cat "$WORK/plan"
    } > "$WORK/firmware-review"
    review_plan 'Extended support: entire mixed-source firmware transaction' "$WORK/firmware-review"
    run_target apt-get -y install $(cat "$WORK/firmware-selectors")
    run_target dpkg --audit
}
