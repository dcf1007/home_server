#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

# Read the original Debconf license question from the exact APT-selected
# .deb, never from a copied or shortened license. Uses Simple-CDD's existing
# .extra mechanism and Debian Installer's native cdebconf graphical frontend.
# Returns 0 on explicit acceptance and 1 on explicit refusal.
firmware_license_decision() {
    licensed_pkg=$1
    licensed_selector=$2
    case "$licensed_pkg" in
        firmware-ipw2x00|firmware-ivtv) : ;;
        *) fatal "Unrecognized license-restricted firmware: $licensed_pkg" ;;
    esac
    license_dir="/tmp/my-cdd-license-$licensed_pkg"
    [ ! -e "/target$license_dir" ] ||
        fatal "Unexpected existing temporary license directory: $license_dir"
    mkdir -m 700 "/target$license_dir" ||
        fatal "Cannot prepare temporary license directory for $licensed_pkg"

    # Download but do not install the selected candidate; the sandbox setting
    # confines this trusted APT download to our root-owned temporary folder.
    capture in-target sh -c '
        cd "$1" || exit 1
        apt-get -o APT::Sandbox::User=root download "$2"
    ' my-cdd "$license_dir" "$licensed_selector" ||
        fatal "Cannot download the exact licensed package: $licensed_selector"

    set -- "/target$license_dir"/*.deb
    [ "$#" -eq 1 ] && [ -f "$1" ] ||
        fatal "Expected exactly one downloaded .deb for $licensed_pkg"
    license_deb=${1#/target}
    capture in-target dpkg-deb -f "$license_deb" Package ||
        fatal "Cannot inspect downloaded $licensed_pkg package"
    grep -Fx "$licensed_pkg" "$WORK/output" >/dev/null ||
        fatal "Downloaded license package has wrong name: $licensed_pkg"
    capture in-target dpkg-deb -e "$license_deb" "$license_dir/control" ||
        fatal "Cannot extract native Debconf templates for $licensed_pkg"

    license_templates="/target$license_dir/control/templates"
    license_question="$licensed_pkg/license/accepted"
    [ -s "$license_templates" ] ||
        fatal "No vendor license templates in $licensed_pkg binary"
    grep -Fx "Template: $license_question" "$license_templates" >/dev/null ||
        fatal "No native license acceptance question for $licensed_pkg"
    debconf-loadtemplate "$licensed_pkg" "$license_templates" ||
        fatal "Cannot load vendor license for $licensed_pkg"
    db_set "$license_question" false ||
        fatal "Cannot reset $licensed_pkg license answer"
    db_fset "$license_question" seen false ||
        fatal "Cannot display native $licensed_pkg license"
    db_input critical "$license_question" ||
        fatal "Native $licensed_pkg license question unavailable"
    db_go || fatal "Native $licensed_pkg license dialog cancelled"
    db_get "$license_question" ||
        fatal "Cannot read the $licensed_pkg license decision"
    if [ "$RET" != true ]; then
        log "USER DECLINED LICENSE: $licensed_pkg"
        rm -rf -- "/target$license_dir"
        return 1
    fi
    log "USER ACCEPTED LICENSE: $licensed_pkg"

    # D-I and the installed target have different Debconf databases. Only
    # after the above explicit GUI consent, store and verify the matching
    # target boolean; the package's own preinst then sees its accepted value.
    # Feed selections via stdin, never through command arguments or logs.
    printf '%s %s boolean true\n' "$licensed_pkg" "$license_question" |
        capture chroot /target /usr/bin/debconf-set-selections ||
        fatal "Cannot record explicit license agreement in target: $licensed_pkg"
    printf 'GET %s\n' "$license_question" |
        capture chroot /target /usr/bin/env DEBIAN_FRONTEND=noninteractive \
            /usr/bin/debconf-communicate "$licensed_pkg" ||
        fatal "Cannot verify target license answer: $licensed_pkg"
    grep -Fx '0 true' "$WORK/output" >/dev/null ||
        fatal "Target Debconf license consent not retained for $licensed_pkg"
    rm -rf -- "/target$license_dir"
    return 0
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

    # Ask the two complete package-native license questions BEFORE unpack.
    # Declines require a separate per-package omission approval and a
    # fresh full APT simulation and transaction review.
    license_omitted=false
    for licensed_pkg in firmware-ipw2x00 firmware-ivtv; do
        licensed_selector="$(grep "^$licensed_pkg/" "$WORK/firmware-selectors" || true)"
        [ -n "$licensed_selector" ] || continue
        if firmware_license_decision "$licensed_pkg" "$licensed_selector"; then
            :
        else
            report_omission "$licensed_pkg" 'The full vendor firmware license was declined in Debian Installer'
            printf '%s: license declined; individually approved omission\n' "$licensed_pkg" >> "$WORK/firmware-omissions"
            awk -v prefix="$licensed_pkg/" 'index($0,prefix)!=1 {print}' \
                "$WORK/firmware-selectors" > "$WORK/firmware-license-filtered"
            mv "$WORK/firmware-license-filtered" "$WORK/firmware-selectors" ||
                fatal "Cannot exclude declined firmware: $licensed_pkg"
            license_omitted=true
        fi
    done
    [ -s "$WORK/firmware-selectors" ] ||
        fatal 'No approved firmware packages remain after license decisions'
    if [ "$license_omitted" = true ]; then
        simulate_target install $(cat "$WORK/firmware-selectors")
        check_critical_removals
        for licensed_pkg in firmware-ipw2x00 firmware-ivtv; do
            if grep -q "^$licensed_pkg: license declined;" "$WORK/firmware-omissions"; then
                grep -Eq "^Inst $licensed_pkg([ :]|$)" "$WORK/plan" &&
                    fatal "Declined $licensed_pkg license is still required as a dependency"
            fi
        done
        {
            echo 'Package selectors after individually approved license omissions:'
            cat "$WORK/firmware-selectors"
            echo 'Individually approved omissions:'
            cat "$WORK/firmware-omissions"
            echo 'Recomputed joint APT simulation:'
            cat "$WORK/plan"
        } > "$WORK/firmware-license-review"
        review_plan 'Extended support: revised transaction after license omissions' "$WORK/firmware-license-review"
    fi
    run_target apt -y install $(cat "$WORK/firmware-selectors")
    run_target dpkg --audit
}


