# 08 — Install Docker Engine and Compose (optional)

**What this does:** installs Docker Engine, Docker Compose and the supporting packages from Docker's **official Debian repository**.

Docker is independent of OpenMediaVault. This guide does not install OMV-Extras, `openmediavault-compose`, containers or additional server services.

## Step 1 — Check for conflicting software

Before installing, check whether Debian's `docker.io`, `docker-compose`, `podman-docker`, `containerd` or `runc` packages are already installed:

This asks APT which of Docker’s **potentially conflicting packages** are already installed. Check any listed installed version before proceeding; the command is read-only and does not remove software. If the output is empty, these named conflicts were not found.

~~~sh
apt list --installed docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc
~~~

This checks just the potentially conflicting packages, rather than listing every installed package. If you find a conflicting package, follow the [official Docker removal guidance](https://docs.docker.com/engine/install/debian/) **after reviewing any existing containers and data**. Do not remove production data blindly.

## Step 2 — Install the tools needed to add Docker's repository

This refreshes Debian’s package information before adding Docker. It **does not install** Docker; resolve existing APT errors first.

~~~sh
sudo apt update
~~~

This installs `ca-certificates` for HTTPS trust verification and `curl` for downloading Docker’s signing key. Review APT’s proposed packages before accepting.

~~~sh
sudo apt install ca-certificates curl
~~~

Create a place for the official signing key:

This creates a directory for APT signing keys, if it does not exist. The directory itself does not trust Docker; the key and repository file are added separately.

~~~sh
sudo mkdir -p /etc/apt/keyrings
~~~

Download Docker's signing key:

This downloads Docker’s **official repository signing key** into the keyring directory over HTTPS. If the download fails or reports a certificate error, do not continue to the repository configuration.

~~~sh
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
~~~

Allow APT to read it:

This makes the downloaded public key readable by APT. It does not give Docker permission to execute arbitrary commands or affect packages until you add and use the Docker repository.

~~~sh
sudo chmod a+r /etc/apt/keyrings/docker.asc
~~~

## Step 3 — Add Docker's package source

Open a new file:

This opens the Docker APT source file in an editor. Paste the shown `trixie`/`amd64` repository information **inside the file**, then save it; you are choosing the Docker package source and scoping its signing key.

Open `/etc/apt/sources.list.d/docker.sources` in a text editor with administrator privileges; review the existing content, make the described change and save the file.

Paste these **file contents**:

~~~text
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
~~~

Save the file after reviewing the content.

This example is specifically for **Debian 13 amd64**, the system used by this project. If you use another Debian release or architecture, consult Docker's documentation instead of copying these values.

## Step 4 — Refresh and install Docker

This refreshes package indexes again, **now including the Docker repository**. Stop if Docker’s repository is unreachable or its signature cannot be verified.

~~~sh
sudo apt update
~~~

If APT reports a signing-key or repository error, stop and correct it.

Check that Docker's official packages are available:

This displays the available Docker Engine versions and their package origins. Verify the candidate comes from **`download.docker.com`**, not from a different repository.

~~~sh
apt policy docker-ce
~~~

The package origin should be Docker's repository at `download.docker.com`.

Install the complete official package set:

This installs official Docker Engine, CLI, containerd runtime, Buildx and Compose plugin. APT will display dependencies and possible replacements/removals; review the transaction carefully before approving.

~~~sh
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
~~~

APT will show the packages and dependencies it intends to install or remove. Read the summary before accepting.

## Step 5 — Confirm Docker works

This displays the installed Docker **client** version. It confirms the CLI is present but by itself **does not prove the Docker daemon is running**.

~~~sh
docker --version
~~~

This displays the installed Docker Compose plugin version. Look for a version rather than an error indicating the `compose` subcommand is missing.

~~~sh
docker compose version
~~~

Check the service:

This checks Docker daemon’s service state. Look for **`active (running)`**, and use its error messages if inactive; the command does not start or restart Docker.

~~~sh
sudo systemctl status docker
~~~

And its container runtime:

This checks the underlying `containerd` runtime service. It should also report an active service; if not, investigate that service before relying on Docker.

~~~sh
sudo systemctl status containerd
~~~

The official packages normally manage their own startup. **Do not mask or disable these services** for this project.

You can also run `sudo docker version` to inspect both client and server versions, without creating a container.

## Step 6 — Leave optional Docker configuration for later

This guide deliberately does **not**:

- Add users to the root-equivalent `docker` group.
- Create containers or Compose projects.
- Change Docker's daemon, storage or network settings.
- Install any OMV Docker or Compose integration.

If you later publish container ports, review Docker's [firewall considerations](https://docs.docker.com/engine/install/debian/). Published ports may behave differently from the host firewall rules you expect.

**Done when:** the official Docker packages are installed, the service is running and `docker compose version` works.

**Reference:** [Docker's Debian installation instructions](https://docs.docker.com/engine/install/debian/).
