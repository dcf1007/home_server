#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_tweaks() {
    [ -f /target/etc/default/grub ] || fatal 'GRUB defaults absent'
    # The user approved only removal of quiet and fsck.repair=no; retain
    # all other kernel arguments and normal GRUB behavior.
    sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ {
        s/"quiet([[:space:]]|")/"\1/g
        s/[[:space:]]quiet([[:space:]]|")/ \1/g
        s/="[[:space:]]+/="/
        s/[[:space:]]+"$/"/
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

    # The profile must not force OpenSSH onto a Debian installation where
    # the native tasksel SSH option was intentionally deselected.
    if capture in-target sh -c 'command -v sshd >/dev/null 2>&1'; then
        mkdir -p /target/etc/ssh/sshd_config.d
        printf 'PermitRootLogin no\n' > /target/etc/ssh/sshd_config.d/01-my-cdd-root-login.conf
        verify_target_sshd
    else
        log 'Debian tweaks: OpenSSH not installed; no SSH policy file created'
    fi
    # Do not create a needless periodic-APT override if the policy is already
    # disabled. This guard is also checked after later selected profiles.
    ensure_manual_updates
}

