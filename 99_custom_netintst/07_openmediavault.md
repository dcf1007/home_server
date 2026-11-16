# 07 — Recreate OpenMediaVault 8 installer support

**Outcome:** build the full **optional OMV 8 profile source** for the custom Debian netinst image, not a script someone must run manually after installation. On a running Debian server, follow [07 — Manual OMV setup](../07_openmediavault/README.md); that guide uses the OMV GUI and requires **no external project Python helper**.

## Step 1 — Prepare the shared installer code

Complete [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md), then work inside `99_custom_netintst/my-cdd/` on a test branch or scratch copy.

The optional profile ID is `openmediavault`. Its source file is `installer/profile-omv.sh`, which defines `profile_omv()`. The existing dispatcher maps the ID to that function **only when selected**.

## Step 2 — Create these complete files

| Source path | Responsibility |
| --- | --- |
| `profiles/openmediavault.description` | The OMV 8 checkbox label. |
| `profiles/openmediavault.extra` | Stages the OMV installer-side module onto the ISO. |
| `profiles/openmediavault.postinst` | Verifies completion; it must be executable and must not reinstall OMV. |
| `installer/profile-omv.sh` | Full code for prerequisites, official OMV key/source, APT approval, admin SSH, OMV update database and Salt deployment. |

Create source directories if absent:

~~~sh
mkdir -p profiles installer
~~~

This only creates folders.

**1. Create `profiles/openmediavault.description`.** The OMV 8 checkbox label.

Open `profiles/openmediavault.description` in a text editor, paste the indicated contents and save it at that path.

Open the file in `nano`, expand its **entire source listing below**, paste all its lines, Save the document after reviewing the pasted contents. The source is **not executed** while you edit it.

**2. Create `profiles/openmediavault.extra`.** Stages the OMV installer-side module onto the ISO.

Open `profiles/openmediavault.extra` in a text editor, paste the indicated contents and save it at that path.

Open the file in `nano`, expand its **entire source listing below**, paste all its lines, Save the document after reviewing the pasted contents. The source is **not executed** while you edit it.

**3. Create `profiles/openmediavault.postinst`.** Verifies completion; it must be executable and must not reinstall OMV.

Open `profiles/openmediavault.postinst` in a text editor, paste the indicated contents and save it at that path.

Open the file in `nano`, expand its **entire source listing below**, paste all its lines, Save the document after reviewing the pasted contents. The source is **not executed** while you edit it.

**4. Create `installer/profile-omv.sh`.** Full code for prerequisites, official OMV key/source, APT approval, admin SSH, OMV update database and Salt deployment.

Open `installer/profile-omv.sh` in a text editor, paste the indicated contents and save it at that path.

Open the file in `nano`, expand its **entire source listing below**, paste all its lines, Save the document after reviewing the pasted contents. The source is **not executed** while you edit it.


The postinst is a marker verifier and needs execute permission:

~~~sh
chmod +x profiles/openmediavault.postinst
~~~

Do **not** mark the imported OMV module as a standalone installer and execute it on the build machine.

## Step 3 — Understand what the complete function implements

1. Install reviewed HTTPS/signing and SSH/sudo prerequisites **inside `/target`**. Ensure target DNS can resolve the OMV package server; the installer's own network is not proof.
2. Download the official OMV signing key, check that GnuPG can parse it and place it into the target keyring; create signed `synchrony` sources for OMV **8**. **Current limitation:** the code verifies a fingerprint is present but does **not** pin a known expected fingerprint.
3. Simulate the whole `openmediavault` package installation, reject essential-package removals and require native **default-No** approval. Install only after consent, then require an **8.x** installed version.
4. Read the administrator username from the installer instead of hardcoding it. Add `sudo` and OMV's `_ssh` group; deny **root SSH** while preserving local emergency recovery.
5. Before first boot **there is no running OMV web UI**. The installer module therefore uses an **inline Python block within the shell module** to read/modify two OMV confdb records, with structural checks: `unattendedupgrade=false` and the one `apt` notification event disabled. It installs **no external Python helper** to be run by the administrator.
6. The module deploys only OMV's relevant `apt` and `apticron` Salt states, checks for unwanted scheduled jobs, and disables Debian's independent periodic updates. It verifies target DNS and package health before completion.
7. The **ordinary post-install OMV guide remains manual**, since the web interface exists then.

**Do not simplify this to a blanket `curl | sh` inside Debian Installer.** The controlled repository and target APT review exist for a reason.

