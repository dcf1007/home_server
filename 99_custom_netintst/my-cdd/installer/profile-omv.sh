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
    capture in-target apt-cache policy openmediavault ||
        fatal 'Cannot inspect official OMV package origin'
    grep -F 'packages.openmediavault.org/public' "$WORK/output" >/dev/null ||
        fatal 'Official signed OMV repository is unavailable'

    # Preserve full default-No APT approval, but do not accept upstream's
    # unreviewed --allow-downgrades/--allow-change-held-packages flags.
    simulate_target install --no-install-recommends openmediavault
    check_critical_removals
    review_plan 'Official OpenMediaVault 8 package and dependencies' "$WORK/plan"
    run_target apt-get -y install --no-install-recommends openmediavault
    run_target dpkg --audit
    capture in-target dpkg-query -W '-f=${Version}\n' openmediavault ||
        fatal 'Cannot read installed OMV version'
    grep -Eq '^8\.' "$WORK/output" ||
        fatal 'Installed OMV package is not version 8'

    # Exactly the two post-install initialization operations in upstream.
    run_target omv-confdbadm populate
    run_target omv-salt deploy run hosts
    log 'OMV 8 installed and initialized; no custom SSH, update, notification or plugin changes'
}
