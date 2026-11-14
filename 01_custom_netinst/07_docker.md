# 07 — Selectable **Docker Engine** profile

**Status:** design only; no installed or tested Docker stack claimed. **Recorded:** 2026-11-14. **Provenance:** user approval of Docker as independent installer option, with service/socket kept inactive through first boot.

## Purpose

If selected, install the official Docker packages on Debian 13 during customized installation:

```text
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

Use the official Docker Debian 13 repository with its signing key scoped via `Signed-By`. Validate the origin, suite, package candidate versions and dependencies. The official Docker repository was already requested, but packages are installed **only when the Docker profile is selected**.

## Do not activate Docker

Docker may start during package configuration or through socket activation unless explicitly prevented. Required behavior:

- During installation: **do not start Docker daemon or Docker socket**.
- On first normal boot: **keep `docker.service` and `docker.socket` disabled/inactive** until the user explicitly approves activation.
- Review related containerd service behavior; do not mistake Docker daemon suppression for a promise that every installed container-runtime process is absent.
- Do not automatically enable any Docker listener, deploy containers, create Compose projects or add the installer-confirmed administrator account to the privileged `docker` group.
- Do not install/configure `openmediavault-compose` or OMV-Extras as an implicit Docker dependency; those are separately undecided.
- Do not add firewall filtering during installation; Docker startup can modify NAT/forwarding rules, which is one reason activation is deferred.

**Implementation caution:** Merely disabling a unit after the package installation is insufficient if maintainer scripts started it earlier. The installer needs a validated, temporary package-service startup suppression mechanism, followed by explicit unit disablement and removal of temporary suppression. Do not globally mask unrelated services without approval.

## Compatibility gate

Simulate Docker install alongside any selected OMV, Backports and Ensure 7.x kernel profiles. If Backports was selected, verify its **default priority 100** and selectively installed kernel dependencies; do not globally prefer Backports packages before making changes. Preserve OMV, networking and SSH settings; do not override pinned package selections without consultation. Verify repository signature and dependency graph.

## Acceptance after first boot

```sh
dpkg-query -W docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl is-enabled docker.service docker.socket
systemctl is-active docker.service docker.socket
docker --version
docker compose version
```

Desired: packages installed, command-line tools available, **Docker daemon and socket inactive/disabled**. Do **not** execute `docker run` as a test without separately authorizing daemon activation.

References: [Docker Engine on Debian](https://docs.docker.com/engine/install/debian/) · [Docker post-install](https://docs.docker.com/engine/install/linux-postinstall/)
