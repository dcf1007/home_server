# 07 — Install and configure OpenMediaVault 8 on Debian 13

**Goal:** add the OpenMediaVault (OMV) 8 NAS interface and manually apply the project's update/notification policy. **You make the settings yourself** in OMV's web interface and Debian's own configuration files; there is **no project Python helper to run**.

**Before starting:** use a minimal Debian 13 (Trixie) installation without a desktop environment or existing web server. Confirm that DNS and networking work and keep physical-console or other recovery access: installing OMV may modify network services. OMV does not automatically add Docker, OMV-Extras, Compose, or NAS shares in this guide.

## Step 1 — Prepare for the official OMV installer

Refresh the available Debian package information. This retrieves package indexes; it does not upgrade anything:

~~~sh
sudo apt update
~~~

Install `wget`, a tool for downloading the vendor's installer. Review APT's package list before approving:

~~~sh
sudo apt install wget
~~~

## Step 2 — Download and inspect the OMV installer

Download the installation script **without executing it**:

~~~sh
wget https://get.openmediavault.io -O openmediavault-install.sh
~~~

This saves the vendor script as `openmediavault-install.sh` in the current directory. Review the actual file before running code as root:

~~~sh
nano openmediavault-install.sh
~~~

Read the instructions it will execute. If you cannot evaluate or accept them, stop and use OMV's [manual Debian installation guide](https://docs.openmediavault.org/en/stable/installation/on_debian.html). When satisfied, run the downloaded script, **with full administrative privileges**:

~~~sh
sudo sh openmediavault-install.sh
~~~

Follow its progress and stop if errors appear. Keep console access available in case its network setup changes connectivity. This installs OMV and dependencies; it is not just a configuration check.

## Step 3 — Verify OMV and regain access

Inspect the installed package version:

~~~sh
apt policy openmediavault
~~~

Under **Installed**, look for **8.x**. If it says `(none)`, the installation did not complete.

Check that no Debian packages were left partially configured:

~~~sh
sudo dpkg --audit
~~~

A healthy result is normally **no output**. Resolve any reported packages before proceeding.

Find the server's current IP address:

~~~sh
ip -brief address
~~~

Use the address on the active network connection to open the OMV web interface. Follow OMV's [initial web-login instructions](https://docs.openmediavault.org/en/stable/installation/) and change any default credentials.

## Step 4 — Keep normal-user SSH administration

OMV may require SSH users to belong to its `_ssh` group. Inspect your existing administrator's group memberships:

~~~sh
id YOUR_USERNAME
~~~

Replace `YOUR_USERNAME` with the Debian administrator you created. If the required memberships are absent, **and you trust this account to administer the server**, add it to both `sudo` and `_ssh` without dropping its other groups:

~~~sh
sudo usermod -aG sudo,_ssh YOUR_USERNAME
~~~

Sign out and back in so the new groups apply, then test a **new SSH login**. Only once this succeeds, use **Services → SSH** in OMV to disable **root login**, then **Save** and **Apply**. This blocks remote root login without locking the local recovery account.

## Step 5 — Turn off OMV's automatic updates yourself

The project's explicit preference is **manual package updates**, including security updates. This means you must commit to checking and installing security fixes yourself.

1. Open OMV's **System → Update Management → Updates** area. Find the **Software** or **Settings** options controlling automatic security updates (the exact placement can vary across OMV 8 builds).
2. Find the option named **Install security updates unattended**. Disable it. **Save** and **Apply** the pending change.
3. Open **System → Notification → Events**. Locate the **APT / package updates / cron-apt** notification event, and disable **only that event**. Preserve useful filesystem, SMART and RAID warnings. **Save** and **Apply**.
4. If a control is absent or named differently, **do not assume the corresponding policy has changed**. Review the current version's OMV UI and documentation before continuing.

These steps change the settings OMV itself manages, rather than directly editing its generated cron files. OMV's [update-management documentation](https://docs.openmediavault.org/en/8.x/various/apt.html) describes its update manager; its [notification documentation](https://docs.openmediavault.org/en/latest/administration/general/notifications.html) describes the independently selectable events.

To verify OMV's effective unattended-upgrade setting, **read its configuration database** (read-only):

~~~sh
sudo omv-confdbadm read --prettify conf.system.apt.updates
~~~

Find `"unattendedupgrade": false`. If the field is missing or still `true`, stop: the UI change has not produced the intended result.

To review OMV's notification settings, also **read** the event records:

~~~sh
sudo omv-confdbadm read --prettify conf.system.notification.notification
~~~

Find the record with `"id": "apt"` and check that its `"enable"` field is `false`. Do not change other notification events just to silence APT.

**Apply the OMV-managed update/notification configuration** using its normal Apply button. Normally, no further command is needed to apply an accepted UI change. Check the cron schedules in Step 6 first.

**Only if** the database values are correct but an OMV-generated apticron schedule remains active, investigate the OMV Apply result and use its own Salt mechanism as a targeted repair. Do not delete OMV-generated cron files manually.

For that corrective action, first refresh OMV's Salt configuration:

~~~sh
sudo omv-salt stage run prepare
~~~

If the first command succeeded, redeploy only the APT and apticron states, not unrelated services:

~~~sh
sudo omv-salt deploy run apt apticron
~~~

These optional repair commands reapply OMV's own configuration choices; they are not package upgrades. Check their output for errors, then recheck the schedules.

## Step 6 — Disable Debian's automatic APT tasks

OMV's own settings do not necessarily disable Debian's separate periodic package tasks. Inspect the current effective APT settings:

~~~sh
apt-config dump
~~~

Look for `APT::Periodic::Update-Package-Lists` and `APT::Periodic::Unattended-Upgrade`. If they are already zero, no additional file is needed.

Otherwise, **manually** open an APT override file:

~~~sh
sudo nano /etc/apt/apt.conf.d/99-home-server-manual-updates
~~~

Enter these two lines **into the file**:

~~~text
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
~~~

Save the file. Run `apt-config dump` again and check that the effective values are zero.

Review the generated OMV cron directories **without modifying them**:

~~~sh
ls /etc/cron.daily
~~~

~~~sh
ls /etc/cron.weekly
~~~

Look for `openmediavault-apticron`. If it remains active, the policy is **not fully verified**; resolve the OMV event configuration and its Salt deployment rather than deleting an OMV-generated cron file.

On systems upgraded from older OMV versions, there may also be a legacy `cron-apt` schedule. **If** `/etc/cron.d/cron-apt` exists, open it for inspection:

~~~sh
sudo nano /etc/cron.d/cron-apt
~~~

This shows whether an actual, uncommented scheduled command remains. **Do not edit the file merely because it exists**; identify whether another package or OMV still manages the schedule and disable it through that configuration. A legacy active update schedule means the manual-only policy is not yet complete.

## Step 7 — Use the OMV web interface for your NAS

Configure actual data disks, filesystems, users, shared folders and protocols in OMV's web interface after confirming the correct devices. This chapter does not create any shares or install OMV-Extras or Docker.

For Docker as an **independent** service, follow [08 — Docker](../08_docker/README.md).

**Done when:** OMV 8 works, normal-user SSH works, the unattended-upgrade and APT notification values have been verified off, and no generated notification schedule remains. **This exact OMV 8 UI sequence and Salt outcome still need verification on the installed version**; do not claim success based only on clicking Save.