## Step 4 — Verify source and build

~~~sh
sh -n installer/profile-omv.sh
~~~

This parses the handler's POSIX shell syntax without installing anything.

~~~sh
sh -n profiles/openmediavault.postinst
~~~

This checks the post-install verifier's syntax. For byte-for-byte checking, `git hash-object <path>` prints a Git blob SHA; compare it with the SHA printed in the complete file heading below.

Once the entire shared framework is assembled, run `./build.sh`. Boot a **disposable VM** and test selected/unselected, official package origin, declined approval, target DNS failure, OMV 8 version, admin SSH, confdb validation, Salt deployment and first boot. **None of these runtime tests are claimed as passed.**

## Exact source files

Expand each file to obtain the full contents you must save; earlier descriptive snippets were incomplete.
<details>
<summary><strong>profiles/openmediavault.description</strong> — complete file (1 lines; Git blob <code>61fef6231366beb1447da3ea81d0648548d02ddf</code>)</summary>

````text
OpenMediaVault 8 NAS installation; management services available after first boot
````

</details>

<details>
<summary><strong>profiles/openmediavault.extra</strong> — complete file (2 lines; Git blob <code>181ac69fc9ceaa5a7dfbe368b6f4a502ff22f7cf</code>)</summary>

````text
# openmediavault: source assets copied by Simple-CDD (not automatically installed).
installer/profile-omv.sh
````

</details>

