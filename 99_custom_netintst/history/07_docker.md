# 07 — Optional Docker Engine profile (independent of OpenMediaVault)

**Current policy (2026-11-15):** Docker is a separately selectable, initially unchecked profile. Do not mask, stop, disable, or otherwise override Docker or containerd startup during installation or at first boot. Their service behavior follows the official Debian packages. The earlier manual-start restriction is superseded. **Source changes are not yet installer-tested.**

## Installation scope

When selected, install from Docker's official signed repository for Debian 13 (Trixie), with key scoped by `Signed-By` and reviewed APT candidates, dependencies, origins, removals and transaction approval:

```text
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

Docker is **not** installed if the Docker profile is unchecked. Do not create containers, Compose projects, storage layouts, privileged docker-group memberships, or a custom Docker daemon configuration. Do not impose firewall settings or modify other services.

## OpenMediaVault independence

Docker and OpenMediaVault are separate installer choices. Selecting one does not automatically select or install the other. **Never install OMV-Extras, `openmediavault-compose`, or configure the OMV Docker/Compose integration during Debian Installer.** If the user installs an integration through OMV's web interface later, its repository and service management is the user's separate post-installation decision. The installer must not preemptively create OMV-Extras repository sources or attempt to manage its future configuration.

## Acceptance and validation

Verify the official Docker package origin, signed APT repository, installed packages and `dpkg --audit`. After first boot, verify `docker.service`, `docker.socket` and `containerd.service` reflect normal vendor package defaults rather than custom masks/disables. These checks do **not** authorize starting or stopping the services as a test, launching containers, or making persistent service changes.

The Docker profile, OMV-only profile and simultaneous selection have not been tested in a live Debian 13 installer; testing is a release gate.

**References:** [Docker Engine on Debian](https://docs.docker.com/engine/install/debian/) · [Docker Linux post-installation](https://docs.docker.com/engine/install/linux-postinstall/) · [OMV 8 installation](https://docs.openmediavault.org/en/stable/installation/on_debian.html)
