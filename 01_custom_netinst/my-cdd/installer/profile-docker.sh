#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_docker() {
    review_install 'Docker signing prerequisites' ca-certificates curl
    mkdir -p /target/etc/apt/keyrings
    capture in-target curl -fsSL --proto '=https' \
        -o /etc/apt/keyrings/docker.asc https://download.docker.com/linux/debian/gpg ||
        fatal 'Official Docker signing key download failed'
    chmod 644 /target/etc/apt/keyrings/docker.asc
    grep -Fx 'VERSION_CODENAME=trixie' /target/etc/os-release >/dev/null ||
        fatal 'Docker requires installed Debian 13 trixie'
    cat > /target/etc/apt/sources.list.d/docker.sources <<'EOT'
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOT
    update_signed_apt
    for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
        capture in-target apt-cache policy "$pkg" || fatal "Cannot inspect $pkg"
        grep -F 'download.docker.com/linux/debian' "$WORK/output" >/dev/null ||
            fatal "$pkg lacks the official signed Docker repository"
    done
    # Installer-only startup prevention targeting ONLY Docker service/socket.
    # Unlike disabling units after the transaction, these masks are applied
    # before any maintainer scripts can request startup.
    capture in-target systemctl --root=/ mask docker.service docker.socket ||
        fatal 'Could not prevent Docker startup before package installation'
    simulate_target install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    check_critical_removals
    review_plan 'Docker: complete official package transaction, daemon/socket suppressed' "$WORK/plan"
    run_target apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    capture in-target systemctl --root=/ unmask docker.service docker.socket ||
        fatal 'Could not remove temporary Docker startup suppression'
    capture in-target systemctl --root=/ disable docker.service docker.socket ||
        fatal 'Could not disable Docker daemon and socket for first boot'
    for unit in docker.service docker.socket; do
        # systemctl is-enabled exits nonzero for the desired "disabled"
        # state; inspect its output rather than treating status 1 as failure.
        capture in-target systemctl --root=/ is-enabled "$unit" || :
        grep -Fx disabled "$WORK/output" >/dev/null ||
            fatal "$unit is not disabled for first boot"
    done
    run_target dpkg --audit
    log 'Docker packages installed; Docker daemon and socket disabled; no containers started'
}

