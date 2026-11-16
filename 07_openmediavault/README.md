# 07 — Install OpenMediaVault 8 on Debian 13

**What this does:** adds the OpenMediaVault 8 (Synchrony) NAS web interface to a minimal Debian 13 server.

**Before starting:** Debian is already installed **without a desktop environment or web server**. You have working network/DNS and a local console or recovery login. OMV takes control of configuration for services it manages, so it may change network and SSH settings. This guide does not install Docker, OMV-Extras, Compose or any NAS shares.

## Step 1 — Prepare Debian

This updates Debian’s package indexes before adding OMV. It does **not** install OMV; stop if normal Debian repositories cannot be reached or verified.

~~~sh
sudo apt update
~~~

This installs `wget`, the program used next to download OMV’s official installer script. Review APT’s proposed changes and confirm only if acceptable.

~~~sh
sudo apt install wget
~~~

Keep local access available during installation in case the network configuration changes.

## Step 2 — Download the official OMV installer

OMV publishes a [quick installation method for Debian 13](https://www.openmediavault.org/install). To avoid piping a remote script directly into a shell, **download it as a file first**:

This **downloads** the OMV vendor’s current installer to the local file `openmediavault-install.sh` without running it. Confirm the download succeeded; the file contains code that would later run as root.

~~~sh
wget https://get.openmediavault.io -O openmediavault-install.sh
~~~

Open the downloaded script and review it:

This opens the downloaded shell script so you can **read what it would do** before executing it. If it does anything you do not understand or approve, do not run the next command.

~~~sh
nano openmediavault-install.sh
~~~

This is vendor-supplied code that will run as root. **If you do not trust or approve its contents, do not run it.** Alternatively follow OMV's [manual Debian installation guide](https://docs.openmediavault.org/en/stable/installation/on_debian.html).

When satisfied, run the saved script:

This runs the reviewed, downloaded OMV installation script with **root privileges**. It may install packages and change network/service settings. Use local recovery access, read its output and stop if it reports an error.

~~~sh
sudo sh openmediavault-install.sh
~~~

Follow any prompts and let the installer finish. If it fails, resolve the reported error rather than running unrelated installation scripts.

## Step 3 — Check that OMV installed correctly

This shows the OMV package’s installed and candidate versions and repository origins. The `Installed` line should identify **OMV 8.x**; if it says `(none)`, the installation did not complete.

~~~sh
apt policy openmediavault
~~~

Check the installed version. It should be **8.x**.

This checks whether Debian has packages that are unpacked but not configured. **No output generally means no incomplete packages**; address listed items before configuring the NAS.

~~~sh
sudo dpkg --audit
~~~

If nothing is reported, Debian has no unfinished package configurations.

This shows the server’s IP addresses after OMV installation. Use the address of the active network interface to reach the web UI, and compare with the pre-install network configuration if access changed.

~~~sh
ip -brief address
~~~

Use your server's address in a browser to open the OMV web interface. OMV's initial web login is documented in its [installation guide](https://docs.openmediavault.org/en/stable/installation/); change any default password promptly.

Do not configure disks or shares until you have reviewed OMV's storage model and confirmed the right physical disks.

## Step 4 — Preserve your administrator's SSH access

OMV may require SSH users to belong to the `_ssh` group. Check your existing Debian administrator:

This shows which groups and numeric IDs belong to the specified administrator. Replace `YOUR_USERNAME` with your actual Debian account and check whether `sudo` and OMV’s `_ssh` group are already present.

~~~sh
id YOUR_USERNAME
~~~

Replace `YOUR_USERNAME` with the actual account you created during Debian installation.

If necessary, add that user to the `sudo` and `_ssh` groups:

This **adds** the named user to the `sudo` and `_ssh` groups without removing other memberships. It grants administrator and allowed-SSH access; run it only for a trusted account and verify the groups after signing in again.

~~~sh
sudo usermod -aG sudo,_ssh YOUR_USERNAME
~~~

Sign out and back in to obtain the new group memberships. Test a **separate SSH session** as this normal user before disabling root SSH.

In OMV's web interface, go to **Services → SSH** and disable root login. Keep a local emergency recovery password. Do not rely on root SSH for normal administration.

## Step 5 — Turn off automatic APT updates (the project's policy)

This policy is optional for other OMV users, but is part of this server design. It turns off unattended upgrades and the OMV APT notification schedule, while leaving manual updates available.

The repository includes a small [configuration helper](disable-automatic-updates.py) so you do not need to edit OMV's JSON database manually.

First enter the guide's directory (adapt the path if you cloned the repository elsewhere):

This changes into the repository’s OMV guide directory so the helper below can be found. If your checkout is elsewhere, use its actual path; this command changes no OMV settings.

~~~sh
cd ~/home_server/07_openmediavault
~~~

Open and review the helper before using it:

This opens the project’s Python helper for inspection. The script modifies **two OMV configuration database values**; read it and verify those are the intended settings before proceeding.

~~~sh
nano disable-automatic-updates.py
~~~

Apply only the two OMV-specific settings:

This runs the reviewed helper as root. It disables OMV 8 unattended-upgrade and APT notification settings in OMV’s own configuration database. **If it reports an unexpected schema, stop** rather than forcing an edit.

~~~sh
sudo python3 disable-automatic-updates.py
~~~

If it reports an unexpected OMV configuration format, **stop**. Do not force a database change.

Refresh OMV's Salt settings:

This refreshes the OMV Salt environment (grains/modules/pillar) before deploying changed configuration. It is not a general package upgrade; inspect the output for errors.

~~~sh
sudo omv-salt stage run prepare
~~~

Apply only the relevant update states:

This applies only OMV’s `apt` and `apticron` Salt states, which implement its update/notification policy. Check that the command succeeds; do not deploy unrelated OMV states as a workaround.

~~~sh
sudo omv-salt deploy run apt apticron
~~~

Next, disable Debian's periodic APT tasks. Open:

This opens Debian’s additional APT settings file. The two configuration lines shown next disable Debian’s scheduled list updates and unattended upgrades, **including automatic security updates**, while leaving manual updates possible.

~~~sh
sudo nano /etc/apt/apt.conf.d/99-home-server-manual-updates
~~~

Add these lines and save:

~~~text
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
~~~

Check the OMV scheduled-update directories:

This lists jobs in `/etc/cron.daily`. Check whether an OMV `openmediavault-apticron` notification job remains; the list is for **inspection**, not removal.

~~~sh
ls /etc/cron.daily
~~~

This lists jobs in `/etc/cron.weekly`. Again look for an OMV `openmediavault-apticron` job; if one remains, inspect OMV’s Salt output instead of deleting a generated file by hand.

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
