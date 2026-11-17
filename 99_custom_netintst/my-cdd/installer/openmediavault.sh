#!/bin/sh
# Sourced only when the OMV profile was explicitly selected.
# Match the official OMV 8 installer's scope. Do not change SSH, account
# groups, update schedules, notifications, plugins or other OMV policies.

profile_omv() {
    # The official installer accepts Debian Trixie on amd64/arm64 only.
    capture in-target sh -c '. /etc/os-release; [ "$VERSION_CODENAME" = trixie ]' ||
        fatal 'OMV 8 requires Debian Trixie'
    capture in-target dpkg --print-architecture ||
        fatal 'Cannot verify OMV target architecture'
    case "$(cat "$WORK/output")" in amd64|arm64) : ;;
        *) fatal 'OMV 8 target architecture unsupported' ;;
    esac
    # Like the official installer, reject an installed display manager.
    capture in-target dpkg -l || fatal 'Cannot inspect target packages'
    if awk '$1 == "ii" && $2 ~ /^(gdm3|lightdm|lxdm|sddm|slim|wdm|xdm)$/ { found=1 } END { exit !found }' "$WORK/output"; then
        fatal 'OMV 8 official installer rejects desktop display managers'
    fi

    review_install 'OMV signing and download tools' gnupg wget
    capture in-target wget -q -O /tmp/my-cdd-omv-key https://packages.openmediavault.io/archive.key ||
        fatal 'Official OMV signing key download failed'
    capture in-target gpg --show-keys --with-colons /tmp/my-cdd-omv-key ||
        fatal 'Official OMV signing key is unreadable'
    grep '^fpr:' "$WORK/output" >/dev/null ||
        fatal 'Official OMV signing key has no fingerprint'
    run_target gpg --batch --yes --dearmor -o \
        /usr/share/keyrings/openmediavault-archive-keyring.gpg /tmp/my-cdd-omv-key
    # The installer uses umask 077; APT's _apt user must read this public key.
    run_target chmod 0644 /usr/share/keyrings/openmediavault-archive-keyring.gpg
    rm -f /target/tmp/my-cdd-omv-key

    # Single official signed repository: first entry in OMV 8's
    # manual Debian installation guide. No mirror list or extra suites.
    mkdir -p /target/etc/apt/sources.list.d
    cat > /target/etc/apt/sources.list.d/openmediavault.list <<'EOF'
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.org/public/ synchrony main
EOF
    update_signed_apt
    # Preserve full default-No APT approval, but do not accept upstream's
    # unreviewed --allow-downgrades/--allow-change-held-packages flags.
    simulate_target install --no-install-recommends openmediavault
    review_plan 'Official OpenMediaVault 8 package and dependencies' "$WORK/plan"
    run_target apt-get -y install --no-install-recommends openmediavault
    run_target dpkg --audit
    capture in-target dpkg-query -W '-f=${Version}\n' openmediavault ||
        fatal 'Cannot read installed OMV version'
    grep -Eq '^8\.' "$WORK/output" ||
        fatal 'Installed OMV package is not version 8'

    # OMV's upstream initialization requires a running systemd/D-Bus.
    # Stage it for the first boot; do not execute it in Debian Installer.
    [ -r "$MEDIA/openmediavault-firstboot.sh" ] ||
        fatal 'OMV first-boot script missing from installer media'
    [ -r "$MEDIA/openmediavault-firstboot.service" ] ||
        fatal 'OMV first-boot service missing from installer media'

    mkdir -p /target/usr/local/sbin /target/etc/systemd/system ||
        fatal 'Cannot create OMV first-boot directories'

    cp "$MEDIA/openmediavault-firstboot.sh" \
        /target/usr/local/sbin/my-cdd-omv-firstboot.sh ||
        fatal 'Cannot install OMV first-boot script'
    chmod 0755 /target/usr/local/sbin/my-cdd-omv-firstboot.sh ||
        fatal 'Cannot make OMV first-boot script executable'

    cp "$MEDIA/openmediavault-firstboot.service" \
        /target/etc/systemd/system/my-cdd-omv-firstboot.service ||
        fatal 'Cannot install OMV first-boot service'
    chmod 0644 \
        /target/etc/systemd/system/my-cdd-omv-firstboot.service ||
        fatal 'Cannot set OMV service file permissions'

    # Only enable here: no OMV initialization in the installer chroot.
    # The one-time service deletes its own files after the first attempt;
    # only /var/log/installer/my-cdd-omv-firstboot.log remains.
    run_target systemctl enable my-cdd-omv-firstboot.service

    cat > "$WORK/omv-firstboot-info" <<'EOT'
OpenMediaVault 8 packages were installed successfully.

Final initialization runs automatically on first boot:
  1. omv-confdbadm populate
  2. omv-salt deploy run hosts

Progress, the result and any errors appear on the boot console and
in /var/log/installer/my-cdd-omv-firstboot.log.

After success or failure, the temporary service and script remove
themselves. No automatic retry occurs. The log is retained.
EOT
    show_note 'OpenMediaVault first-boot initialization' \
        "$WORK/omv-firstboot-info" ||
        log 'Could not display OMV first-boot note; installer log remains'

    log 'OMV 8 packages installed; one-time first-boot initialization scheduled'
}
