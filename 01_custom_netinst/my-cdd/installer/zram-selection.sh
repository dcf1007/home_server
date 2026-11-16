#!/bin/sh
# Native Debian Installer ZRAM tools; no target util-linux block commands.
# Standard GPT PARTITION TYPE GUIDs (not disk-specific PARTUUIDs):
#   Linux swap:                 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
#   Linux filesystem/data:      0FC63DAF-8483-4772-8E79-3D69D8477DE4 (gdisk 8300)
# The ZRAM backing remains raw/unformatted. GNU Parted's "type" command
# requires the GPT type GUID, whereas blkid reports it for eligibility checks.
ZRAM_SWAP_GUID=0657fd6d-a4ab-43c4-84e5-0933c84b4f4f
ZRAM_DATA_GUID=0fc63daf-8483-4772-8e79-3d69d8477de4

zram_blkid() { blkid "$@"; }

zram_check_utilities() {
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
}

zram_probe_value() {
    printf '%s\n' "$zi_output" | sed -n "s/^$1=//p" | head -n 1
}

# The native blkid low-level probe supplies GPT PART_ENTRY_* fields even on
# raw partitions. sysfs exposes partition topology and size in 512B sectors.
zram_partition_info() {
    zi_device=$1
    [ -b "$zi_device" ] || return 1
    zi_name=$(basename "$zi_device")
    case "$zi_name" in ''|*[!a-zA-Z0-9_.-]*) return 1 ;; esac
    zi_sys="/sys/class/block/$zi_name"
    [ -r "$zi_sys/partition" ] && [ -r "$zi_sys/size" ] || return 1
    zi_partn=$(cat "$zi_sys/partition") || return 1
    zi_sectors=$(cat "$zi_sys/size") || return 1
    case "$zi_partn:$zi_sectors" in ''|*[!0-9:]*|:*|*:) return 1 ;; esac
    zi_parent=$(basename "$(dirname "$(readlink -f "$zi_sys")")") || return 1
    case "$zi_parent" in ''|*[!a-zA-Z0-9_.-]*) return 1 ;; esac
    zi_disk="/dev/$zi_parent"
    [ -b "$zi_disk" ] || return 1
    [ "$(blkid -p -s PTTYPE -o value "$zi_disk" 2>/dev/null)" = gpt ] || return 1
    zi_output=$(blkid -p -o export "$zi_device" 2>/dev/null || true)
    [ "$(zram_probe_value PART_ENTRY_SCHEME)" = gpt ] || return 1
    zi_partuuid=$(zram_probe_value PART_ENTRY_UUID | tr '[:upper:]' '[:lower:]')
    printf '%s\n' "$zi_partuuid" |
        grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' ||
        return 1
    zi_type=$(zram_probe_value PART_ENTRY_TYPE | tr '[:upper:]' '[:lower:]')
    [ "$(zram_probe_value PART_ENTRY_NUMBER)" = "$zi_partn" ] || return 1
    zi_entry_disk=$(zram_probe_value PART_ENTRY_DISK)
    if [ -n "$zi_entry_disk" ]; then
        [ "$zi_entry_disk" = "$(cat "/sys/class/block/$zi_parent/dev")" ] || return 1
    fi
    zi_label=$(zram_probe_value PART_ENTRY_NAME)
    zi_signature=$(zram_probe_value TYPE)
    zi_size_kib=$((zi_sectors / 2))
}

