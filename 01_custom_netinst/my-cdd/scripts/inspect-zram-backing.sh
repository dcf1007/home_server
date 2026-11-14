#!/bin/sh
# READ-ONLY preflight. Never picks a device or changes any partition.
# Usage: sh scripts/inspect-zram-backing.sh /dev/disk/by-partuuid/CONFIRMED_UUID
set -eu
[ "$#" -eq 1 ] || { echo 'Expected one explicit PARTUUID device path' >&2; exit 2; }
case "$1" in
  /dev/disk/by-partuuid/*) ;;
  *) echo 'Refusing arbitrary device path: use the confirmed PARTUUID symlink' >&2; exit 2 ;;
esac
[ -b "$1" ] || { echo 'Specified PARTUUID target is not a block device' >&2; exit 1; }
command -v readlink >/dev/null 2>&1 || exit 1
device="$(readlink -f -- "$1")"
[ -b "$device" ] || exit 1
[ "$(lsblk -dnro TYPE -- "$device")" = part ] || {
  echo 'Refusing non-partition block device' >&2; exit 1;
}
printf 'Confirmed inspect-only partition path: %s\n' "$device"
lsblk -no NAME,PATH,TYPE,SIZE,FSTYPE,PARTTYPE,PARTLABEL,PARTUUID,MOUNTPOINTS -- "$device"
printf '\nActive swap table (for separate user review):\n'
swapon --show --output NAME,TYPE,SIZE,USED,PRIO || true
printf '\nSignatures (read only):\n'
wipefs -n -- "$device" || true
printf '\nThis preflight NEVER runs swapoff, sgdisk, wipefs -a, mkfs or mkswap.\n'
