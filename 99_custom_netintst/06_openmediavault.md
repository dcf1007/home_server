# Netinst — Install OpenMediaVault 8 during Debian installation

**Purpose:** add **OpenMediaVault 8 (Synchrony)** to the selected Debian 13 target, preserve administrator and SSH access, and disable OMV-specific scheduled package updates and APT notifications according to this server's policy.

**If Debian is already installed**, use [07 — Manually install/configure OMV](../07_openmediavault/README.md) instead. Its settings are applied by **you** in OMV's GUI and Debian's editor; no standalone Python helper is provided.

## Step 1 — Select OMV independently

In the early Simple-CDD menu, select **OpenMediaVault 8** and confirm the summary. It is independent of Docker and does **not** automatically select Docker, OMV-Extras or the Compose plugin.

The installer performs this profile **after** any selected Backports, kernel, firmware, ZRAM or Debian tweaks stages. It operates on the installed target under `/target`, not on the installer's temporary operating system.

## Step 2 — Prepare and verify target networking

Before OMV is installed, the target must have working DNS and an administrative recovery path.

The installer shows a reviewed APT transaction for these prerequisites:

- `systemd-resolved` and `psmisc` for system functions;
- `gnupg`, `ca-certificates` and `curl` for trustworthy repository setup;
- `openssh-server` and `sudo` to preserve normal administrator access.

The target looks up `packages.openmediavault.io`. If DNS fails, the profile **stops** rather than inventing a network configuration. Debian Installer's native package-service-start protection must already have been checked by the common dispatcher.

## Step 3 — Add the official signed OMV 8 repository

The installer downloads the vendor's signing key from:

`https://packages.openmediavault.io/archive.key`

It checks that GnuPG can read the key and display a fingerprint, converts it into the installed target's trusted keyring and removes the temporary download. **The current code checks that a fingerprint exists; it does not verify the fingerprint against an independently pinned expected value.**

It then creates an OMV source in the target with **`synchrony`** components from the official `packages.openmediavault.org` and `packages.openmediavault.io` repositories, each restricted by that signing-key file.

After refreshing signed package indexes, it checks that APT can see the **OMV 8** repository and the `openmediavault` package.

## Step 4 — Review and install OMV

The installer simulates the full target APT installation of `openmediavault`. Debian Installer displays the proposed packages, dependencies and removals and asks for a **default-No** approval.

With approval, it installs OMV through target APT using Debian Installer's progress display. It checks that the installed OMV package version begins with **8.** and audits package configuration. If a dependency or version check fails, it stops.

**No NAS data disk, share or Docker application is configured here.**

## Step 5 — Preserve an administrator and deny root SSH

The installer reads the **username you entered in Debian's normal account screen**; it does not hardcode a username.

It verifies that the account exists and that OMV's `_ssh` group is present. It then adds the account to `sudo` and `_ssh`, preserving its other group memberships. This gives the installer-created administrator normal sudo and permitted SSH access.

A target SSH drop-in sets:

~~~text
PermitRootLogin no
~~~

The installer checks the effective SSH configuration. This **disables remote root SSH**, not the local root password used for emergency recovery.

## Step 6 — Turn off OMV's unattended updates and APT notifications

In an ordinary system you would use OMV's own web interface as described in the [standalone guide](../07_openmediavault/README.md). **During installation there is no accessible, configured OMV web interface**, so this selected profile configures the target's OMV database before first boot.

The current installer implementation performs these checks and settings internally:

1. Read `conf.system.apt.updates` and verify the expected OMV 8 setting exists.
2. Set **`unattendedupgrade` to `false`**.
3. Read `conf.system.notification.notification`, find the **one** notification whose ID is `apt`, and set its **`enable` to `false`**.
4. Re-read both OMV records to confirm the values were saved. If the expected models or exactly one APT event are not present, stop.
5. Refresh OMV Salt configuration with `omv-salt stage run prepare`.
6. Deploy only OMV's `apt` and `apticron` states — **not** unrelated services or an obsolete `cronapt` state.
7. Verify that generated `openmediavault-apticron` daily/weekly cron jobs are absent; reject an active legacy `cron-apt` job.

**Implementation distinction:** the installer profile currently uses a short *inline* Python call within its own shell module to update OMV's structured configuration database safely. It does **not** install a separate Python helper file onto the NAS and the user does **not** run a script to configure OMV after boot. The normal [07 guide](../07_openmediavault/README.md) provides manual UI steps and no project helper.

## Step 7 — Disable Debian's separate periodic APT tasks

OMV's settings are not the same as Debian's periodic APT settings. The installer creates a small target override for:

~~~text
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
~~~

It checks the effective `apt-config` values, verifies DNS again after OMV setup, runs `dpkg --audit` and records the profile complete only after these checks pass.

**This deliberately turns off automatic security upgrades.** Manual APT/OMV updates remain your responsibility.

## Step 8 — Verify OMV at first boot

After first boot, confirm:

- OMV 8's web interface is reachable and its installed version is **8.x**;
- a normal administrator can connect by SSH, and **root SSH is denied**;
- the OMV unattended-upgrade setting and APT notification event remain disabled;
- no OMV apticron cron schedule remains active;
- Debian's separate scheduled-update settings are off;
- no OMV-Extras/Compose plugin or Docker integration was added automatically.

**Unverified:** the full selected-profile OMV 8 installation, Salt deployment and first-boot network/SSH policy still require a VM test. Implementation: [profile-omv.sh](my-cdd/installer/profile-omv.sh).
