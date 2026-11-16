#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

suite_version() {
    capture in-target apt-cache madison "$1" ||
        fatal "Unable to inspect APT candidates for $1"
    awk -F '|' -v s="$2" 'index($3,s"/") {
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit
    }' "$WORK/output"
}

normal_suite() {
    best_suite=''
    best_version=''
    for suite in trixie-security trixie-updates trixie; do
        v="$(suite_version "$1" "$suite")"
        [ -n "$v" ] || continue
        if [ -z "$best_version" ] ||
            in-target dpkg --compare-versions "$v" gt "$best_version"; then
            best_suite=$suite
            best_version=$v
        fi
    done
    [ -n "$best_suite" ] || return 1
    printf '%s\n' "$best_suite"
}

backports_is_selected() {
    case " $ordered " in *' backports '*) return 0;; *) return 1;; esac
}

update_signed_apt() {
    run_target apt-get update
    capture in-target apt-cache policy || fatal 'Cannot inspect APT priorities'
}

# Automatic installs require both the unattended-upgrades package and an
# enabled APT::Periodic::Unattended-Upgrade setting. Do not create an override
# on a freshly installed system where no automatic installer is active.
ensure_manual_updates() {
    if ! capture in-target dpkg-query -W '-f=${Status}\n' unattended-upgrades; then
        log 'unattended-upgrades is absent; no automatic-install override needed'
        return 0
    fi
    if ! grep -Fx 'install ok installed' "$WORK/output" >/dev/null; then
        log 'unattended-upgrades is not fully installed; no override needed'
        return 0
    fi
    capture in-target apt-config dump || fatal 'Cannot inspect automatic APT settings'
    if grep -Ei 'APT::Periodic::Unattended-Upgrade[[:space:]]+"?([1-9]|yes|true)' "$WORK/output" >/dev/null; then
        mkdir -p /target/etc/apt/apt.conf.d
        printf 'APT::Periodic::Unattended-Upgrade "0";\n' > \
            /target/etc/apt/apt.conf.d/99-my-cdd-manual-updates
        capture in-target apt-config dump ||
            fatal 'Cannot verify manual-update APT override'
        if grep -Ei 'APT::Periodic::Unattended-Upgrade[[:space:]]+"?([1-9]|yes|true)' "$WORK/output" >/dev/null; then
            fatal 'Unattended upgrades still enabled after writing override'
        fi
        log 'Installed unattended-upgrades was enabled; automatic installations disabled'
    else
        log 'unattended-upgrades is installed but automatic installation already disabled'
    fi
}

# ssh.service normally creates /run/sshd via RuntimeDirectory=sshd.
# During Debian Installer late_command the target has not booted and
# that transient directory may not exist. Do not mistake that condition
# for an invalid sshd_config. Capture real diagnostics if checks still fail.
verify_target_sshd() {
    [ -x /target/usr/sbin/sshd ] || fatal 'Installed OpenSSH daemon is missing'
    mkdir -p /target/run/sshd ||
        fatal 'Cannot create transient target /run/sshd for validation'
    chmod 755 /target/run/sshd ||
        fatal 'Cannot set transient target /run/sshd directory mode'
    capture in-target /usr/sbin/sshd -t ||
        fatal 'OpenSSH syntax/prerequisite check failed; read sshd stderr in my-cdd.log'
    capture in-target /usr/sbin/sshd -T ||
        fatal 'OpenSSH effective configuration check failed; read sshd stderr in my-cdd.log'
    grep -Fx 'permitrootlogin no' "$WORK/output" >/dev/null ||
        fatal 'OpenSSH effective PermitRootLogin policy is not no'
}
