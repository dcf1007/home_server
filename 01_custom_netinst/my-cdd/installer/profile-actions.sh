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
                        stable_version="$(suite_version "$pkg" "$stable")"
                        printf '%s: version=%s, origin=%s, fallback reason=%s\n' \
                            "$pkg" "$stable_version" "$stable" "$reason" >> "$WORK/firmware-fallbacks"
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


# ZRAM: the FIRST operation is the approved, user-identified GPT conversion.
profile_zram() {
    [ -f "$LOG_DIR/my-cdd-completed/ensure-7x-kernel" ] ||
        fatal 'ZRAM cannot run without the separately completed Ensure 7.x kernel profile'
    for utility in lsblk blkid swapon swapoff parted wipefs readlink findmnt; do
        command -v "$utility" >/dev/null 2>&1 ||
            fatal "ZRAM conversion requires unavailable installer utility: $utility"
    done
    [ -r "$MEDIA/zram-generator.conf.template" ] ||
        fatal 'Original ZRAM generator source missing'

    # Detect, show, and have the user type the EXACT PARTUUID; do not select
    # a disk, partition or name automatically.
    capture lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,PARTTYPE,PARTLABEL,PARTUUID,MOUNTPOINTS ||
        fatal 'Cannot enumerate partitions for ZRAM backing selection'
    {
        echo 'Identify the swap partition you manually created in the native partitioner.'
        echo 'If none exists, return to manual partitioning or deselect ZRAM.'
        echo 'If several exist, identify exactly one; none will be selected automatically.'
        echo 'Enter its exact PARTUUID at the next native installer prompt.'
        echo
        cat "$WORK/output"
    } > "$WORK/zram-candidates"
    show_note 'Select the user-created ZRAM backing partition' "$WORK/zram-candidates" ||
        fatal 'Could not display partition candidates'
    db_set my-cdd/zram-partuuid '' || fatal 'Cannot reset partition identity prompt'
    db_fset my-cdd/zram-partuuid seen false ||
        fatal 'Cannot display partition identity prompt'
    db_input critical my-cdd/zram-partuuid ||
        fatal 'Partition selection was not confirmed'
    db_go || fatal 'Partition identity input cancelled'
    db_get my-cdd/zram-partuuid || fatal 'Cannot read confirmed PARTUUID'
    uuid=$RET
    printf '%s\n' "$uuid" |
        grep -Eq '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$' ||
        fatal 'PARTUUID must be a complete UUID typed by the user'
    devlink="/dev/disk/by-partuuid/$uuid"
    [ -b "$devlink" ] || fatal 'User-entered PARTUUID does not exist as a block partition'
    device="$(readlink -f -- "$devlink")"
    [ "$(lsblk -dnro TYPE "$device")" = part ] ||
        fatal 'Selected PARTUUID is not a single partition'
    parent="$(lsblk -dnro PKNAME "$device")"
    partn="$(lsblk -dnro PARTN "$device")"
    case "$parent" in ''|*[!a-zA-Z0-9_-]*) fatal 'Invalid parent disk identity';; esac
    case "$partn" in ''|*[!0-9]*) fatal 'Invalid partition number';; esac
    disk="/dev/$parent"
    [ -b "$disk" ] || fatal 'Confirmed partition parent disk not found'
    [ "$(lsblk -dnro PTTYPE "$disk")" = gpt ] ||
        fatal 'Selected swap partition is not on a GPT disk'
    ptype="$(lsblk -dnro PARTTYPE "$device")"
    case "$ptype" in
        0657fd6d-a4ab-43c4-84e5-0933c84b4f4f|0657FD6D-A4AB-43C4-84E5-0933C84B4F4F) ;;
        *) fatal 'User-selected partition is not marked as conventional GPT Linux swap' ;;
    esac
    fstype="$(lsblk -dnro FSTYPE "$device")"
    [ "$fstype" = swap ] ||
        fatal 'Selected partition lacks an identifiable swap signature'
    [ -z "$(lsblk -dnro MOUNTPOINTS "$device")" ] ||
        fatal 'Backing partition is mounted; refusing conversion'
    former_uuid="$(blkid -s UUID -o value "$device")"
    size="$(lsblk -dnro SIZE "$device")"

    db_subst my-cdd/zram-destructive MYCDD_PARTITION "$device" ||
        fatal 'Unable to show partition path for destructive confirmation'
    db_subst my-cdd/zram-destructive MYCDD_PARTUUID "$uuid" ||
        fatal 'Unable to show exact PARTUUID for destructive confirmation'
    db_subst my-cdd/zram-destructive MYCDD_SIZE "$size" ||
        fatal 'Unable to show partition capacity for destructive confirmation'
    yes_no my-cdd/zram-destructive ||
        fatal 'User declined destructive ZRAM backing conversion'

    # Never swapoff -a. Check only this exact, reconfirmed partition.
    active_used=''
    swapon --noheadings --bytes -o NAME,USED > "$WORK/active-swaps" ||
        fatal 'Cannot read active swap devices'
    while read -r swap_path swap_used; do
        [ -n "$swap_path" ] || continue
        resolved="$(readlink -f -- "$swap_path")"
        if [ "$resolved" = "$device" ]; then active_used=$swap_used; fi
    done < "$WORK/active-swaps"
    if [ -n "$active_used" ]; then
        available_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
        case "$available_kb" in ''|*[!0-9]*) fatal 'Cannot assess available RAM for swapoff';; esac
        available_bytes=$((available_kb * 1024))
        if [ "$available_bytes" -le "$active_used" ]; then
            fatal 'Available RAM does not safely cover used bytes on confirmed swap; no swapoff attempted'
        fi
        db_subst my-cdd/zram-swapoff MYCDD_PARTITION "$device" ||
            fatal 'Cannot show exact swapoff target'
        db_subst my-cdd/zram-swapoff MYCDD_USED "$active_used" ||
            fatal 'Cannot show current used swap bytes'
        yes_no my-cdd/zram-swapoff ||
            fatal 'Targeted swapoff was not separately approved'
        capture swapoff "$device" ||
            fatal 'Targeted swapoff failed; GPT and signatures left unchanged'
        swapon --noheadings -o NAME > "$WORK/active-after"
        while IFS= read -r swap_path; do
            [ -n "$swap_path" ] || continue
            [ "$(readlink -f -- "$swap_path")" != "$device" ] ||
                fatal 'Target partition still active as ordinary swap after swapoff'
        done < "$WORK/active-after"
    fi
    [ -z "$(lsblk -dnro MOUNTPOINTS "$device")" ] ||
        fatal 'Selected backing partition was mounted before conversion'

    # The only destructive partition commands target the one confirmed GPT
    # partition. No automatic partition creation, sizing or formatting.
    log "USER APPROVED CONVERSION: $device, PARTUUID=$uuid, size=$size"
    capture parted -s "$disk" type "$partn" 0FC63DAF-8483-4772-8E79-3D69D8477DE4 ||
        fatal 'Could not change only the confirmed GPT partition type'
    capture parted -s "$disk" name "$partn" zram-writeback ||
        fatal 'Could not set confirmed GPT PARTLABEL'
    capture wipefs -a "$device" ||
        fatal 'Could not remove signatures from only the confirmed partition'
    [ "$(lsblk -dnro PARTUUID "$device" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$uuid" | tr '[:upper:]' '[:lower:]')" ] ||
        fatal 'PARTUUID changed unexpectedly after conversion'
    [ "$(lsblk -dnro PARTLABEL "$device")" = zram-writeback ] ||
        fatal 'Converted GPT PARTLABEL not visible'
    [ "$(lsblk -dnro PARTTYPE "$device" | tr '[:upper:]' '[:lower:]')" = 0fc63daf-8483-4772-8e79-3d69d8477de4 ] ||
        fatal 'Confirmed partition has the wrong GPT type after conversion'
    [ -z "$(blkid -s TYPE -o value "$device" 2>/dev/null || true)" ] ||
        fatal 'Backing partition still has a filesystem/swap signature'
    [ -z "$(lsblk -dnro MOUNTPOINTS "$device")" ] ||
        fatal 'Converted partition unexpectedly mounted'
    if swapon --noheadings -o NAME | grep -Fx "$device" >/dev/null; then
        fatal 'Converted raw backing is still conventional swap'
    fi
    # Only the chosen swap entry is removed from target fstab. Any unexpected
    # additional swap mapping requires manual resolution rather than guessing.
    [ -f /target/etc/fstab ] || fatal 'Target fstab missing after conversion'
    awk -v suuid="$former_uuid" -v partuuid="$uuid" -v dev="$device" '
        /^[[:space:]]*#/ {print; next}
        $3=="swap" && ($1=="UUID=" suuid || $1=="PARTUUID=" partuuid || $1==dev) {next}
        {print}
    ' /target/etc/fstab > "$WORK/fstab"
    cp "$WORK/fstab" /target/etc/fstab
    if grep -E '^[^#].*[[:space:]]swap[[:space:]]' /target/etc/fstab |
        grep -E "$former_uuid|$uuid|$device" >/dev/null; then
        fatal 'Conventional swap entry still references the raw backing partition'
    fi
    # No other ZRAM provisioning occurs until the partition conversion
    # (type, name, PARTUUID, signatures and active-swap state) has passed.

    review_install 'ZRAM generator package and all dependencies' systemd-zram-generator
    mkdir -p /target/etc/systemd/system/systemd-zram-setup@zram0.service.d \
        /target/etc/systemd/system /target/etc/sysctl.d /target/usr/local/sbin
    sed "s/YOUR_PARTUUID/$uuid/g" "$MEDIA/zram-generator.conf.template" >
        /target/etc/systemd/zram-generator.conf
    cp "$MEDIA/10-compressed-writeback.conf" \
        /target/etc/systemd/system/systemd-zram-setup@zram0.service.d/10-compressed-writeback.conf
    # Setup failure enters emergency, unlike a monitor failure.
    printf '[Unit]\nOnFailure=emergency.target\nOnFailureJobMode=replace-irreversibly\n' >
        /target/etc/systemd/system/systemd-zram-setup@zram0.service.d/20-failure-emergency.conf
    cp "$MEDIA/zram-pressure.sh" /target/usr/local/sbin/zram-pressure.sh
    chmod 755 /target/usr/local/sbin/zram-pressure.sh
    cp "$MEDIA/zram-pressure.service" /target/etc/systemd/system/zram-pressure.service
    cp "$MEDIA/90-zram-swappiness.conf" /target/etc/sysctl.d/90-zram-swappiness.conf
    # zswap must not intercept memory intended for zram.
    if ! grep -q 'zswap.enabled=0' /target/etc/default/grub; then
        sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"$/ zswap.enabled=0"/' /target/etc/default/grub
    fi
    run_target update-grub
    run_target systemctl enable zram-pressure.service
    # Confirm the root account is not locked; emergency requires it.
    capture in-target passwd -S root || fatal 'Cannot inspect emergency root account'
    grep -E '^root[[:space:]]+P[[:space:]]' "$WORK/output" >/dev/null ||
        fatal 'Separate local root password is not enabled for ZRAM emergency recovery'
    log "ZRAM raw backing: $device PARTUUID=$uuid size=$size; boot kernel/sysfs and generator require first-boot validation"
}

