# 08 — Official Docker Engine and Compose plugin (optional)

Applies independently to Debian 13. **Docker is not an OpenMediaVault component here.** Installing OMV does not require Docker and vice versa. Do not install OMV-Extras or the `openmediavault-compose` plugin as part of this chapter.

## Use Docker's official Debian repository

~~~sh
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
~~~

For this guide, verify that the generated suite is **trixie**. If `docker.io`, `podman-docker`, `docker-compose`, system `containerd` or other conflicting packages are already installed, **review Docker's official conflict-removal instructions first**. Do not remove working containers or data blindly.

~~~sh
apt-cache policy docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt-get -s install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
~~~

After checking that the proposed dependencies, replacements and removals are acceptable:

~~~sh
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo dpkg --audit
docker --version
docker compose version
sudo systemctl status docker containerd
~~~

Preserve the official packages' **normal startup behavior**. Do not mask/disable Docker or containerd, create containers, configure storage/Compose stacks, or grant a user the root-equivalent `docker` group automatically.

**Note:** Docker can change firewall behavior and exposed container ports may bypass some host firewall configurations. Check your network exposure before publishing services.

References: [Official Docker Engine on Debian](https://docs.docker.com/engine/install/debian/) · [Docker post-installation](https://docs.docker.com/engine/install/linux-postinstall/).
