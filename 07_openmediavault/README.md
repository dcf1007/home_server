# 07 — Install OpenMediaVault 8 on Debian 13

**What this does:** adds the OpenMediaVault 8 (Synchrony) NAS web interface to a minimal Debian 13 server.

**Before starting:** Debian is already installed **without a desktop environment or web server**. You have working network/DNS and a local console or recovery login. OMV takes control of configuration for services it manages, so it may change network and SSH settings. This guide does not install Docker, OMV-Extras, Compose or any NAS shares.

## Step 1 — Prepare Debian

~~~sh
sudo apt update
~~~

~~~sh
sudo apt install wget
~~~

Keep local access available during installation in case the network configuration changes.

## Step 2 — Download the official OMV installer

OMV publishes a [quick installation method for Debian 13](https://www.openmediavault.org/install). To avoid piping a remote script directly into a shell, **download it as a file first**:

~~~sh
wget https://get.openmediavault.io -O openmediavault-install.sh
~~~

Open the downloaded script and review it:

~~~sh
nano openmediavault-install.sh
~~~

This is vendor-supplied code that will run as root. **If you do not trust or approve its contents, do not run it.** Alternatively follow OMV's [manual Debian installation guide](https://docs.openmediavault.org/en/stable/installation/on_debian.html).

When satisfied, run the saved script:

~~~sh
sudo sh openmediavault-install.sh
~~~

Follow any prompts and let the installer finish. If it fails, resolve the reported error rather than running unrelated installation scripts.

## Step 3 — Check that OMV installed correctly

~~~sh
apt policy openmediavault
~~~

Check the installed version. It should be **8.x**.

~~~sh
sudo dpkg --audit
~~~

If nothing is reported, Debian has no unfinished package configurations.

~~~sh
ip -brief address
~~~

Use your server's address in a browser to open the OMV web interface. OMV's initial web login is documented in its [installation guide](https://docs.openmediavault.org/en/stable/installation/); change any default password promptly.

Do not configure disks or shares until you have reviewed OMV's storage model and confirmed the right physical disks.

## Step 4 — Preserve your administrator's SSH access

OMV may require SSH users to belong to the `_ssh` group. Check your existing Debian administrator:

~~~sh
id YOUR_USERNAME
~~~

Replace `YOUR_USERNAME` with the actual account you created during Debian installation.

If necessary, add that user to the `sudo` and `_ssh` groups:

~~~sh
sudo usermod -aG sudo,_ssh YOUR_USERNAME
~~~

Sign out and back in to obtain the new group memberships. Test a **separate SSH session** as this normal user before disabling root SSH.

In OMV's web interface, go to **Services → SSH** and disable root login. Keep a local emergency recovery password. Do not rely on root SSH for normal administration.

## Step 5 — Turn off automatic APT updates (the project's policy)

This policy is optional for other OMV users, but is part of this server design. It turns off unattended upgrades and the OMV APT notification schedule, while leaving manual updates available.

The repository includes a small [configuration helper](disable-automatic-updates.py) so you do not need to edit OMV's JSON database manually.

First enter the guide's directory (adapt the path if you cloned the repository elsewhere):

~~~sh
cd ~/home_server/07_openmediavault
~~~

Open and review the helper before using it:

~~~sh
nano disable-automatic-updates.py
~~~

Apply only the two OMV-specific settings:

~~~sh
sudo python3 disable-automatic-updates.py
~~~

If it reports an unexpected OMV configuration format, **stop**. Do not force a database change.

Refresh OMV's Salt settings:

~~~sh
sudo omv-salt stage run prepare
~~~

Apply only the relevant update states:

~~~sh
sudo omv-salt deploy run apt apticron
~~~

Next, disable Debian's periodic APT tasks. Open:

~~~sh
sudo nano /etc/apt/apt.conf.d/99-home-server-manual-updates
~~~

Add these lines and save:

~~~text
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
~~~

Check the OMV scheduled-update directories:

~~~sh
ls /etc/cron.daily
~~~

~~~sh
ls /etc/cron.weekly
~~~

The OMV apticron notification jobs should no longer be present. If they remain, inspect the Salt output before proceeding.

**Important:** this deliberately disables automatic **security** updates too. Plan to update Debian and OMV manually on a regular schedule.

## Step 6 — Finish in the OMV web interface

Use OMV's web UI to configure your data disks, filesystems, shared folders, users and services according to your needs. Do not install OMV-Extras, the `openmediavault-compose` plugin or Docker integration as part of this guide.

For independent Docker Engine, see [08](../08_docker/README.md).

**Done when:** OMV 8 is installed, the web interface is reachable, normal-user SSH works, and the selected update policy has been applied.

**References:** [Official OMV installation](https://www.openmediavault.org/install) · [OMV on Debian](https://docs.openmediavault.org/en/stable/installation/on_debian.html).