profile_tweaks() {
    [ -f /target/etc/default/grub ] || fatal 'GRUB defaults absent'
    # The user approved only removal of quiet and fsck.repair=no; retain
    # all other kernel arguments and normal GRUB behavior.
    sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ {
        s/(^|[[:space:]])quiet([[:space:]"])/\1\2/g
        /fsck\.repair=no/! s/"$/ fsck.repair=no"/
    }' /target/etc/default/grub
    run_target update-grub

    [ -f /target/etc/fstab ] || fatal 'Target fstab absent'
    awk '
      /^[[:space:]]*#/ {print; next}
      $2=="/" && $3=="ext4" {
        n=split($4, opts, ","); out=""
        for (i=1;i<=n;i++) {
          if (opts[i]=="atime" || opts[i]=="relatime" || opts[i]=="strictatime") continue
          if (opts[i] ~ /^errors=/ || opts[i]=="noatime") continue
          out=out (out? ",":"") opts[i]
        }
        $4=out ",noatime,errors=panic"
        changed++
      }
      {print}
      END {if (changed!=1) exit 2}
    ' /target/etc/fstab > "$WORK/tweaks-fstab" ||
        fatal 'Cannot identify exactly one ext4 root mount in fstab'
    cp "$WORK/tweaks-fstab" /target/etc/fstab

    # PermitRootLogin no is the only SSH override for this profile.
    mkdir -p /target/etc/ssh/sshd_config.d
    printf 'PermitRootLogin no\n' > /target/etc/ssh/sshd_config.d/01-my-cdd-root-login.conf
    capture in-target sshd -T || fatal 'OpenSSH configuration invalid'
    grep -Fx 'permitrootlogin no' "$WORK/output" >/dev/null ||
        fatal 'Effective OpenSSH root-login setting is not no'
    # Do not create a needless periodic-APT override if the policy is already
    # disabled. This guard is also checked after later selected profiles.
    ensure_manual_updates
}
ensure_manual_updates() {
    capture in-target apt-config dump || fatal 'Cannot inspect automatic APT settings'
    if grep -Ei 'APT::Periodic::Unattended-Upgrade[[:space:]]+"?([1-9]|yes|true)' "$WORK/output" >/dev/null; then
        mkdir -p /target/etc/apt/apt.conf.d
        printf 'APT::Periodic::Unattended-Upgrade "0";\n' >
            /target/etc/apt/apt.conf.d/99-my-cdd-manual-updates
        log 'Explicitly disabled an enabled unattended APT upgrade setting'
    fi
}


# Official OMV 8 installation from signed vendor repositories on Debian 13.
profile_omv() {
    # OMV warns that the resolver must work BEFORE package installation.
    review_install 'OMV prerequisites: resolver, utilities and signing tools' systemd-resolved psmisc gnupg ca-certificates curl
    capture in-target getent ahostsv4 packages.openmediavault.io ||
        fatal 'Target DNS unavailable; stop rather than invent network configuration'
    capture curl -fsSL --proto '=https' \
        -o /target/tmp/my-cdd-omv-key https://packages.openmediavault.io/archive.key ||
        fatal 'Official OMV signing key download failed'
    capture in-target gpg --show-keys --with-colons /tmp/my-cdd-omv-key ||
        fatal 'Vendor OMV signing key malformed'
    grep '^fpr:' "$WORK/output" >/dev/null ||
        fatal 'Vendor OMV key contained no fingerprint'
    run_target gpg --batch --yes --dearmor -o \
        /usr/share/keyrings/openmediavault-archive-keyring.gpg /tmp/my-cdd-omv-key
    rm -f /target/tmp/my-cdd-omv-key
    mkdir -p /target/etc/apt/sources.list.d
    cat > /target/etc/apt/sources.list.d/openmediavault.list <<'EOT'
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.org/public/ synchrony main
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.io/ synchrony main
EOT
    update_signed_apt
    capture in-target apt-cache policy openmediavault ||
        fatal 'Cannot inspect official OMV package origin'
    grep -F 'synchrony/main' "$WORK/output" >/dev/null ||
        fatal 'Signed official OMV 8 package repository unavailable'
    review_install 'OMV 8 package and dependencies' openmediavault
    capture in-target dpkg-query -W -f='${Version}\n' openmediavault ||
        fatal 'Cannot check installed OMV version'
    grep -E '^8\.' "$WORK/output" >/dev/null ||
        fatal 'Installed OMV is not version 8'

    # Native Debian Installer account: never hardcode a username.
    db_get passwd/username || fatal 'Missing Debian Installer username'
    admin=$RET
    case "$admin" in ''|*[!a-zA-Z0-9_.-]*) fatal 'Unexpected admin account name';; esac
    capture in-target id "$admin" || fatal 'Admin account unavailable'
    capture in-target getent group _ssh || fatal 'OMV _ssh access group unavailable'
    run_target usermod -aG sudo,_ssh "$admin"
    mkdir -p /target/etc/ssh/sshd_config.d
    printf 'PermitRootLogin no\n' > /target/etc/ssh/sshd_config.d/01-my-cdd-root-login.conf
    capture in-target sshd -T || fatal 'OMV SSH config invalid'
    grep -Fx 'permitrootlogin no' "$WORK/output" >/dev/null ||
        fatal 'OMV root SSH still enabled'

    # Only approved OMV customization: disable the entire cron-apt schedule.
    run_target omv-confdbadm populate
    run_target omv-env set -- OMV_CRON_APT_ENABLED false
    run_target omv-salt deploy run cronapt
    if [ -f /target/etc/cron.d/cron-apt ]; then
        if grep -Ev '^[[:space:]]*(#|$)' /target/etc/cron.d/cron-apt | grep -q .; then
            fatal 'OMV cron-apt still schedules automatic update checks'
        fi
    fi
    capture in-target omv-env get OMV_CRON_APT_ENABLED ||
        fatal 'Cannot confirm OMV cron-apt environment setting'
    grep -Ei '^(false|no|0)[[:space:]]*$' "$WORK/output" >/dev/null ||
        fatal 'OMV cron-apt was not disabled'
    capture in-target getent ahostsv4 packages.openmediavault.io ||
        fatal 'OMV installation disrupted target DNS; manual repair required'
    ensure_manual_updates
    run_target dpkg --audit
    log 'OMV 8 installed with cron-apt off; no NAS shares or plugins configured'
}

# Official Docker packages; daemon and socket MUST NOT start during install.
profile_docker() {
    review_install 'Docker signing prerequisites' ca-certificates curl
    mkdir -p /target/etc/apt/keyrings
    capture curl -fsSL --proto '=https' \
        -o /target/etc/apt/keyrings/docker.asc https://download.docker.com/linux/debian/gpg ||
        fatal 'Official Docker signing key download failed'
    chmod 644 /target/etc/apt/keyrings/docker.asc
    grep -Fx 'VERSION_CODENAME=trixie' /target/etc/os-release >/dev/null ||
        fatal 'Docker requires installed Debian 13 trixie'
    cat > /target/etc/apt/sources.list.d/docker.sources <<'EOT'
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOT
    update_signed_apt
    for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
        capture in-target apt-cache policy "$pkg" || fatal "Cannot inspect $pkg"
        grep -F 'download.docker.com/linux/debian' "$WORK/output" >/dev/null ||
            fatal "$pkg lacks the official signed Docker repository"
    done
    # Installer-only startup prevention targeting ONLY Docker service/socket.
    # Unlike disabling units after the transaction, these masks are applied
    # before any maintainer scripts can request startup.
    capture systemctl --root=/target mask docker.service docker.socket ||
        fatal 'Could not prevent Docker startup before package installation'
    simulate_target install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    check_critical_removals
    review_plan 'Docker: complete official package transaction, daemon/socket suppressed' "$WORK/plan"
    run_target apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    capture systemctl --root=/target unmask docker.service docker.socket ||
        fatal 'Could not remove temporary Docker startup suppression'
    capture systemctl --root=/target disable docker.service docker.socket ||
        fatal 'Could not disable Docker daemon and socket for first boot'
    for unit in docker.service docker.socket; do
        # systemctl is-enabled exits nonzero for the desired "disabled"
        # state; inspect its output rather than treating status 1 as failure.
        capture systemctl --root=/target is-enabled "$unit" || :
        grep -Fx disabled "$WORK/output" >/dev/null ||
            fatal "$unit is not disabled for first boot"
    done
    run_target dpkg --audit
    log 'Docker packages installed; Docker daemon and socket disabled; no containers started'
}
