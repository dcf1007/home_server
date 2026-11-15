#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_zram() {
    [ -f "$LOG_DIR/my-cdd-completed/ensure-7x-kernel" ] ||
        fatal 'ZRAM cannot run without the separately completed Ensure 7.x kernel profile'
    [ -r "$MEDIA/zram-generator.conf.template" ] ||
        fatal 'Original ZRAM generator source missing'
    [ -r "$MEDIA/zram-selection.sh" ] ||
        fatal 'Installer ZRAM selection helper missing'
    . "$MEDIA/zram-selection.sh"
    # The installer is a minimal udeb environment: it need not contain
    # lsblk/findmnt/wipefs. Check required host and installed-target tools
    # before asking for a destructive partition conversion.
    zram_check_utilities
    zram_collect_candidates
    zram_choose_candidate
    uuid=$zram_uuid
    device=$zram_device
    size=$zram_size
    former_uuid="$(zram_blkid -s UUID -o value "$device" 2>/dev/null || true)"
    former_label="$(zram_blkid -s LABEL -o value "$device" 2>/dev/null || true)"
    zram_prepare_fstab

    # The automatically detected partition still requires exactly the same
    # destructive confirmation as a manually selected partition. A partition
    # shared with another OS loses its conventional swap identity.
    db_subst my-cdd/zram-destructive MYCDD_PARTITION "$device" ||
        fatal 'Unable to show partition path for destructive confirmation'
    db_subst my-cdd/zram-destructive MYCDD_PARTUUID "$uuid" ||
        fatal 'Unable to show exact PARTUUID for destructive confirmation'
    db_subst my-cdd/zram-destructive MYCDD_SIZE "$size" ||
        fatal 'Unable to show partition capacity for destructive confirmation'
    db_subst my-cdd/zram-destructive MYCDD_DISK "$disk" ||
        fatal 'Unable to show selected parent disk'
    db_subst my-cdd/zram-destructive MYCDD_SELECTION "$zram_selection" ||
        fatal 'Unable to show selection provenance'
    yes_no my-cdd/zram-destructive ||
        fatal 'User declined destructive ZRAM backing conversion'

    # Debian Installer may itself activate even newly created swap. Leave
    # unrelated swap devices completely untouched; never use swapoff -a.
    zram_read_active_swap
    if [ -n "$active_used" ]; then
        available_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
        total_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
        case "$available_kb:$total_kb" in
            *[!0-9:]*|:*|*:) fatal 'Cannot assess installer memory pressure for swapoff' ;;
        esac
        if [ -r /proc/pressure/memory ]; then
            log "Installer memory PSI before any swapoff: $(head -n 2 /proc/pressure/memory | tr '\n' ';')"
        fi
        reserve_kb=$((total_kb / 8))
        [ "$reserve_kb" -ge 262144 ] || reserve_kb=262144
        used_kb=$((active_used / 1024 + 1))
        [ "$available_kb" -gt "$((used_kb + reserve_kb))" ] ||
            fatal 'RAM cannot cover selected swap usage plus a safety reserve; no zram_swapoff attempted'
        db_subst my-cdd/zram-zram_swapoff MYCDD_PARTITION "$device" ||
            fatal 'Cannot show exact zram_swapoff target'
        db_subst my-cdd/zram-zram_swapoff MYCDD_USED "$active_used" ||
            fatal 'Cannot show selected swap usage'
        yes_no my-cdd/zram-zram_swapoff ||
            fatal 'Targeted zram_swapoff was not separately approved'
        # Re-evaluate memory and identity immediately before swapoff, too.
        zram_validate_candidate
        zram_read_active_swap
        if [ -n "$active_used" ]; then
            available_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
            case "$available_kb" in ''|*[!0-9]*) fatal 'RAM check failed immediately before swapoff' ;; esac
            used_kb=$((active_used / 1024 + 1))
            [ "$available_kb" -gt "$((used_kb + reserve_kb))" ] ||
                fatal 'Insufficient remaining RAM for a safe targeted swapoff'
            capture zram_swapoff "$device" ||
                fatal 'Targeted zram_swapoff failed; GPT and signatures left unchanged'
        fi
        zram_read_active_swap
        [ -z "$active_used" ] ||
            fatal 'Selected partition still active after targeted swapoff'
    fi
    zram_validate_candidate
    zram_read_active_swap
    [ -z "$active_used" ] ||
        fatal 'Selected backing was reactivated as swap before conversion'

    # The only destructive partition commands target the one confirmed GPT
    # partition. No automatic partition creation, sizing or formatting.
    cmp -s /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Installed target fstab changed after verification; conversion stopped'
    log "USER APPROVED CONVERSION: $device, PARTUUID=$uuid, size=$size"
    capture parted -s "$disk" type "$partn" 0FC63DAF-8483-4772-8E79-3D69D8477DE4 ||
        fatal 'Could not change only the confirmed GPT partition type'
    capture parted -s "$disk" name "$partn" zram-writeback ||
        fatal 'Could not set confirmed GPT PARTLABEL'
    capture zram_wipefs -a "$device" ||
        fatal 'Could not remove signatures from only the confirmed partition'
    [ "$(zram_lsblk -dnro PARTUUID "$device" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$uuid" | tr '[:upper:]' '[:lower:]')" ] ||
        fatal 'PARTUUID changed unexpectedly after conversion'
    [ "$(zram_lsblk -dnro PARTLABEL "$device")" = zram-writeback ] ||
        fatal 'Converted GPT PARTLABEL not visible'
    [ "$(zram_lsblk -dnro PARTTYPE "$device" | tr '[:upper:]' '[:lower:]')" = 0fc63daf-8483-4772-8e79-3d69d8477de4 ] ||
        fatal 'Confirmed partition has the wrong GPT type after conversion'
    [ -z "$(zram_blkid -p -s TYPE -o value "$device" 2>/dev/null || true)" ] ||
        fatal 'Backing partition still has a filesystem/swap signature'
    if zram_lsblk -dnro MOUNTPOINTS "$device" |
        grep -Ev '^[[:space:]]*$' | grep -q .; then
        fatal 'Converted partition unexpectedly mounted or active'
    fi
    zram_read_active_swap
    [ -z "$active_used" ] ||
        fatal 'Converted raw backing is still conventional swap'
    # This exact filtered fstab was prepared before destructive conversion;
    # preserve every unrelated swap line and refuse residual aliases.
    cmp -s /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Installed target fstab changed after conversion; manual repair is required'
    # Stage the verified fstab on the target filesystem, then replace it
    # atomically. A failed copy must not truncate the active target fstab.
    fstab_tmp="/target/etc/.fstab.my-cdd.$"
    [ ! -e "$fstab_tmp" ] ||
        fatal 'Unexpected temporary target fstab path already exists'
    cp "$WORK/zram-safe-fstab" "$fstab_tmp" ||
        fatal 'Could not stage target fstab after partition conversion'
    chmod 644 "$fstab_tmp" ||
        fatal 'Could not set staged target fstab permissions'
    mv -f -- "$fstab_tmp" /target/etc/fstab ||
        fatal 'Could not atomically install the verified target fstab'
    awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $3 == "swap" {print $1}' \
        /target/etc/fstab > "$WORK/zram-residual-swaps"
    while IFS= read -r swap_ref; do
        if zram_ref_matches "$swap_ref" "$uuid" "$device" "$former_uuid" "$former_label"; then
            fatal 'Confirmed backing is still referenced as conventional swap'
        fi
    done < "$WORK/zram-residual-swaps"
    # No other ZRAM provisioning occurs until the partition conversion
    # (type, name, PARTUUID, signatures and active-swap state) has passed.

    review_install 'ZRAM generator package and all dependencies' systemd-zram-generator
    mkdir -p /target/etc/systemd/system/systemd-zram-setup@zram0.service.d \
        /target/etc/systemd/system /target/etc/sysctl.d /target/usr/local/sbin
    sed "s/YOUR_PARTUUID/$uuid/g" "$MEDIA/zram-generator.conf.template" > \
        /target/etc/systemd/zram-generator.conf
    [ "$(grep -o "$uuid" /target/etc/systemd/zram-generator.conf | wc -l)" -eq 2 ] &&
        ! grep -q YOUR_PARTUUID /target/etc/systemd/zram-generator.conf ||
        fatal 'ZRAM generator configuration contains unresolved or mismatched backing identity'
    cp "$MEDIA/10-compressed-writeback.conf" \
        /target/etc/systemd/system/systemd-zram-setup@zram0.service.d/10-compressed-writeback.conf
    # Setup failure enters emergency, unlike a monitor failure.
    printf '[Unit]\nOnFailure=emergency.target\nOnFailureJobMode=replace-irreversibly\n' > \
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
    # Defense in depth: common preflight has already established recovery access
    # before any selected profile (including this partition conversion).
    capture in-target passwd -S root || fatal 'Cannot inspect emergency root account'
    grep -E '^root[[:space:]]+P[[:space:]]' "$WORK/output" >/dev/null ||
        fatal 'Separate local root password is not enabled for ZRAM emergency recovery'
    log "ZRAM raw backing: $device PARTUUID=$uuid size=$size; boot kernel/sysfs and generator require first-boot validation"
}

