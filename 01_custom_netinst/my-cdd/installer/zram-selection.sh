#!/bin/sh
# ZRAM backing discovery and native Debconf selection, sourced by profile-actions.sh.
# No partition is created, formatted or modified by these functions.
ZRAM_SWAP_GUID=0657fd6d-a4ab-43c4-84e5-0933c84b4f4f
ZRAM_DATA_GUID=0fc63daf-8483-4772-8e79-3d69d8477de4

zram_ref_matches() (
    # Return success only when a target fstab source resolves to the exact
    # selected GPT partition. An arbitrary same-disk swap is NOT a match.
    zr_ref=$1
    zr_part=$2
    zr_dev=$3
    zr_swap_uuid=$4
    zr_swap_label=$5
    case "$zr_ref" in
        PARTUUID=*) [ "$(printf '%s' "${zr_ref#PARTUUID=}" | tr '[:upper:]' '[:lower:]')" = "$zr_part" ] ;;
        UUID=*) [ -n "$zr_swap_uuid" ] &&
            [ "$(printf '%s' "${zr_ref#UUID=}" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$zr_swap_uuid" | tr '[:upper:]' '[:lower:]')" ] &&
            [ "$(readlink -f -- "$(blkid -t "UUID=$zr_swap_uuid" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
        LABEL=*) [ -n "$zr_swap_label" ] && [ "${zr_ref#LABEL=}" = "$zr_swap_label" ] &&
            [ "$(readlink -f -- "$(blkid -t "LABEL=$zr_swap_label" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
        # PARTLABEL is not unique and cannot prove which raw partition
        # belongs to the target. Do not resolve it automatically.
        PARTLABEL=*) return 1 ;;
        /dev/*) [ "$(readlink -f -- "$zr_ref" 2>/dev/null || true)" = "$zr_dev" ] ;;
        *) return 1 ;;
    esac
)

zram_collect_candidates() {
    # The target fstab reflects this installation's actual partman assignment;
    # it also supports swap partitions reused from a previous installation.
    [ -f /target/etc/fstab ] || fatal 'No installed-target fstab: cannot identify assigned swap'
    [ -n "$(findmnt -nr -M /target -o SOURCE 2>/dev/null)" ] ||
        fatal 'Installed target root is not a separately mounted filesystem'
    : > "$WORK/zram-candidate-map"
    capture lsblk -pnro PATH,TYPE ||
        fatal 'Cannot enumerate block devices for ZRAM backing'
    cp "$WORK/output" "$WORK/zram-block-list"
    while read -r zc_path zc_type; do
        [ "$zc_type" = part ] || continue
        case "$zc_path" in /dev/*) ;; *) continue ;; esac
        zc_device="$(readlink -f -- "$zc_path")"
        [ -b "$zc_device" ] || continue
        zc_partuuid="$(lsblk -dnro PARTUUID "$zc_device" | tr '[:upper:]' '[:lower:]')"
        printf '%s\n' "$zc_partuuid" |
            grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' ||
            continue
        zc_parent="$(lsblk -dnro PKNAME "$zc_device")"
        [ -n "$zc_parent" ] && [ "$(lsblk -dnro PTTYPE "/dev/$zc_parent")" = gpt ] || continue
        zc_guid="$(lsblk -dnro PARTTYPE "$zc_device" | tr '[:upper:]' '[:lower:]')"
        zc_signature="$(blkid -p -s TYPE -o value "$zc_device" 2>/dev/null || true)"
        zc_kind=''
        if [ "$zc_guid" = "$ZRAM_SWAP_GUID" ] && [ "$zc_signature" = swap ]; then
            zc_kind=swap
        elif [ "$zc_guid" = "$ZRAM_DATA_GUID" ] &&
            [ "$(lsblk -dnro PARTLABEL "$zc_device")" = zram-writeback ] &&
            [ -z "$zc_signature" ]; then
            zc_kind=existing-raw
        fi
        [ -n "$zc_kind" ] || continue
        ! grep -q "^$zc_partuuid|" "$WORK/zram-candidate-map" ||
            fatal 'Duplicate GPT partition identity; refusing ZRAM selection'
        zc_size="$(lsblk -dnro SIZE "$zc_device")"
        case "$zc_size" in ''|*'|'*|*','*) fatal 'Cannot display safe partition capacity' ;; esac
        printf '%s|%s|%s|%s\n' "$zc_partuuid" "$zc_device" "$zc_kind" "$zc_size" >> "$WORK/zram-candidate-map"
    done < "$WORK/zram-block-list"
    [ -s "$WORK/zram-candidate-map" ] ||
        fatal 'No eligible GPT swap or existing raw zram-writeback partition. Return to partitioning or deselect ZRAM.'
}

zram_choose_candidate() {
    # Automatic selection is authorized ONLY by one exact swap reference in
    # this newly installed target, never by partition age or disk proximity.
    awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $3 == "swap" {print $1}' \
        /target/etc/fstab > "$WORK/zram-target-swap-refs"
    za_count=0
    za_uuid=''
    if [ "$(wc -l < "$WORK/zram-target-swap-refs")" -eq 1 ]; then
        za_ref="$(cat "$WORK/zram-target-swap-refs")"
        while IFS='|' read -r za_id za_dev za_kind za_size; do
            za_swap_uuid="$(blkid -s UUID -o value "$za_dev" 2>/dev/null || true)"
            za_swap_label="$(blkid -s LABEL -o value "$za_dev" 2>/dev/null || true)"
            if [ "$za_kind" = swap ] &&
                zram_ref_matches "$za_ref" "$za_id" "$za_dev" "$za_swap_uuid" "$za_swap_label"; then
                za_count=$((za_count + 1))
                za_uuid=$za_id
            fi
        done < "$WORK/zram-candidate-map"
    fi
    if [ "$za_count" -eq 1 ]; then
        zram_uuid=$za_uuid
        zram_selection=automatic
        log "ZRAM assigned backing verified from target fstab: PARTUUID=$zram_uuid"
    else
        # Choices-C holds canonical PARTUUIDs; Choices holds display-only
        # device/size/type labels. The first choice is deliberately safe.
        za_ids=none
        za_labels='Stop without changing a partition'
        while IFS='|' read -r za_id za_dev za_kind za_size; do
            za_ids="$za_ids, $za_id"
            za_labels="$za_labels, $za_dev ($za_size; $za_kind; PARTUUID $za_id)"
        done < "$WORK/zram-candidate-map"
        db_subst my-cdd/zram-backing-select MYCDD_BACKING_IDS "$za_ids" ||
            fatal 'Cannot construct canonical ZRAM partition choices'
        db_subst my-cdd/zram-backing-select MYCDD_BACKING_LABELS "$za_labels" ||
            fatal 'Cannot display ZRAM partition choices'
        db_set my-cdd/zram-backing-select none || fatal 'Cannot reset ZRAM selection to safe default'
        db_fset my-cdd/zram-backing-select seen false || fatal 'Cannot present ZRAM selection'
        db_input critical my-cdd/zram-backing-select || fatal 'ZRAM partition chooser unavailable'
        db_go || fatal 'ZRAM partition chooser cancelled; no backing changed'
        db_get my-cdd/zram-backing-select || fatal 'Cannot read ZRAM partition choice'
        zram_uuid=$RET
        [ "$zram_uuid" != none ] && [ -n "$zram_uuid" ] ||
            fatal 'No backing partition was selected; nothing modified'
        zram_selection=manual
        log "USER SELECTED ZRAM backing in native partition list: PARTUUID=$zram_uuid"
    fi
    zram_device=''
    zram_kind=''
    zram_size=''
    zram_hits=0
    while IFS='|' read -r za_id za_dev za_kind za_size; do
        if [ "$za_id" = "$zram_uuid" ]; then
            zram_hits=$((zram_hits + 1))
            zram_device=$za_dev
            zram_kind=$za_kind
            zram_size=$za_size
        fi
    done < "$WORK/zram-candidate-map"
    [ "$zram_hits" -eq 1 ] || fatal 'Chosen partition is not a unique verified candidate'
    zram_validate_candidate
}

zram_validate_candidate() {
    # Re-read all identity and usage metadata, including immediately before
    # a destructive change. Never trust a stale menu label or device name.
    zc_link="/dev/disk/by-partuuid/$zram_uuid"
    [ -b "$zc_link" ] || fatal 'Selected PARTUUID block device is missing'
    [ "$(readlink -f -- "$zc_link")" = "$zram_device" ] ||
        fatal 'Backing device has changed since selection'
    [ "$(lsblk -dnro TYPE "$zram_device")" = part ] ||
        fatal 'ZRAM backing is no longer a partition'
    parent="$(lsblk -dnro PKNAME "$zram_device")"
    partn="$(lsblk -dnro PARTN "$zram_device")"
    case "$parent" in ''|*[!a-zA-Z0-9_-]*) fatal 'Unsafe parent disk identity' ;; esac
    case "$partn" in ''|*[!0-9]*) fatal 'Unsafe partition number' ;; esac
    disk="/dev/$parent"
    [ -b "$disk" ] && [ "$(lsblk -dnro PTTYPE "$disk")" = gpt ] ||
        fatal 'Backing partition is not on a GPT disk'
    [ "$(lsblk -dnro PARTUUID "$zram_device" | tr '[:upper:]' '[:lower:]')" = "$zram_uuid" ] ||
        fatal 'Backing PARTUUID changed before conversion'
    zc_guid="$(lsblk -dnro PARTTYPE "$zram_device" | tr '[:upper:]' '[:lower:]')"
    zc_sig="$(blkid -p -s TYPE -o value "$zram_device" 2>/dev/null || true)"
    case "$zram_kind" in
        swap)
            [ "$zc_guid" = "$ZRAM_SWAP_GUID" ] && [ "$zc_sig" = swap ] ||
                fatal 'Backing is no longer a conventional GPT swap partition' ;;
        existing-raw)
            [ "$zc_guid" = "$ZRAM_DATA_GUID" ] && [ -z "$zc_sig" ] &&
                [ "$(lsblk -dnro PARTLABEL "$zram_device")" = zram-writeback ] ||
                fatal 'Previously converted backing no longer matches raw GPT identity' ;;
        *) fatal 'Unknown ZRAM backing class' ;;
    esac
    # A partition which is part of a mapped/RAID/storage stack is not safe.
    for zc_holder in "/sys/class/block/$(basename "$zram_device")/holders/"*; do
        [ ! -e "$zc_holder" ] || fatal 'Selected ZRAM backing is held by another block device'
    done
    if lsblk -dnro MOUNTPOINTS "$zram_device" |
        grep -Ev '^[[:space:]]*(\[SWAP\])?[[:space:]]*$' | grep -q .; then
        fatal 'Selected backing has filesystem mounts; refusing conversion'
    fi
    if [ -n "$(findmnt -rn -S "$zram_device" -o TARGET 2>/dev/null || true)" ]; then
        fatal 'Selected backing is mounted; refusing conversion'
    fi
}

zram_read_active_swap() {
    active_used=''
    swapon --noheadings --bytes -o NAME,USED > "$WORK/zram-active-swaps" ||
        fatal 'Cannot enumerate installer-active swap'
    while read -r zs_path zs_used; do
        [ -n "$zs_path" ] || continue
        if [ "$(readlink -f -- "$zs_path" 2>/dev/null || true)" = "$zram_device" ]; then
            [ -z "$active_used" ] || fatal 'Duplicate active-swap mapping for the chosen partition'
            case "$zs_used" in ''|*[!0-9]*) fatal 'Invalid used-swap byte count' ;; esac
            active_used=$zs_used
        fi
    done < "$WORK/zram-active-swaps"
}

zram_prepare_fstab() {
    # Build the edited target fstab BEFORE modifying any partition. Preserve
    # every unrelated line byte-for-byte and remove only matching swap lines.
    cp /target/etc/fstab "$WORK/zram-original-fstab" ||
        fatal 'Cannot snapshot installed fstab before ZRAM conversion'
    : > "$WORK/zram-safe-fstab"
    while IFS= read -r zf_line || [ -n "$zf_line" ]; do
        zf_ref="$(printf '%s\n' "$zf_line" |
            awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $3 == "swap" {print $1}')"
        case "$zf_ref" in
            PARTLABEL=*) fatal 'Ambiguous PARTLABEL swap reference in target fstab; resolve it before ZRAM conversion' ;;
            UUID=*)
                case "$former_uuid" in
                    '') ;;
                    *) if [ "${zf_ref#UUID=}" = "$former_uuid" ] &&
                        ! zram_ref_matches "$zf_ref" "$zram_uuid" "$zram_device" "$former_uuid" "$former_label"; then
                        fatal 'Target fstab swap UUID is duplicated or cannot be resolved uniquely'
                    fi ;;
                esac ;;
            LABEL=*)
                case "$former_label" in
                    '') ;;
                    *) if [ "${zf_ref#LABEL=}" = "$former_label" ] &&
                        ! zram_ref_matches "$zf_ref" "$zram_uuid" "$zram_device" "$former_uuid" "$former_label"; then
                        fatal 'Target fstab swap LABEL is duplicated or cannot be resolved uniquely'
                    fi ;;
                esac ;;
        esac
        if [ -n "$zf_ref" ] &&
            zram_ref_matches "$zf_ref" "$zram_uuid" "$zram_device" "$former_uuid" "$former_label"; then
            log "Removing confirmed backing conventional-swap fstab reference: $zf_ref"
            continue
        fi
        printf '%s\n' "$zf_line" >> "$WORK/zram-safe-fstab"
    done < "$WORK/zram-original-fstab"
    # Never leave a second conventionally activated swap configured in the
    # new target; modifying or deactivating that other device is NOT approved.
    if awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $3 == "swap" {print $1}' \
        "$WORK/zram-safe-fstab" | grep -q .; then
        fatal 'Another target swap entry would remain; do not enable independent swap alongside required ZRAM'
    fi
}
