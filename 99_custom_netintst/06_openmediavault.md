# 06 — Build the OpenMediaVault 8 installer profile

**Build goal:** implement an **optional Simple-CDD profile** that installs signed OMV 8 packages in `/target`, preserves the newly created administrator's SSH/sudo access, and sets the approved **manual-only updates** policy before first boot.

This is a **guide to writing installer automation**. For an already installed server, follow [07 — OMV 8](../07_openmediavault/README.md) and set the options manually in the OMV web UI. **Do not write an external Python script that a human must run after boot.**

## Step 1 — Register and stage the OMV module

Create `profiles/openmediavault.description` and `profiles/openmediavault.extra`:

~~~text
installer/profile-omv.sh
~~~

Keep the profile name `openmediavault` in the offered list, with no automatic selection. The shared dispatcher maps it to:

~~~sh
openmediavault) module=omv; handler=profile_omv ;;
~~~

Create `profile_omv()` in `installer/profile-omv.sh`. Keep `profiles/openmediavault.postinst` as **verification-only**.

## Step 2 — Install and verify prerequisites in /target

The profile starts with an APT review for networking, HTTPS/signing, SSH and sudo prerequisites:

~~~sh
review_install 'OMV prerequisites: resolver, SSH/sudo access and signing tools' systemd-resolved psmisc gnupg ca-certificates curl openssh-server sudo
~~~

The common helper simulates dependencies and removals and asks default-No approval. Then test DNS from **the installed target**:

~~~sh
capture in-target getent ahostsv4 packages.openmediavault.io ||
    fatal 'Target DNS unavailable; stop rather than invent network configuration'
~~~

**Why:** the installer environment may have network access while `/target` lacks correct DNS. Do not silently invent a new DNS setting after such a failure.

## Step 3 — Build the signed OMV source setup

Inside `profile_omv()`, download OMV's official archive key using target `curl` over HTTPS, inspect it with target `gpg --show-keys --with-colons` and verify it contains a fingerprint record. Convert it to a binary keyring under the target's `/usr/share/keyrings`, then remove the temporary downloaded key.

**Security distinction:** the tracked code checks that a fingerprint exists; it does **not** compare it with an independently pinned fingerprint. Do not claim it does.

Create the installed target's `/etc/apt/sources.list.d/openmediavault.list` from these actual lines:

~~~text
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.org/public/ synchrony main
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.io/ synchrony main
~~~

**Purpose:** OMV 8's `synchrony` packages must be signed by the specified key and available to target APT. Refresh target indexes and inspect `apt-cache policy openmediavault`, requiring the expected official `synchrony/main` origin before installation.

## Step 4 — Review and install OMV 8

Use the shared package review helper:

~~~sh
review_install 'OMV 8 package and dependencies' openmediavault
~~~

This is not a blind install: it simulates the target transaction, checks critical removals, presents the complete plan and requests default-No approval. Once accepted, native Debian Installer package progress installs it into `/target`.

Verify the installed `openmediavault` package version begins with `8.`; otherwise fail without writing a completion marker.

## Step 5 — Preserve the actual Debian admin account

Get the username from **Debian Installer's existing user-setup database** (`passwd/username`), not a hardcoded name. Validate that the target account and OMV's `_ssh` group exist.

The source performs:

~~~sh
run_target usermod -aG sudo,_ssh "$admin"
~~~

Here `admin` is the validated installer-created username. This adds both groups **without removing existing memberships**.

Create a target `sshd_config.d` drop-in containing:

~~~text
PermitRootLogin no
~~~

Then check target `sshd -T` and require the effective value `permitrootlogin no`. This keeps local emergency-root access but disallows remote root SSH.

## Step 6 — Implement the OMV policy in the installer code

This is the part that differs from the manual OMV GUI instructions: **there is no usable OMV web UI during Debian Installer's late command**. The selected installer profile must set the target's OMV configuration before first boot.

The current implementation contains an **inline Python block inside `profile-omv.sh`**, using `omv-confdbadm` through subprocess calls. It does **not** install or require a separate Python helper file.

Build this block to:

1. Read OMV's `conf.system.apt.updates` JSON record; ensure the expected `unattendedupgrade` boolean exists.
2. Set `unattendedupgrade` to `false` and update the same OMV model.
3. Read `conf.system.notification.notification`, require exactly **one** record with `id == "apt"`, set its `enable` to `false` and write it back.
4. Re-read **both** models to verify values; error out on an unknown schema or unexpected notification count.
5. Never disable other notifications or modify generated cron jobs directly.

These are **code design steps**, not commands a human should run in an OMV terminal. The exact current block is in [profile-omv.sh](my-cdd/installer/profile-omv.sh); copying only two database values without the schema checks would not preserve its fail-closed behavior.

## Step 7 — Deploy only the relevant OMV states

After the verified configuration-database update, the selected module runs:

~~~sh
run_target omv-salt stage run prepare
run_target omv-salt deploy run apt apticron
~~~

**Reason:** OMV's generated APT and apticron files are controlled by Salt. Do not edit generated cron scripts or deploy unrelated OMV services.

The code requires no `/target/etc/cron.daily/openmediavault-apticron` or weekly counterpart remains, and refuses an active legacy `cron-apt` schedule.

## Step 8 — Disable Debian's separate scheduled APT tasks

OMV's configuration database is separate from Debian's APT periodic options. In `/target/etc/apt/apt.conf.d/99-my-cdd-manual-updates`, write:

~~~text
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
~~~

Verify both **effective** values via target `apt-config dump`. Then check that target DNS still works and `dpkg --audit` finds no unfinished package configuration.

**Why two layers:** OMV's unattended-upgrade and APT notification policy does not prove Debian's independent periodic jobs are disabled.

## Step 9 — Test selection, state and first boot

Parse the installer module without executing it:

~~~sh
sh -n installer/profile-omv.sh
~~~

Build via `./build.sh` and boot a disposable VM. Test **OMV unselected**, selected/approved, the package-repository failure path, invalid OMV confdb schema, declined package approval, GUI availability, normal-user SSH, scheduled-update configuration and DNS after first boot. OMV's exact Salt behavior remains a runtime validation requirement.

**Source:** [profile-omv.sh](my-cdd/installer/profile-omv.sh). The ordinary [standalone guide](../07_openmediavault/README.md) has manual GUI steps and **no extra Python helper**.
