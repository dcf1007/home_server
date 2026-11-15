#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

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

choose_normal_kernel() {
    # Among normal Debian repositories, use the newest *viable* 7.x pair,
    # not an arbitrarily preferred security/updates suite.
    best_suite=''
    best_version=''
    for normal in trixie-security trixie-updates trixie; do
        if try_kernel_suite "$normal"; then
            if [ -z "$best_version" ] ||
                in-target dpkg --compare-versions "$KERNEL_IMAGE_VERSION" gt "$best_version"; then
                best_suite=$normal
                best_version=$KERNEL_IMAGE_VERSION
            fi
        fi
    done
    [ -n "$best_suite" ] || return 1
    try_kernel_suite "$best_suite"
}

profile_kernel() {
    update_signed_apt
    if backports_is_selected; then
        try_kernel_suite trixie-backports ||
            choose_normal_kernel ||
            fatal 'No compatible moving 7.x kernel image+headers in selected repositories'
    else
        choose_normal_kernel ||
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
    paired=0
    for image in /target/boot/vmlinuz-7.*; do
        [ -f "$image" ] || continue
        abi="${image##*/vmlinuz-}"
        if [ -d "/target/usr/src/linux-headers-$abi" ]; then
            paired=1
        fi
    done
    [ "$paired" = 1 ] ||
        fatal 'No Linux 7.x boot image with exactly matching installed headers'
    run_target dpkg --audit
}

