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

    # OMV 8 source controls scheduled updates through conf.system.apt.updates
    # and the "apt" notification record, deploying apt + apticron (not the
    # obsolete cronapt Salt state). Do not edit OMV-generated cron files.
    # No OMV service is stopped, masked or disabled by this setting.
    capture in-target python3 -c '
import json
import subprocess

def read(model):
    result = subprocess.run(
        ["omv-confdbadm", "read", model],
        check=True, capture_output=True, text=True)
    return json.loads(result.stdout)

def update(model, data):
    subprocess.run(
        ["omv-confdbadm", "update", model, json.dumps(data)],
        check=True, capture_output=True, text=True)

settings = read("conf.system.apt.updates")
if not isinstance(settings, dict) or not isinstance(settings.get("unattendedupgrade"), bool):
    raise RuntimeError("Unexpected OMV 8 APT update settings")
settings["unattendedupgrade"] = False
update("conf.system.apt.updates", settings)

notifications = read("conf.system.notification.notification")
if not isinstance(notifications, list):
    raise RuntimeError("Unexpected OMV 8 notification list")
apt_notifications = [n for n in notifications if isinstance(n, dict) and n.get("id") == "apt"]
if len(apt_notifications) != 1:
    raise RuntimeError("Missing or ambiguous OMV 8 APT notification")
apt_notification = apt_notifications[0]
apt_notification["enable"] = False
update("conf.system.notification.notification", apt_notification)

if read("conf.system.apt.updates").get("unattendedupgrade") is not False:
    raise RuntimeError("OMV unattended updates remain enabled")
remaining = read("conf.system.notification.notification")
if len([n for n in remaining if n.get("id") == "apt" and n.get("enable") is False]) != 1:
    raise RuntimeError("OMV APT update notifications remain enabled")
' || fatal 'Could not disable OMV 8 scheduled updates through its configuration database'
    run_target omv-salt deploy run apt apticron

    # OMV 8 apticron state removes generated daily/weekly notification jobs
    # when the APT notification setting is disabled. Check the effective
    # outcome; never hand-edit Salt-managed cron configuration files.
    for schedule in daily weekly; do
        [ ! -e "/target/etc/cron.$schedule/openmediavault-apticron" ] ||
            fatal "OMV apticron $schedule update notification schedule remains active"
    done

    # Block Debian periodic list refreshes and unattended upgrades for this
    # explicitly selected OMV system; manual apt operations are unaffected.
    mkdir -p /target/etc/apt/apt.conf.d
    printf 'APT::Periodic::Update-Package-Lists "0";\nAPT::Periodic::Unattended-Upgrade "0";\n' > \
        /target/etc/apt/apt.conf.d/99-my-cdd-manual-updates
    capture in-target apt-config dump ||
        fatal 'Cannot validate OMV and Debian scheduled APT update policy'
    grep -Fx 'APT::Periodic::Update-Package-Lists "0";' "$WORK/output" >/dev/null ||
        fatal 'Periodic APT package-list updates were not disabled'
    grep -Fx 'APT::Periodic::Unattended-Upgrade "0";' "$WORK/output" >/dev/null ||
        fatal 'Unattended APT upgrades were not disabled'

    # Legacy cron-apt may exist on upgraded systems; do not mistake it for
    # OMV 8 apticron. Fail closed if an active legacy schedule would remain.
    if [ -f /target/etc/cron.d/cron-apt ]; then
        if grep -Ev '^[[:space:]]*(#|$)' /target/etc/cron.d/cron-apt | grep -q .; then
            fatal 'A legacy cron-apt job remains active; scheduled updates not fully disabled'
        fi
    fi
    capture in-target getent ahostsv4 packages.openmediavault.io ||
        fatal 'OMV installation disrupted target DNS; manual repair required'
    ensure_manual_updates
    run_target dpkg --audit
    log 'OMV 8 installed with unattended upgrades and scheduled APT notifications off; no NAS shares or plugins configured'
}