<details>
<summary><strong>profiles/openmediavault.postinst</strong> — complete file (11 lines; Git blob <code>4db0e01874e0b99b8b910a8919a52d8acb3d6f72</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer late command, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/openmediavault"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'openmediavault'
    exit 1
fi
````

</details>

<details>
<summary><strong>installer/profile-omv.sh</strong> — complete file (129 lines; Git blob <code>3887f60260657ad8f34f7e2565b2a91a5b60da8d</code>)</summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.
# OMV is independent of Docker. Do not install OMV-Extras/Compose or suppress
# OMV service startup; the user can add optional plugins through the OMV GUI.

profile_omv() {
    # OMV warns that the resolver must work BEFORE package installation.
    review_install 'OMV prerequisites: resolver, SSH/sudo access and signing tools' systemd-resolved psmisc gnupg ca-certificates curl openssh-server sudo
    capture in-target getent ahostsv4 packages.openmediavault.io ||
        fatal 'Target DNS unavailable; stop rather than invent network configuration'
    capture in-target curl -fsSL --proto '=https' \
        -o /tmp/my-cdd-omv-key https://packages.openmediavault.io/archive.key ||
        fatal 'Official OMV signing key download failed'
    capture in-target gpg --show-keys --with-colons /tmp/my-cdd-omv-key ||
        fatal 'Vendor OMV signing key malformed'
    grep '^fpr:' "$WORK/output" >/dev/null ||
        fatal 'Vendor OMV key contained no fingerprint'
    run_target gpg --batch --yes --dearmor -o \
        /usr/share/keyrings/openmediavault-archive-keyring.gpg /tmp/my-cdd-omv-key
    rm -f /target/tmp/my-cdd-omv-key
    mkdir -p /target/etc/apt/sources.list.d
    cat > /target/etc/apt/sources.list.d/openmediavault.list <<'EOT'
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.org/public/ synchrony main
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.io/ synchrony main
EOT
    update_signed_apt
    capture in-target apt-cache policy openmediavault ||
        fatal 'Cannot inspect official OMV package origin'
    grep -F 'synchrony/main' "$WORK/output" >/dev/null ||
        fatal 'Signed official OMV 8 package repository unavailable'
    review_install 'OMV 8 package and dependencies' openmediavault
    capture in-target dpkg-query -W -f='${Version}\n' openmediavault ||
        fatal 'Cannot check installed OMV version'
    grep -E '^8\.' "$WORK/output" >/dev/null ||
        fatal 'Installed OMV is not version 8'

    # Native Debian Installer account: never hardcode a username.
    db_get passwd/username || fatal 'Missing Debian Installer username'
    admin=$RET
    case "$admin" in ''|*[!a-zA-Z0-9_.-]*) fatal 'Unexpected admin account name';; esac
    capture in-target id "$admin" || fatal 'Admin account unavailable'
    capture in-target getent group _ssh || fatal 'OMV _ssh access group unavailable'
    run_target usermod -aG sudo,_ssh "$admin"
    mkdir -p /target/etc/ssh/sshd_config.d
    printf 'PermitRootLogin no\n' > /target/etc/ssh/sshd_config.d/01-my-cdd-root-login.conf
    capture in-target sshd -T || fatal 'OMV SSH config invalid'
    grep -Fx 'permitrootlogin no' "$WORK/output" >/dev/null ||
        fatal 'OMV root SSH still enabled'

    # OMV 8 source controls scheduled updates through conf.system.apt.updates
    # and the "apt" notification record, deploying apt + apticron (not the
    # obsolete cronapt Salt state). Do not edit OMV-generated cron files.
    # No OMV service is stopped, masked or disabled by this setting.
    capture in-target python3 -c '
import json
import subprocess

def read(model):
    result = subprocess.run(
        ["omv-confdbadm", "read", model],
        check=True, capture_output=True, text=True)
    return json.loads(result.stdout)

def update(model, data):
    subprocess.run(
        ["omv-confdbadm", "update", model, json.dumps(data)],
        check=True, capture_output=True, text=True)

settings = read("conf.system.apt.updates")
if not isinstance(settings, dict) or not isinstance(settings.get("unattendedupgrade"), bool):
    raise RuntimeError("Unexpected OMV 8 APT update settings")
settings["unattendedupgrade"] = False
update("conf.system.apt.updates", settings)

notifications = read("conf.system.notification.notification")
if not isinstance(notifications, list):
    raise RuntimeError("Unexpected OMV 8 notification list")
apt_notifications = [n for n in notifications if isinstance(n, dict) and n.get("id") == "apt"]
if len(apt_notifications) != 1:
    raise RuntimeError("Missing or ambiguous OMV 8 APT notification")
apt_notification = apt_notifications[0]
apt_notification["enable"] = False
update("conf.system.notification.notification", apt_notification)

if read("conf.system.apt.updates").get("unattendedupgrade") is not False:
    raise RuntimeError("OMV unattended updates remain enabled")
remaining = read("conf.system.notification.notification")
if len([n for n in remaining if n.get("id") == "apt" and n.get("enable") is False]) != 1:
    raise RuntimeError("OMV APT update notifications remain enabled")
' || fatal 'Could not disable OMV 8 scheduled updates through its configuration database'
    # Refresh OMV Salt grains, modules and pillar before targeted update-state
    # deployment. Do NOT run 'stage run all': it redeploys unrelated services.
    run_target omv-salt stage run prepare
    run_target omv-salt deploy run apt apticron

    # OMV 8 apticron state removes generated daily/weekly notification jobs
    # when the APT notification setting is disabled. Check the effective
    # outcome; never hand-edit Salt-managed cron configuration files.
    for schedule in daily weekly; do
        [ ! -e "/target/etc/cron.$schedule/openmediavault-apticron" ] ||
            fatal "OMV apticron $schedule update notification schedule remains active"
    done

    # Block Debian periodic list refreshes and unattended upgrades for this
    # explicitly selected OMV system; manual apt operations are unaffected.
    mkdir -p /target/etc/apt/apt.conf.d
    printf 'APT::Periodic::Update-Package-Lists "0";\nAPT::Periodic::Unattended-Upgrade "0";\n' > \
        /target/etc/apt/apt.conf.d/99-my-cdd-manual-updates
    capture in-target apt-config dump ||
        fatal 'Cannot validate OMV and Debian scheduled APT update policy'
    grep -Fx 'APT::Periodic::Update-Package-Lists "0";' "$WORK/output" >/dev/null ||
        fatal 'Periodic APT package-list updates were not disabled'
    grep -Fx 'APT::Periodic::Unattended-Upgrade "0";' "$WORK/output" >/dev/null ||
        fatal 'Unattended APT upgrades were not disabled'

    # Legacy cron-apt may exist on upgraded systems; do not mistake it for
    # OMV 8 apticron. Fail closed if an active legacy schedule would remain.
    if [ -f /target/etc/cron.d/cron-apt ]; then
        if grep -Ev '^[[:space:]]*(#|$)' /target/etc/cron.d/cron-apt | grep -q .; then
            fatal 'A legacy cron-apt job remains active; scheduled updates not fully disabled'
        fi
    fi
    capture in-target getent ahostsv4 packages.openmediavault.io ||
        fatal 'OMV installation disrupted target DNS; manual repair required'
    ensure_manual_updates
    run_target dpkg --audit
    log 'OMV 8 installed with unattended upgrades and scheduled APT notifications off; no NAS shares or plugins configured'
}

````

</details>
