#!/bin/sh
# Source code for an EARLY installer-stage gate. NOT yet wired into d-i.
# Invoke AFTER db_get simple-cdd/profiles but BEFORE .preseed/.udebs/.packages.
set -eu
. /usr/share/debconf/confmodule

# This deliberately refuses to auto-select dependent profiles.
db_get simple-cdd/profiles
selected="$(printf '%s' "$RET" | tr ',' ' ')"
choices='backports ensure-7x-kernel extended-device-support zram-writeback debian-tweaks openmediavault docker'
summary=""
selected_kernel=false
selected_zram=false
for p in $choices; do
  case " $selected " in *" $p "*) status=Selected ;; *) status='Not selected' ;; esac
  [ "$p" != ensure-7x-kernel ] || [ "$status" != Selected ] || selected_kernel=true
  [ "$p" != zram-writeback ] || [ "$status" != Selected ] || selected_zram=true
  summary="$summary\n$p: $status"
done
if [ "$selected_zram" = true ] && [ "$selected_kernel" != true ]; then
  printf >&2 'ZRAM requires an explicitly selected Ensure 7.x profile.\n'
  exit 1
fi
# Debconf substitution is intentionally reviewed/validated as a future udeb step.
db_subst my-cdd/profile-summary MYCDD_SUMMARY "$summary"
db_fset my-cdd/profile-summary seen false
db_input critical my-cdd/profile-summary || true
db_go
db_set my-cdd/profile-confirm false
db_fset my-cdd/profile-confirm seen false
db_input critical my-cdd/profile-confirm || true
db_go
db_get my-cdd/profile-confirm
[ "$RET" = true ] || { printf >&2 'Selected profiles NOT approved.\n'; exit 1; }
