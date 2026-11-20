#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_docker() {
    review_install 'Docker signing prerequisites' ca-certificates curl
    mkdir -p /target/etc/apt/keyrings
    progress_status 'Downloading Docker repository signing key'
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
    # Install through Docker's official signed Debian repository.
    # No custom masking, disabling or starting of Docker/containerd units:
    # preserve the packages' own install-time and first-boot defaults.
    # OMV remains independent; OMV-Extras/Compose is never installed here.
    simulate_target install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    review_plan 'Docker: official packages and normal service defaults' "$WORK/plan"
    run_target apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    run_target dpkg --audit
    log 'Docker packages installed; service activation is governed by native package defaults'
}

