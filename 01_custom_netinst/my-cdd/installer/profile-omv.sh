#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.
# OMV is independent of Docker. Do not install OMV-Extras/Compose or suppress
# OMV service startup; the user can add optional plugins through the OMV GUI.

profile_omv() {
    # OMV warns that the resolver must work BEFORE package installation.
    review_install 'OMV prerequisites: resolver, SSH/sudo access and signing tools' systemd-resolved psmisc gnupg ca-certificates curl openssh-server sudo
    capture in-target getent ahostsv4 packages.openmediavault.io ||
        fatal 'Target DNS unavailable; stop rather than invent network configuration'
    capture in-target curl -fsSL --proto '=https' \
        -o /tmp/my-cdd-omv-key https://packages.openmediavault.io/archive.key ||
        fatal 'Official OMV signing key download failed'
    capture in-target gpg --show-keys --with-colons /tmp/my-cdd-omv-key ||
        fatal 'Vendor OMV signing key malformed'
    grep '^fpr:' "$WORK/output" >/dev/null ||
        fatal 'Vendor OMV key contained no fingerprint'
    run_target gpg --batch --yes --dearmor -o \
        /usr/share/keyrings/openmediavault-archive-keyring.gpg /tmp/my-cdd-omv-key
    rm -f /target/tmp/my-cdd-omv-key
    mkdir -p /target/etc/apt/sources.list.d
    cat > /target/etc/apt/sources.list.d/openmediavault.list <<'EOT'
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.org/public/ synchrony main
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.io/ synchrony main
EOT
    update_signed_apt
    capture in-target apt-cache policy openmediavault ||
        fatal 'Cannot inspect official OMV package origin'
    grep -F 'synchrony/main' "$WORK/output" >/dev/null ||
        fatal 'Signed official OMV 8 package repository unavailable'
    review_install 'OMV 8 package and dependencies' openmediavault
    capture in-target dpkg-query -W -f='${Version}\n' openmediavault ||
        fatal 'Cannot check installed OMV version'
    grep -E '^8\.' "$WORK/output" >/dev/null ||
        fatal 'Installed OMV is not version 8'

    # Native Debian Installer account: never hardcode a username.
    db_get passwd/username || fatal 'Missing Debian Installer username'
    admin=$RET
    case "$admin" in ''|*[!a-zA-Z0-9_.-]*) fatal 'Unexpected admin account name';; esac
    capture in-target id "$admin" || fatal 'Admin account unavailable'
    capture in-target getent group _ssh || fatal 'OMV _ssh access group unavailable'
    run_target usermod -aG sudo,_ssh "$admin"
    mkdir -p /target/etc/ssh/sshd_config.d
    printf 'PermitRootLogin no\n' > /target/etc/ssh/sshd_config.d/01-my-cdd-root-login.conf
    capture in-target sshd -T || fatal 'OMV SSH config invalid'
    grep -Fx 'permitrootlogin no' "$WORK/output" >/dev/null ||
        fatal 'OMV root SSH still enabled'

    # Only approved OMV customization: disable the entire cron-apt schedule.
    run_target omv-confdbadm populate
    run_target omv-env set -- OMV_CRON_APT_ENABLED false
    run_target omv-salt deploy run cronapt
    if [ -f /target/etc/cron.d/cron-apt ]; then
        if grep -Ev '^[[:space:]]*(#|$)' /target/etc/cron.d/cron-apt | grep -q .; then
            fatal 'OMV cron-apt still schedules automatic update checks'
        fi
    fi
    capture in-target omv-env get OMV_CRON_APT_ENABLED ||
        fatal 'Cannot confirm OMV cron-apt environment setting'
    grep -Ei '^(false|no|0)[[:space:]]*$' "$WORK/output" >/dev/null ||
        fatal 'OMV cron-apt was not disabled'
    capture in-target getent ahostsv4 packages.openmediavault.io ||
        fatal 'OMV installation disrupted target DNS; manual repair required'
    ensure_manual_updates
    run_target dpkg --audit
    log 'OMV 8 installed with cron-apt off; no NAS shares or plugins configured'
}