zram_is_mounted() {
    zm_name=$(basename "$zram_device")
    zm_id=$(cat "/sys/class/block/$zm_name/dev") ||
        fatal 'Cannot inspect selected partition mount identity'
    awk -v id="$zm_id" '$3 == id { found=1 } END { exit !found }' /proc/self/mountinfo
}

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
            [ "$(readlink -f -- "$(zram_blkid -t "UUID=$zr_swap_uuid" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
        LABEL=*) [ -n "$zr_swap_label" ] && [ "${zr_ref#LABEL=}" = "$zr_swap_label" ] &&
            [ "$(readlink -f -- "$(zram_blkid -t "LABEL=$zr_swap_label" -o device 2>/dev/null || true)" 2>/dev/null || true)" = "$zr_dev" ] ;;
        # PARTLABEL is not unique and cannot prove which raw partition
        # belongs to the target. Do not resolve it automatically.
        PARTLABEL=*) return 1 ;;
        /dev/*) [ "$(readlink -f -- "$zr_ref" 2>/dev/null || true)" = "$zr_dev" ] ;;
        *) return 1 ;;
    esac
)

zram_collect_candidates() {
    # Prefer swap in this target's fstab; allow manually selected existing raw backing.
    [ -f /target/etc/fstab ] || fatal 'No installed-target fstab: cannot identify assigned swap'
    [ -r /proc/self/mountinfo ] &&
        awk '$5 == "/target" { found=1 } END { exit !found }' /proc/self/mountinfo ||
        fatal 'Installed target root is not a separately mounted filesystem'
    : > "$WORK/zram-candidate-map"
    for zc_entry in /sys/class/block/*/partition; do
        [ -r "$zc_entry" ] || continue
        zc_device="/dev/$(basename "$(dirname "$zc_entry")")"
        zram_partition_info "$zc_device" || continue
        zc_kind=''
        if [ "$zi_type" = "$ZRAM_SWAP_GUID" ] && [ "$zi_signature" = swap ]; then
            zc_kind=swap
        elif [ "$zi_type" = "$ZRAM_DATA_GUID" ] &&
            [ "$zi_label" = zram-writeback ] &&
            { [ -z "$zi_signature" ] || [ "$zi_signature" = swap ]; }; then
            zc_kind=existing-raw
        fi
        [ -n "$zc_kind" ] || continue
        ! grep -q "^$zi_partuuid|" "$WORK/zram-candidate-map" ||
            fatal 'Duplicate GPT partition identity; refusing ZRAM selection'
        zc_size="$zi_size_kib KiB"
        printf '%s|%s|%s|%s\n' "$zi_partuuid" "$zc_device" "$zc_kind" "$zc_size" >> "$WORK/zram-candidate-map"
    done
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
            za_swap_uuid="$(zram_blkid -s UUID -o value "$za_dev" 2>/dev/null || true)"
            za_swap_label="$(zram_blkid -s LABEL -o value "$za_dev" 2>/dev/null || true)"
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
    # Re-check live identity, active use and mounts before destructive changes.
    zc_link="/dev/disk/by-partuuid/$zram_uuid"
    [ -b "$zc_link" ] || fatal 'Selected PARTUUID block device is missing'
    [ "$(readlink -f "$zc_link")" = "$zram_device" ] ||
        fatal 'Backing device has changed since selection'
    zram_partition_info "$zram_device" ||
        fatal 'Selected backing is not a readable GPT partition'
    [ "$zi_partuuid" = "$zram_uuid" ] ||
        fatal 'Backing PARTUUID changed before conversion'
    parent=$zi_parent
    partn=$zi_partn
    disk=$zi_disk
    [ "$zi_sectors" -ge 2048 ] ||
        fatal 'Selected backing is smaller than the required 1 MiB signature erase'
    # Cloned disks can duplicate a PARTUUID even on ineligible partitions.
    zc_hits=0
    for zc_entry in /sys/class/block/*/partition; do
        [ -r "$zc_entry" ] || continue
        zc_other="/dev/$(basename "$(dirname "$zc_entry")")"
        zram_partition_info "$zc_other" || continue
        if [ "$zi_partuuid" = "$zram_uuid" ]; then
            zc_hits=$((zc_hits + 1))
        fi
    done
    [ "$zc_hits" -eq 1 ] ||
        fatal 'Selected PARTUUID occurs on multiple block partitions; refusing ambiguous backing'
    zram_partition_info "$zram_device" ||
        fatal 'Selected backing vanished during validation'
    case "$zram_kind" in
        swap)
            [ "$zi_type" = "$ZRAM_SWAP_GUID" ] && [ "$zi_signature" = swap ] ||
                fatal 'Backing is no longer a conventional GPT swap partition' ;;
        existing-raw)
            [ "$zi_type" = "$ZRAM_DATA_GUID" ] &&
                [ "$zi_label" = zram-writeback ] &&
                { [ -z "$zi_signature" ] || [ "$zi_signature" = swap ]; } ||
                fatal 'Previously converted backing no longer matches raw GPT identity' ;;
        *) fatal 'Unknown ZRAM backing class' ;;
    esac
    for zc_holder in "/sys/class/block/$(basename "$zram_device")/holders/"*; do
        [ ! -e "$zc_holder" ] || fatal 'Selected ZRAM backing is held by another block device'
    done
    ! zram_is_mounted ||
        fatal 'Selected backing has filesystem mounts; refusing conversion'
}

zram_read_active_swap() {
    # /proc/swaps reports KiB used; preserve byte units for RAM checks/prompts.
    active_used=''
    [ -r /proc/swaps ] || fatal 'Cannot enumerate installer-active swap'
    while read -r zs_path zs_type zs_size zs_used zs_priority; do
        [ "$zs_path" != Filename ] || continue
        [ -n "$zs_path" ] || continue
        if [ "$(readlink -f "$zs_path" 2>/dev/null || true)" = "$zram_device" ]; then
            [ -z "$active_used" ] || fatal 'Duplicate active-swap mapping for the chosen partition'
            case "$zs_used" in ''|*[!0-9]*) fatal 'Invalid used-swap KiB count' ;; esac
            active_used=$((zs_used * 1024))
        fi
    done < /proc/swaps
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
