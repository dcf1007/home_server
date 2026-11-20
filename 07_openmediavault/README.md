# 07 — Install OpenMediaVault 8 on Debian 13

**Goal:** install OMV 8 from its official signed APT repository and perform the two initialization steps in the [official OMV installer](https://github.com/openmediavault/openmediavault/blob/master/install.sh). The OMV web interface handles later NAS configuration. This guide does **not** configure SSH, account groups, automatic updates, notifications, plugins or Docker.

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

**Before starting:** use Debian 13 (Trixie) without a desktop environment, on amd64 or arm64. Follow the numbered [base Debian guide](../01_base_debian/README.md) first. OMV's [manual installation guide](https://docs.openmediavault.org/en/8.x/installation/on_debian.html) explicitly requires working DNS and a configured `systemd-resolved` **before** installing OMV; otherwise the package installation can interrupt name resolution. Verify this prerequisite and keep local console access. OMV's packages may change network services.

</td>
</tr>
</table>

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

**Existing Debian settings:** OMV is a configuration manager, not just an additional application. Its [installation documentation](https://docs.openmediavault.org/en/8.x/installation/on_debian.html) states that most existing managed service settings are not imported (network/time are exceptions, with import limitations). OMV package installation can deploy its own SSH, APT, sysctl and other configurations. Before proceeding, retain console access and note any settings from Chapters 01–06 that you intend to keep. The [post-install notes below](#omv-8-configuration-ownership-and-post-install-checks) explain what to review; they do not add mandatory package or configuration operations.

</td>
</tr>
</table>

## Step 1 — Install repository tools

Refresh Debian package lists and install the tools used by OMV's official installer. Review the APT transaction before approving it:

~~~sh
sudo apt update
sudo apt install gnupg wget
~~~

## Step 2 — Install the official signing key

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="100%" alt="Important note"></td>
<td valign="top" width="100%">

Download the key to a local file rather than executing a remote script. The download URL is the one used by the official installer:

</td>
</tr>
</table>

~~~sh
wget -O openmediavault-archive.key https://packages.openmediavault.io/archive.key
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="100%" alt="Important note"></td>
<td valign="top" width="100%">

Inspect the key before installing it. This prints its identity/fingerprint; it is **not** independent verification against a trusted published fingerprint:

</td>
</tr>
</table>

~~~sh
gpg --show-keys --with-fingerprint openmediavault-archive.key
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="100%" alt="Important note"></td>
<td valign="top" width="100%">

Install it as a dedicated APT keyring (review an existing destination before replacing it):

</td>
</tr>
</table>

~~~sh
sudo gpg --dearmor -o /usr/share/keyrings/openmediavault-archive-keyring.gpg openmediavault-archive.key
~~~

Ensure the installed **public signing key** is readable by APT's unprivileged `_apt` user:

~~~sh
sudo chmod 0644 /usr/share/keyrings/openmediavault-archive-keyring.gpg
~~~

This does not weaken repository signature verification; it only makes the public keyring accessible to the signature verifier.

## Step 3 — Add OMV's official signed APT repository

Create the standard APT source directory if necessary:

~~~sh
sudo mkdir -p /etc/apt/sources.list.d
~~~

Open `/etc/apt/sources.list.d/openmediavault.list` with administrator privileges in a text editor. Save **only this entry**, the first repository listed in [OMV's manual Debian 13 installation guide](https://docs.openmediavault.org/en/8.x/installation/on_debian.html):

~~~text
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.org/public/ synchrony main
~~~

The keyring authenticates the repository's signed APT metadata. No fallback-mirror file, proposed/partner repository, or global APT pin is needed.

## Step 4 — Review and install OMV

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="100%" alt="Important note"></td>
<td valign="top" width="100%">

Refresh the signed package lists; stop if repository signatures or downloads fail:

</td>
</tr>
</table>

~~~sh
sudo apt update
~~~

Simulate the complete OMV transaction **without installing anything**:

~~~sh
sudo apt-get -s install --no-install-recommends openmediavault
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="100%" alt="Important note"></td>
<td valign="top" width="100%">

Review the package changes, especially removals, downgrades or held packages. If they are unexpected, stop rather than accepting them blindly. Then install the actual package with APT's normal confirmation:

</td>
</tr>
</table>

~~~sh
sudo apt install --no-install-recommends openmediavault
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

The official quick installer passes additional flags permitting removals and downgrades without review; this manual guide deliberately does not. It installs the same OMV package from the same official repository, but retains explicit transaction control.

</td>
</tr>
</table>

## Step 5 — Complete the two upstream initialization steps

Populate OMV's initial configuration database:

~~~sh
sudo omv-confdbadm populate
~~~

Deploy OMV's managed `/etc/hosts` configuration so its own hostname resolves:

~~~sh
sudo omv-salt deploy run hosts
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

These are the two explicit post-package commands in the official installer. Do not run `omv-salt stage run all` or change other services as part of this installation.

</td>
</tr>
</table>

## Step 6 — Verify and use OMV

Check the installed package version and package state:

~~~sh
dpkg-query -W -f='${Version}\n' openmediavault
sudo dpkg --audit
~~~

The version must begin with **8.**; `dpkg --audit` should report no partially configured packages. Find the server's current address:

~~~sh
ip -brief address
~~~

Open the OMV web interface using that address. Follow [OMV's login instructions](https://docs.openmediavault.org/en/stable/installation/) and change the initial web credentials.

## OMV 8 configuration ownership and post-install checks

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

These notes apply to a normally installed Debian 13 system after installing OMV 8 (also relevant after later OMV deployments and upgrades). Sources checked on 2026-11-20: the OMV 8 documentation and upstream OMV source snapshot [d2f39bc](https://github.com/openmediavault/openmediavault/commit/d2f39bc069c0273d1890a1913bef63c87915f415). The actual installed package and configuration remain authoritative; source inspection is not a live test. The following are observations and read-only checks, not an additional mandatory hardening or setup policy.

</td>
</tr>
</table>

### SSH and administrative access (Chapters 01–02)

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

The [SSH Salt state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/ssh/20sshd_config.sls) manages and diverts `/etc/ssh/sshd_config`. Settings are rendered from OMV's configuration database (`/etc/openmediavault/config.xml`, object `conf.service.ssh`), replacing direct edits when the SSH state is deployed. Its [data model](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/usr/share/openmediavault/datamodels/conf.service.ssh.json) defaults root login, password authentication and public-key authentication to enabled, and its [template](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/ssh/files/sshd_config.j2) normally restricts access with `AllowGroups root _ssh`. OMV's official installation guide explicitly warns that the original Debian administrator may lose SSH access unless permitted by that group. Sudo and SSH authorization are separate. The documented initial root SSH access is separate from the local recovery password; disabling SSH root login does not lock the local account.

For inspection on the running system (not inside Debian Installer):

~~~sh
id
getent group _ssh
sudo /usr/sbin/sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowgroups|authorizedkeysfile|port) '
~~~

The first two commands show current group membership and the group record; the third prints effective global SSH settings. If conditional `Match` rules exist, inspect the effective configuration for the actual connection with `sshd -T -C` and the corresponding connection values. Verify a separate normal-user SSH session and sudo access before relying on a revised root-login policy.

Review ordinary settings in **Services | SSH**; use OMV's user management for `_ssh` membership and public keys where desired. When public-key authentication is enabled, the current template normally includes **both** the user's home-directory `.ssh/authorized_keys` / `.ssh/authorized_keys2` and OMV's central `/var/lib/openmediavault/ssh/authorized_keys/%u`. The [key deployment state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/ssh/10authorized_keys.sls) rebuilds the central directory from OMV user records, so manual edits to that directory are not durable. This is not a claim that valid home-directory keys cease working.

**Extra options and drop-ins:** OMV's template emits its explicit settings first, then the database-backed Extra options field, then `Include /etc/ssh/sshd_config.d/*.conf` at the bottom (unlike ordinary Debian). OpenSSH generally uses the first obtained value; some directives accumulate or are conditional. Neither Extra options nor a normal drop-in can be assumed to override an earlier single-value setting such as `PermitRootLogin`. Use the WebUI's dedicated setting for supported options. For advanced options consult OMV's [custom configuration guide](https://docs.openmediavault.org/en/8.x/various/advset.html) and available environment variables / custom Salt states, with separately approved changes only. Verify effective settings rather than assuming precedence or universal drop-in persistence.

**Sources:** [OMV 8 SSH documentation](https://docs.openmediavault.org/en/8.x/administration/services/ssh.html), [Debian sshd_config(5)](https://manpages.debian.org/trixie/openssh-server/sshd_config.5.en.html), [older upstream root-access issue #779](https://github.com/openmediavault/openmediavault/issues/779), [older public-key issue #946](https://github.com/openmediavault/openmediavault/issues/946) and [community report](https://www.reddit.com/r/OpenMediaVault/comments/146hpxa/omv_web_gui_overwriting_ssh_settings_how_do_i/). The current template, rather than the older reports, determines the default key paths and Include ordering.

</td>
</tr>
</table>

### Automatic updates and SSH regeneration (Chapters 02–03)

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

OMV 8 depends on `unattended-upgrades` and `apticron` ([package dependencies](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/debian/control)); the older `cron-apt` wording still present in the [update documentation](https://docs.openmediavault.org/en/8.x/various/apt.html) does not describe the inspected source. OMV's [95 periodic defaults](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/etc/apt/apt.conf.d/95openmediavault-periodic) enable package-list refresh/download but set automatic installation to 0. The [update data model](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/usr/share/openmediavault/datamodels/conf.system.apt.updates.json) defaults automatic security installation to enabled, and the [APT Salt state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/apt/30periodic_custom.sls) creates `98openmediavault-periodic-custom` with value 1 when enabled, removes it otherwise. Its [unattended-upgrade configuration](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/etc/apt/apt.conf.d/95openmediavault-unattended-upgrade) clears the origin list and selects Debian Security origins by default, not OMV's package repository. Local overrides may change this. The OMV [APT default state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/apt/10default.sls) removes/diverts the ordinary `50unattended-upgrades` file.

The Chapter 02 Debian setting may therefore be superseded. Review the **Install security updates unattended** option under System | Update Management | Settings (Software section, if shown in your installed version). Check actual settings rather than relying on the service's active status alone:

~~~sh
apt-config dump | grep -E 'APT::Periodic::|Unattended-Upgrade::(Origins-Pattern|Allowed-Origins|Automatic-Reboot)'
systemctl list-timers --all apt-daily.timer apt-daily-upgrade.timer
~~~

The first command inspects effective APT settings including origin rules; the second inspects the scheduled APT jobs. Package-list refreshes, downloads, notifications and installation are distinct; none is disabled by this note.

Automatic installation of the OMV package itself is **not the stock security-only origin policy**. If a local configuration permits OMV upgrades, its maintainer scripts still run like those of manually upgraded packages. The inspected [postinst](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/debian/openmediavault.postinst) deploys SSH, APT and sysctl on first install; later versions have conditional migrations that may mark SSH or other modules dirty (e.g. the transition from versions older than 8.2.0). Applying a pending SSH deployment or explicitly deploying the SSH state can regenerate the file. There is no unconditional SSH deployment after every OMV upgrade in this source. Regular Debian OpenSSH updates follow Debian package configuration handling, but OMV's diversion and service deployment mean conffile preservation is not a guarantee for OMV-managed files. Use supported OMV configuration, not an assumption about which upgrade mechanism is used.

</td>
</tr>
</table>

### APT repositories, Backports, kernel and firmware (Chapters 03–05)

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

The [APT deployment state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/apt/10default.sls) can rewrite `openmediavault.list` to use its signed mirror list, manage OS security sources, remove `APT::Default-Release` assignments and supply its own kernel Backports repository and preference file. This describes OMV's package behavior; it is not a change to the approved single-repository initial installation procedure above. By default, `OMV_APT_USE_KERNEL_BACKPORTS` is true and the [preferences template](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/apt/files/etc-apt-preferences_d-openmediavault-kernel-backports_pref.j2) assigns priority 500 to `linux-base`, `linux-image-*`, `linux-headers-*` and `firmware-*` from Backports (not a global pin, nor a pin matching the two CPU microcode names). Therefore package-specific selection may differ from ordinary Debian's priority 100, and a repository can appear even when Chapter 03 was skipped. OMV's official [software guidance](https://docs.openmediavault.org/en/8.x/various/apt.html) warns that arbitrary packages from Backports/Testing/Experimental may cause incompatibilities.

~~~sh
apt policy
apt policy linux-image-amd64 linux-headers-amd64 firmware-realtek intel-microcode amd64-microcode
uname -r
~~~

Inspect both relevant source/preference files and the actual candidate versions. The guide's approved 7.x image/header requirement and initial fallback are separate from OMV's package preferences; a future update may change the candidates. Do not silently remove an OMV-managed repository or change pin priorities to restore an earlier guide's assumptions.

</td>
</tr>
</table>

### ZRAM, sysctl and root/data filesystems (Chapters 02 and 06)

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

OMV's [nonrotating-root Salt state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/sysctl/nonrot.sls) can generate `/etc/sysctl.d/99-openmediavault-nonrot.conf` on a detected nonrotating root disk, setting `vm.swappiness` to 1 by default along with other I/O tuning. Its [sysctl state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/sysctl/default.sls) reloads sysctl configuration. The later filename takes precedence over this project's `90-zram.conf` setting of 100 under normal [sysctl.d ordering](https://manpages.debian.org/trixie/systemd/sysctl.d.5.en.html). This is a possible real conflict even if the ZRAM files themselves were never edited. Check after installing OMV, after reboot and after a relevant redeployment:

~~~sh
sysctl vm.swappiness
swapon --show
zramctl
findmnt /
cat /etc/fstab
~~~

If the generated value conflicts with the selected ZRAM design, inspect `OMV_SYSCTL_VM_SWAPPINESS` (the [supported environment customization mechanism](https://docs.openmediavault.org/en/8.x/various/advset.html)) and the actual effective settings before deciding how to resolve it. No change to the variable, sysctl filename, production ZRAM service or diagnostic is made by this guide. Inspect the generator/monitor status using Chapter 06 if ZRAM was configured. Do not put the raw backing device into NAS storage or activate it as normal swap.

OMV's [fstab state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/fstab/default.sls) replaces the block between `# >>> [openmediavault]` and `# <<< [openmediavault]`; the [official configuration file guidance](https://docs.openmediavault.org/en/8.x/various/files.html) confirms that other entries may exist outside that block. Root/EFI and unrelated manual entries outside it are not the target of that state. Do not edit the OMV-managed data mounts inside the block; review the root mount options and selected backing identity independently.

</td>
</tr>
</table>

### Network, DNS, time and other managed services (Chapters 01, 08 and 09)

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

OMV imports certain network/time settings, but the [installation documentation](https://docs.openmediavault.org/en/8.x/installation/on_debian.html) says its network import currently parses `/etc/network/interfaces` only. It documents `omv-salt deploy run systemd-networkd` or `omv-firstaid` for network setup and warns that the IP can change. The [network states](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/systemd-networkd/10network_interfaces.sls) manage the interfaces file, and the [resolver state](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/srv/salt/omv/deploy/systemd-networkd/90resolv_conf.sls) can replace `/etc/resolv.conf` with a systemd-resolved symlink. The [postinst](https://github.com/openmediavault/openmediavault/blob/d2f39bc069c0273d1890a1913bef63c87915f415/deb/openmediavault/debian/openmediavault.postinst) also enables networkd/resolved on first installation, uses chrony and disables/masks the replaced systemd-timesyncd/ntp services. These are vendor operations, not additional CDD policy.

~~~sh
ip -brief address
resolvectl status
getent hosts deb.debian.org
timedatectl
systemctl status chrony
~~~

These commands inspect the active network, name resolution and time synchronization. If the OMV network setup is incomplete, the documented network deployment/recovery mechanism is a separate manual decision; this note does not append a deployment command to the approved two-command initialization sequence. OMV also manages its own web server, file-sharing, notification and monitoring configurations; see the [official configuration file list](https://docs.openmediavault.org/en/8.x/various/files.html) before editing them. Docker and labwc remain independent optional procedures. No automatic network, SSH, APT, storage or service changes are prescribed here.

</td>
</tr>
</table>

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

**Scope ends here.** SSH access policy, account groups, update schedules, APT notifications, storage, shares and additional applications are separate decisions. Neither the standalone guide nor the OMV CDD profile imposes them. Docker remains independent in [08 — Docker](../08_docker/README.md).

</td>
</tr>
</table>

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

**Runtime status:** the signed-repository installation and subsequent networking/first-boot behavior must still be verified on a fresh Debian 13 VM. Do not claim functional success from the presence of the package alone.

</td>
</tr>
</table>
