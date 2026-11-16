# Netinst — Install official Docker during Debian installation

**Purpose:** offer Docker Engine and the Compose plugin as **one independent optional profile**. It does not install OMV, OMV-Extras, the OMV Compose plugin, containers or user-group permissions.

For a normal, running Debian system, follow [08 — Docker](../08_docker/README.md). The following steps are executed by the selected installer profile **inside the newly installed target**.

## Step 1 — Select Docker explicitly

Tick **Docker** in the early seven-profile Simple-CDD screen and confirm the exact selection. This does not select OpenMediaVault. An unselected Docker profile should perform **no Docker package or repository operations**.

## Step 2 — Install the signing prerequisites

The installer first simulates installation of `ca-certificates` and `curl` and shows a reviewed APT transaction. These tools are needed to retrieve the signing key securely using HTTPS.

After approval, the prerequisites are installed under `/target` using Debian Installer's native package progress interface.

## Step 3 — Install Docker's public signing key

The installer downloads Docker's official Debian public key:

`https://download.docker.com/linux/debian/gpg`

It stores the key in the target under `/etc/apt/keyrings/docker.asc`, with permissions allowing APT to read it. The key belongs only to Docker's repository; the installer does **not** disable APT signing verification.

The target must identify as **Debian 13 Trixie**. If not, the profile stops rather than choosing another Docker repository automatically.

## Step 4 — Add the exact Debian source

The profile writes an installed-target Deb822 source with:

~~~text
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
~~~

This source is for **amd64 Trixie** only. It is separate from OMV or Debian Backports sources.

The installer updates target package indexes and verifies that **each** requested Docker package can be resolved through the official `download.docker.com` repository.

## Step 5 — Review the whole Docker installation

The selected package set is:

- `docker-ce` — Engine daemon;
- `docker-ce-cli` — client commands;
- `containerd.io` — container runtime;
- `docker-buildx-plugin` — Buildx;
- `docker-compose-plugin` — the `docker compose` subcommand.

APT simulates installing **all five together**. The profile rejects planned removals of essential kernel, boot, SSH, sudo, systemd, APT or dpkg components.

The Debconf interface displays the complete package transaction and asks for a **default-No** approval. Read the package changes before approving. A refused or failed transaction must not mark Docker complete.

## Step 6 — Install and leave normal service defaults alone

With approval, the installer runs target `apt-get` and then `dpkg --audit`. It does **not** manually start, mask, disable or otherwise override Docker or containerd services: vendor package behavior controls startup and first boot.

It does not add the Debian administrator to Docker's **root-equivalent** `docker` group or create containers.

## Step 7 — Check Docker after reboot

On the installed Debian server, verify:

1. `docker --version` reports the installed CLI.
2. `docker compose version` reports the Compose plugin.
3. `sudo systemctl status docker` and `sudo systemctl status containerd` show expected service states.
4. No OMV Docker integration, Compose stack, container or unintended firewall exposure was created.

**Remaining validation:** package origins, first-boot service activation and interaction with an independently selected OMV profile must be tested in a VM.

Implementation: [profile-docker.sh](my-cdd/installer/profile-docker.sh).
