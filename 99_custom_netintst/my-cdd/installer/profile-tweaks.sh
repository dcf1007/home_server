#!/bin/sh
# Sourced only when the Debian tweaks profile is explicitly selected.

profile_tweaks() {
    [ -f /target/etc/default/grub ] || fatal 'GRUB defaults absent'
    # Keep unrelated kernel arguments; remove quiet and request no automatic fsck repair.
    sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ {
        s/"quiet([[:space:]]|")/"\1/g
        s/[[:space:]]quiet([[:space:]]|")/ \1/g
        s/="[[:space:]]+/="/
        s/[[:space:]]+"$/"/
        /fsck\.repair=no/! s/"$/ fsck.repair=no"/
    }' /target/etc/default/grub
    run_target update-grub

    # Edit only the root mount entry. noatime is generic; the panic option
    # depends on the actual root filesystem.
    [ -f /target/etc/fstab ] || fatal 'Target fstab absent'
    awk '
      /^[[:space:]]*#/ {print; next}
      $2=="/" {
        fs=$3; n=split($4, opts, ","); out=""
        for (i=1;i<=n;i++) {
          if (opts[i]=="atime" || opts[i]=="relatime" ||
              opts[i]=="strictatime" || opts[i]=="noatime") continue
          if (fs ~ /^ext[234]$/ && opts[i] ~ /^errors=/) continue
          if (fs=="btrfs" && opts[i] ~ /^fatal_errors=/) continue
          out=out (out ? "," : "") opts[i]
        }
        $4=out (out ? "," : "") "noatime"
        if (fs ~ /^ext[234]$/) $4=$4 ",errors=panic"
        else if (fs=="btrfs") $4=$4 ",fatal_errors=panic"
        changed++
      }
      {print}
      END {if (changed!=1) exit 2}
    ' /target/etc/fstab > "$WORK/tweaks-fstab" ||
        fatal 'Cannot identify exactly one root filesystem in fstab'
    cp -p /target/etc/fstab /target/etc/fstab.before-tweaks ||
        fatal 'Cannot preserve the original root mount configuration'
    cp "$WORK/tweaks-fstab" /target/etc/fstab ||
        fatal 'Cannot install root mount options'

    # Fresh Debian installation: place the global setting before Include
    # and Match, without adding a project-owned sshd_config.d file.
    if [ -f /target/etc/ssh/sshd_config ]; then
        if [ "$(head -n 1 /target/etc/ssh/sshd_config)" != 'PermitRootLogin no' ]; then
            sed -i '1iPermitRootLogin no' /target/etc/ssh/sshd_config ||
                fatal 'Cannot disable root login in the existing SSH configuration'
        fi
    else
        log 'Debian tweaks: OpenSSH not installed; no SSH configuration changed'
    fi

    # This is a one-time, selected-profile policy; later profiles do not
    # reconfigure APT automatic updates.
    if capture in-target dpkg-query -W '-f=${Status}\n' unattended-upgrades &&
        grep -Fx 'install ok installed' "$WORK/output" >/dev/null; then
        capture in-target apt-config dump ||
            fatal 'Cannot inspect Debian automatic-update settings'
        if grep -Eiq '^APT::Periodic::Unattended-Upgrade[[:space:]]+"?([1-9][0-9]*|yes|true)' "$WORK/output"; then
            native_apt=/target/etc/apt/apt.conf.d/20auto-upgrades
            if [ -f "$native_apt" ] &&
                grep -Eq '^[[:space:]]*APT::Periodic::Unattended-Upgrade[[:space:]]+' "$native_apt"; then
                sed -i -E 's@^[[:space:]]*APT::Periodic::Unattended-Upgrade[[:space:]]+[^;]*;@APT::Periodic::Unattended-Upgrade "0";@' "$native_apt" ||
                    fatal 'Cannot disable periodic upgrades in Debian APT configuration'
                log 'Disabled automatic upgrades in Debian native 20auto-upgrades'
            else
                mkdir -p /target/etc/apt/apt.conf.d
                printf 'APT::Periodic::Unattended-Upgrade "0";\n' > \
                    /target/etc/apt/apt.conf.d/99-my-cdd-manual-updates
                log 'Disabled automatic upgrades with one APT override'
            fi
        fi
    fi
}
