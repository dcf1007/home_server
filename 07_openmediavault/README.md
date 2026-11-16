# 07 — Install OpenMediaVault 8 on Debian 13

**Goal:** install OMV 8 from its official signed APT repository and perform the two initialization steps in the [official OMV installer](https://github.com/openmediavault/openmediavault/blob/master/install.sh). The OMV web interface handles later NAS configuration. This guide does **not** configure SSH, account groups, automatic updates, notifications, plugins or Docker.

**Before starting:** use Debian 13 (Trixie) without a desktop environment, on amd64 or arm64. Confirm working network/DNS and keep local console access: OMV's own packages may change system services or networking. Follow the numbered [base Debian guide](../01_base_debian/README.md) first.

## Step 1 — Install repository tools

Refresh Debian package lists and install the tools used by OMV's official installer. Review the APT transaction before approving it:

~~~sh
sudo apt update
sudo apt install gnupg wget
~~~

## Step 2 — Install the official signing key

Download the key to a local file rather than executing a remote script. The download URL is the one used by the official installer:

~~~sh
wget -O openmediavault-archive.key https://packages.openmediavault.io/archive.key
~~~

Inspect the key before installing it. This prints its identity/fingerprint; it is **not** independent verification against a trusted published fingerprint:

~~~sh
gpg --show-keys --with-fingerprint openmediavault-archive.key
~~~

Install it as a dedicated APT keyring (review an existing destination before replacing it):

~~~sh
sudo gpg --dearmor -o /usr/share/keyrings/openmediavault-archive-keyring.gpg openmediavault-archive.key
~~~

## Step 3 — Add OMV's signed repository

Create the official mirror-list directory and APT source directory:

~~~sh
sudo mkdir -p /etc/apt/mirrors /etc/apt/sources.list.d
~~~

Open `/etc/apt/mirrors/openmediavault.txt` with administrator privileges in a text editor and enter the official priority-ordered mirrors:

~~~text
https://packages.openmediavault.org/public/ priority:1
https://packages.openmediavault.io/ priority:2
https://openmediavault.github.io/packages/ priority:3
https://downloads.sourceforge.net/project/openmediavault/packages/ priority:4
~~~

Open `/etc/apt/sources.list.d/openmediavault.list` with administrator privileges and enter:

~~~text
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] mirror+file:/etc/apt/mirrors/openmediavault.txt synchrony main
## Uncomment the following line to add software from the proposed repository.
# deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] mirror+file:/etc/apt/mirrors/openmediavault.txt synchrony-proposed main
## This software is not part of OpenMediaVault, but is offered by third-party
## developers as a service to OpenMediaVault users.
# deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] mirror+file:/etc/apt/mirrors/openmediavault.txt synchrony partner
~~~

The proposed and partner repositories remain disabled. No global APT pin is changed.

## Step 4 — Review and install OMV

Refresh the signed package lists; stop if repository signatures or downloads fail:

~~~sh
sudo apt update
~~~

Simulate the complete OMV transaction **without installing anything**:

~~~sh
sudo apt-get -s install --no-install-recommends openmediavault
~~~

Review the package changes, especially removals, downgrades or held packages. If they are unexpected, stop rather than accepting them blindly. Then install the actual package with APT's normal confirmation:

~~~sh
sudo apt install --no-install-recommends openmediavault
~~~

The official quick installer passes additional flags permitting removals and downgrades without review; this manual guide deliberately does not. It installs the same OMV package from the same official repository, but retains explicit transaction control.

## Step 5 — Complete the two upstream initialization steps

Populate OMV's initial configuration database:

~~~sh
sudo omv-confdbadm populate
~~~

Deploy OMV's managed `/etc/hosts` configuration so its own hostname resolves:

~~~sh
sudo omv-salt deploy run hosts
~~~

These are the two explicit post-package commands in the official installer. Do not run `omv-salt stage run all` or change other services as part of this installation.

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

**Scope ends here.** SSH access policy, account groups, update schedules, APT notifications, storage, shares and additional applications are separate decisions. Neither the standalone guide nor the OMV CDD profile imposes them. Docker remains independent in [08 — Docker](../08_docker/README.md).

**Runtime status:** the signed-repository installation and subsequent networking/first-boot behavior must still be verified on a fresh Debian 13 VM. Do not claim functional success from the presence of the package alone.
