# 07 — OpenMediaVault 8 on an existing Debian 13 system

**Prerequisites:** minimal **headless Debian 13 Trixie** (no desktop or preinstalled web server), working Internet/DNS, a usable root/admin recovery path and deliberate acceptance that OMV will take over configuration of services it manages. This chapter does **not** install Docker, OMV-Extras, Compose or NAS shares.

## Install using OMV's documented Debian route

OpenMediaVault officially provides a short installation route for **OMV 8 Synchrony** on Debian 13:

~~~sh
sudo apt-get update
sudo apt-get install wget
sudo -i
wget -O - https://get.openmediavault.io | sh -
~~~

**Security note:** this executes vendor-provided remote shell code as root. If you prefer to inspect each operation before running it, download and read the script first, or follow OMV's [manual Debian installation](https://docs.openmediavault.org/en/stable/installation/on_debian.html) with the signed archive repository. Do not substitute unofficial OMV-Extras scripts. Be prepared for network configuration changes; keep console/local access available.

Check the installed package and first-boot health:

~~~sh
dpkg-query -W openmediavault
omv-salt stage run prepare
dpkg --audit
getent ahostsv4 packages.openmediavault.io
~~~

The desired major version is **8**. Access the web UI by the address reported for your host; configure disks, filesystems, shares and users **after** installation, not during the installer phase.

## Preserve SSH administration

OMV may restrict SSH logins to the `_ssh` group and its documented defaults may permit root SSH initially. Confirm your chosen non-root administrative account belongs to the needed groups before disabling root SSH:

~~~sh
id YOUR_ADMIN_ACCOUNT
sudo usermod -aG sudo,_ssh YOUR_ADMIN_ACCOUNT
sudo /usr/sbin/sshd -T | grep -i permitrootlogin
~~~

Replace `YOUR_ADMIN_ACCOUNT` with your actual Debian user. Verify a **second, working SSH session** before disabling root SSH through OMV's SSH settings or a compatible drop-in. Do not accidentally lock out remote maintenance.

## Apply the approved manual-only update policy

The existing installer profile disables OMV 8 unattended upgrades and its APT notification schedule through OMV's configuration database, then deploys only the `apt` and `apticron` Salt states. The same post-install procedure is provided as [disable-automatic-updates.py](disable-automatic-updates.py):

~~~sh
cd /path/to/home_server/07_openmediavault  # use your actual clone path
sudo python3 disable-automatic-updates.py
sudo omv-salt stage run prepare
sudo omv-salt deploy run apt apticron
~~~

Also disable Debian's periodic scheduled APT checks if enabled:

~~~sh
sudo tee /etc/apt/apt.conf.d/99-home-server-manual-updates >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
sudo apt-config dump | grep -E 'APT::Periodic'
~~~

Check that no generated OMV apticron cron jobs remain in `/etc/cron.daily/` or `/etc/cron.weekly/`, and inspect any legacy cron-apt schedule rather than assuming it is absent. This policy **does not prevent manual updates** and does not disable OMV services.

Do not install OMV-Extras, `openmediavault-compose`, or connect Docker to OMV automatically. The independent Docker guide is [08](../08_docker/README.md).

**Important:** OMV network and Salt deployment effects and these exact configuration-database fields still need validation on the selected installed OMV 8 build.

References: [OMV quick install](https://www.openmediavault.org/install) · [OMV on Debian](https://docs.openmediavault.org/en/stable/installation/on_debian.html).
