#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_zram() {
    # ordered-selection requires the separately selected kernel profile,
    # and the native stage-11 runner executes it before ZRAM. Any failure
    # prevents reaching this handler; no duplicate completion marker needed.
    [ -r "$MEDIA/zram-generator.conf.template" ] ||
        fatal 'Original ZRAM generator source missing'
    [ -r "$MEDIA/zram-writeback-selection.sh" ] ||
        fatal 'Installer ZRAM selection helper missing'
    . "$MEDIA/zram-writeback-selection.sh"
    # The installer is a minimal udeb environment. The official parted-udeb
    # supplies the installer-native GPT editing CLI and matching udeb libraries.
    # Simple-CDD stages it via the build-only installer-media.udebs profile;
    # anna-install loads it only for an explicitly chosen ZRAM profile.
    # Do not copy normal target binaries or libraries into Debian Installer.
    if ! command -v parted >/dev/null 2>&1; then
        command -v anna-install >/dev/null 2>&1 ||
            fatal 'Native Debian Installer anna-install is unavailable for parted-udeb'
        progress_status 'Loading installer partition tools'
        progress_handoff
        capture anna-install parted-udeb ||
            fatal 'Could not load official parted-udeb into Debian Installer'
    fi
    command -v parted >/dev/null 2>&1 ||
        fatal 'Official parted-udeb did not provide a usable parted command'
    # Load installer-native blkid from util-linux-udeb when absent.
    if ! command -v blkid >/dev/null 2>&1; then
        progress_status 'Loading installer block-device tools'
        progress_handoff
        capture anna-install util-linux-udeb ||
            fatal 'Could not load official util-linux-udeb into Debian Installer'
    fi
    # Check all remaining installer utilities before a destructive conversion.
    # Prerequisites belong to this one-time ZRAM profile operation.
    for utility in parted blkid busybox readlink cmp awk sed; do
        command -v "$utility" >/dev/null 2>&1 ||
            fatal "ZRAM requires unavailable Debian Installer utility: $utility"
    done
    for applet in dd swapoff; do
        busybox --list | grep -qx "$applet" ||
            fatal "ZRAM requires unavailable Debian Installer BusyBox applet: $applet"
    done
    [ -d /sys/class/block ] && [ -r /proc/swaps ] &&
        [ -r /proc/self/mountinfo ] && [ -d /dev/disk/by-partuuid ] ||
        fatal 'ZRAM cannot inspect installer block devices, swaps, mounts or PARTUUID links'
    progress_status 'Inspecting writeback partition candidates'
    zram_collect_candidates
    zram_choose_candidate
    uuid=$zram_uuid
    device=$zram_device
    size=$zram_size
    former_uuid="$(blkid -s UUID -o value "$device" 2>/dev/null || true)"
    former_label="$(blkid -s LABEL -o value "$device" 2>/dev/null || true)"
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

    # Debian Installer may activate the selected swap partition temporarily.
    # Deactivate ONLY this confirmed partition, with the separately approved
    # targeted swapoff. Do not veto an empty installer swap on RAM estimates.
    zram_read_active_swap
    if [ -n "$active_used" ]; then
        db_subst my-cdd/zram-swapoff MYCDD_PARTITION "$device" ||
            fatal 'Cannot show exact swapoff target'
        db_subst my-cdd/zram-swapoff MYCDD_USED "$active_used" ||
            fatal 'Cannot show selected swap usage'
        yes_no my-cdd/zram-swapoff ||
            fatal 'Targeted swapoff was not separately approved'
        zram_validate_candidate
        zram_read_active_swap
        if [ -n "$active_used" ]; then
            capture busybox swapoff "$device" ||
                fatal 'Targeted swapoff failed; GPT and signatures left unchanged'
        fi
        zram_read_active_swap
        [ -z "$active_used" ] ||
            fatal 'Selected partition still active after targeted swapoff'
    fi
    zram_validate_candidate
    zram_read_active_swap
    [ -z "$active_used" ] ||
        fatal 'Selected backing is active swap; cannot overwrite its signature'

    # Write only the approved partition's first 1 MiB, never its parent disk.
    # The GPT layout and PARTUUID are preserved; no filesystem is created.
    cmp -s /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Installed target fstab changed after verification; conversion stopped'
    log "USER APPROVED CONVERSION: $device, PARTUUID=$uuid, size=$size"
    progress_status 'Preparing the explicitly approved writeback partition'
    capture busybox dd if=/dev/zero of="$device" bs=4096 count=256 conv=notrunc,fsync ||
        fatal 'Could not erase swap signature from the confirmed backing partition'
    capture parted -s "$disk" type "$partn" "$ZRAM_DATA_GUID" ||
        fatal 'Could not change only the confirmed GPT partition type'
    capture parted -s "$disk" name "$partn" zram-writeback ||
        fatal 'Could not set confirmed GPT PARTLABEL'
    zram_partition_info "$device" ||
        fatal 'Cannot re-probe converted GPT partition'
    [ "$zi_type" = "$ZRAM_DATA_GUID" ] && [ "$zi_label" = zram-writeback ] ||
        fatal 'Converted backing GPT type or name is incorrect'
    [ -z "$zi_signature" ] ||
        fatal 'Converted backing still has a detected filesystem/swap signature'
    [ "$zi_partuuid" = "$uuid" ] ||
        fatal 'PARTUUID unexpectedly changed without partition recreation'
    ! zram_is_mounted ||
        fatal 'Converted partition unexpectedly mounted'
    zram_read_active_swap
    [ -z "$active_used" ] ||
        fatal 'Converted raw backing is still conventional swap'
    # This exact filtered fstab was prepared before destructive conversion;
    # preserve every unrelated swap line and refuse residual aliases.
    cmp -s /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Installed target fstab changed after conversion; manual repair is required'
    # Stage the verified fstab on the target filesystem, then replace it
    # atomically. A failed copy must not truncate the active target fstab.
    fstab_tmp="/target/etc/.fstab.my-cdd.$$"
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
    # One drop-in covers pre-initialization compressed writeback and setup failure.
    cp "$MEDIA/override.conf" \
        /target/etc/systemd/system/systemd-zram-setup@zram0.service.d/override.conf
    cp "$MEDIA/zram-pressure.sh" /target/usr/local/sbin/zram-pressure.sh
    chmod 755 /target/usr/local/sbin/zram-pressure.sh
    cp "$MEDIA/zram-pressure.service" /target/etc/systemd/system/zram-pressure.service
    cp "$MEDIA/90-zram.conf" /target/etc/sysctl.d/90-zram.conf
    # zswap must not intercept memory intended for zram.
    if ! grep -q 'zswap.enabled=0' /target/etc/default/grub; then
        sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"$/ zswap.enabled=0"/' /target/etc/default/grub
    fi
    run_target update-grub
    run_target systemctl enable zram-pressure.service
    log "ZRAM raw backing: $device PARTUUID=$uuid size=$size; boot kernel/sysfs and generator require first-boot validation"
}

