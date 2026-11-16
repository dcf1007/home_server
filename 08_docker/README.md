# 08 — Install Docker Engine and Compose (optional)

**What this does:** installs Docker Engine, Docker Compose and the supporting packages from Docker's **official Debian repository**.

Docker is independent of OpenMediaVault. This guide does not install OMV-Extras, `openmediavault-compose`, containers or additional server services.

## Step 1 — Check for conflicting software

Before installing, check whether Debian's `docker.io`, `docker-compose`, `podman-docker`, `containerd` or `runc` packages are already installed:

~~~sh
apt list --installed
~~~

Read the installed package list, or look for those names in your terminal's search function. If you find a conflicting package, follow the [official Docker removal guidance](https://docs.docker.com/engine/install/debian/) **after reviewing any existing containers and data**. Do not remove production data blindly.

## Step 2 — Install the tools needed to add Docker's repository

~~~sh
sudo apt update
~~~

~~~sh
sudo apt install ca-certificates curl
~~~

Create a place for the official signing key:

~~~sh
sudo mkdir -p /etc/apt/keyrings
~~~

Download Docker's signing key:

~~~sh
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
~~~

Allow APT to read it:

~~~sh
sudo chmod a+r /etc/apt/keyrings/docker.asc
~~~

## Step 3 — Add Docker's package source

Open a new file:

~~~sh
sudo nano /etc/apt/sources.list.d/docker.sources
~~~

Paste these **file contents**:

~~~text
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: trixie
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
~~~

Save with **Ctrl+O**, Enter, then **Ctrl+X**.

This example is specifically for **Debian 13 amd64**, the system used by this project. If you use another Debian release or architecture, consult Docker's documentation instead of copying these values.

## Step 4 — Refresh and install Docker

~~~sh
sudo apt update
~~~

If APT reports a signing-key or repository error, stop and correct it.

Check that Docker's official packages are available:

~~~sh
apt policy docker-ce
~~~

The package origin should be Docker's repository at `download.docker.com`.

Install the complete official package set:

~~~sh
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
~~~

APT will show the packages and dependencies it intends to install or remove. Read the summary before accepting.

## Step 5 — Confirm Docker works

~~~sh
docker --version
~~~

~~~sh
docker compose version
~~~

Check the service:

~~~sh
sudo systemctl status docker
~~~

And its container runtime:

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
