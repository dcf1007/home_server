#!/usr/bin/env bash
set -Eeuo pipefail

Z=/sys/block/zram0
POLL=1
START=80
TARGET=70
EMERGENCY=95
PSI_MIN=500                  # 5.00% as hundredths of a percent
AGES=(86400 21600 3600 300 60)

state() {
    local kind avg whole fraction
    read -r _ _ used limit _ < "$Z/mm_stat" || return 1
    (( limit > 0 )) || return 1
    read -r kind avg _ < /proc/pressure/memory || return 1
    [[ $kind == some && $avg =~ ^avg10=([0-9]+)\.([0-9]{2})$ ]] || return 1
    whole=${BASH_REMATCH[1]}
    fraction=${BASH_REMATCH[2]}
    psi=$(( 10#$whole * 100 + 10#$fraction ))
    occupancy=$(( used * 100 / limit ))
}

for name in mm_stat idle writeback bd_stat compressed_writeback writeback_limit_enable; do
    [[ -e $Z/$name ]] || { echo "Missing $Z/$name" >&2; exit 1; }
done
read -r value < "$Z/compressed_writeback"
[[ $value == 1 ]] || { echo 'Compressed writeback is not enabled' >&2; exit 1; }
read -r value < "$Z/writeback_limit_enable"
[[ $value == 0 ]] || { echo 'Disable writeback_limit before starting' >&2; exit 1; }

while :; do
    state || { echo 'Cannot read PSI/zram state' >&2; exit 1; }
    if (( occupancy < EMERGENCY && (occupancy < START || psi < PSI_MIN) )); then
        sleep "$POLL"
        continue
    fi

    echo "Writeback triggered: zram=${occupancy}% PSI=${psi}bp"
    read -r _ _ before < "$Z/bd_stat"
    failed=0

    for age in "${AGES[@]}"; do
        state || exit 1
        # Once started, continue only while pressure + insufficient
        # headroom persist, or the emergency threshold is reached.
        if (( occupancy < EMERGENCY && (occupancy < TARGET || psi < PSI_MIN) )); then
            break
        fi
        if ! printf '%s\n' "$age" > "$Z/idle" ||
           ! printf '%s\n' 'type=idle' > "$Z/writeback"; then
            echo "Writeback failed for age=${age}s" >&2
            failed=1
            break
        fi
        echo "Writeback completed: age=${age}s"
    done

    state || exit 1
    if (( failed == 0 && occupancy >= EMERGENCY )); then
        echo 'Emergency writeback: all remaining eligible entries'
        if ! printf '%s\n' all > "$Z/idle" ||
           ! printf '%s\n' 'type=idle' > "$Z/writeback"; then
            echo 'Emergency writeback failed' >&2
            failed=1
        fi
    fi

    read -r _ _ after < "$Z/bd_stat"
    echo "Cycle complete; backing writes delta=$((after - before))"
    if (( failed || after == before )); then
        sleep 30                 # Avoid rapid retries on full/ineffective backing
    else
        sleep "$POLL"
    fi
done
