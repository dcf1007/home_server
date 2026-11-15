#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

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
            if capture in-target apt -s install $(cat "$WORK/firmware-selectors") "$candidate"; then
                if ! grep -E '^Remv (linux-image|linux-headers|grub|openssh-server|sudo|systemd|apt |dpkg )' "$WORK/output" >/dev/null; then
                    selector=$candidate
                fi
            fi
            [ -n "$selector" ] ||
                reason='Backports candidate incompatible with existing requested set; details in complete APT log'
        fi
        if [ -z "$selector" ] && [ -n "$stable" ]; then
            candidate="$pkg/$stable"
            if capture in-target apt -s install $(cat "$WORK/firmware-selectors") "$candidate"; then
                if ! grep -E '^Remv (linux-image|linux-headers|grub|openssh-server|sudo|systemd|apt |dpkg )' "$WORK/output" >/dev/null; then
                    selector=$candidate
                    if backports_is_selected; then
                        [ -n "$reason" ] || reason='No published Backports version'
                        stable_version="$(suite_version "$pkg" "$stable")"
                        printf '%s: version=%s, origin=%s, fallback reason=%s\n' \
                            "$pkg" "$stable_version" "$stable" "$reason" >> "$WORK/firmware-fallbacks"
                    fi
                fi
            fi
        fi
        if [ -z "$selector" ]; then
            if [ -z "$bpo" ] && [ -z "$stable" ]; then
                reason='No published candidate in the enabled approved Debian repositories'
            else
                detail="$(grep -m1 '^E:' "$WORK/output" | cut -c1-160 || true)"
                [ -n "$detail" ] ||
                    detail='APT refused the selected package combination (full diagnostics in target log)'
                reason="Package dependency/conflict: $detail"
            fi
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
    run_target apt -y install $(cat "$WORK/firmware-selectors")
    run_target dpkg --audit
}


