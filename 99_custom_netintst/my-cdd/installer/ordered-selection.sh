#!/bin/sh
# Pure selection validation. Does NOT enable, disable or execute profiles.
# Usage: sh ordered-selection.sh 'docker, backports, ensure-7x-kernel'
set -eu
[ "$#" -eq 1 ] || { printf >&2 'Expected one comma-separated selection string\n'; exit 2; }
selected="$(printf %s "$1" | tr ',' ' ')"
order='backports ensure-7x-kernel extended-device-support zram-writeback debian-tweaks openmediavault docker'
for token in $selected; do
  case " $order " in *" $token "*) ;; *)
    printf >&2 'Unknown/unapproved profile: %s\n' "$token"; exit 1;;
  esac
done
out=''
for token in $order; do
  case " $selected " in
    *" $token "*)
      if [ -n "$out" ]; then out="$out $token"; else out="$token"; fi ;;
  esac
done
case " $out " in *' zram-writeback '*)
  case " $out " in *' ensure-7x-kernel '*) ;; *)
    printf >&2 'ZRAM requires explicitly selected Ensure 7.x\n'; exit 1;;
  esac ;;
esac
printf '%s\n' "$out"
