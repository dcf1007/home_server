# Netinst — Docker adaptation

**Normal post-install route:** [08 — Docker](../08_docker/README.md).

The selected-only [profile-docker.sh](my-cdd/installer/profile-docker.sh) stages Docker's official signed key and APT `.sources` configuration under `/target`, checks package origins, simulates and requests approval, then installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` and `docker-compose-plugin`.

Only the installer needs `in-target`, `/target` paths, target-APT simulation and native Debconf confirmation. Docker and containerd retain vendor package service startup defaults; there are **no** custom masks, disables, containers, Docker-group memberships or OMV integration.

History: [07 Docker planning](history/07_docker.md).
