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
| `installer/profile-omv.sh` | Official OMV 8 installation scope: signed mirror list, reviewed APT and two upstream initialization commands. |

Create source directories if absent:

~~~sh
mkdir -p profiles installer
~~~

This only creates folders.

**1. Create `profiles/openmediavault.description`.** The OMV 8 checkbox label.

Open `profiles/openmediavault.description` in a text editor, paste the indicated contents and save it at that path.

Use the matching complete listing below and save it at this path; editing does not execute installer code.

**2. Create `profiles/openmediavault.extra`.** Stages the OMV installer-side module onto the ISO.

Open `profiles/openmediavault.extra` in a text editor, paste the indicated contents and save it at that path.

Use the matching complete listing below and save it at this path; editing does not execute installer code.

**3. Create `profiles/openmediavault.postinst`.** Verifies completion; it must be executable and must not reinstall OMV.

Open `profiles/openmediavault.postinst` in a text editor, paste the indicated contents and save it at that path.

Use the matching complete listing below and save it at this path; editing does not execute installer code.

**4. Create `installer/profile-omv.sh`.** Official OMV 8 installation scope: signed mirror list, reviewed APT and two upstream initialization commands.

Open `installer/profile-omv.sh` in a text editor, paste the indicated contents and save it at that path.

Use the matching complete listing below and save it at this path; editing does not execute installer code.


The postinst is a marker verifier and needs execute permission:

~~~sh
chmod +x profiles/openmediavault.postinst
~~~

Do **not** mark the imported OMV module as a standalone installer and execute it on the build machine.

## Step 3 — Understand the limited installer scope

The OMV handler runs **only when selected**. It is constrained to actions performed by the official [OMV 8 `install.sh`](https://github.com/openmediavault/openmediavault/blob/master/install.sh):

1. Confirm Debian Trixie, supported architecture and no installed desktop display manager.
2. Install the signing/download tools with reviewed APT approval, retrieve the official key, and configure upstream's signed `mirror+file` repository with ordered fallback mirrors.
3. Refresh APT, show the entire `openmediavault` transaction and require **default-No approval** before installation. The official script's permissive downgrade/held-package flags are intentionally omitted for safety.
4. Check that OMV 8 was installed and run the two official initialization commands: `omv-confdbadm populate` and `omv-salt deploy run hosts`.

**Not allowed in the OMV CDD profile:** SSH configuration, user/group changes, automatic-update or notification policy, extra services, OMV-Extras, Docker, plugins or NAS configuration. OMV's own package maintainer scripts may modify services as part of normal installation; the CDD adds no further policy.

## Step 4 — Verify source and build

~~~sh
sh -n installer/profile-omv.sh
~~~

This parses the handler's POSIX shell syntax without installing anything.

~~~sh
sh -n profiles/openmediavault.postinst
~~~

This checks the post-install verifier's syntax. For byte-for-byte checking, `git hash-object <path>` prints a Git blob SHA; compare it with the SHA printed in the complete file heading below.

Once the entire shared framework is assembled, run `./build.sh`. Boot a **disposable VM** and test selected/unselected, the official signed mirror configuration, refused package approval, OMV 8 version, database population, hosts deployment and first-boot reachability. Confirm the OMV module made **no SSH, account, update or notification changes**. **None of these runtime tests are claimed as passed.**

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
<summary><strong>installer/profile-omv.sh</strong> — complete file (66 lines; Git blob <code>321dae7f837b7b9563bc4aa201411a0aee745de5</code>)</summary>

````sh
#!/bin/sh
# Sourced only when the OMV profile was explicitly selected.
# Match the official OMV 8 installer's scope. Do not change SSH, account
# groups, update schedules, notifications, plugins or other OMV policies.

profile_omv() {
    # The official installer accepts Debian Trixie on amd64/arm64 only.
    capture in-target sh -c '. /etc/os-release; [ "$VERSION_CODENAME" = trixie ]' ||
        fatal 'OMV 8 requires Debian Trixie'
    capture in-target dpkg --print-architecture ||
        fatal 'Cannot verify OMV target architecture'
    case "$(cat "$WORK/output")" in amd64|arm64) : ;;
        *) fatal 'OMV 8 target architecture unsupported' ;;
    esac
    # Like the official installer, reject an installed display manager.
    capture in-target dpkg -l || fatal 'Cannot inspect target packages'
    if awk '$1 == "ii" && $2 ~ /^(gdm3|lightdm|lxdm|sddm|slim|wdm|xdm)$/ { found=1 } END { exit !found }' "$WORK/output"; then
        fatal 'OMV 8 official installer rejects desktop display managers'
    fi

    review_install 'OMV signing and download tools' gnupg wget
    capture in-target wget -q -O /tmp/my-cdd-omv-key https://packages.openmediavault.io/archive.key ||
        fatal 'Official OMV signing key download failed'
    capture in-target gpg --show-keys --with-colons /tmp/my-cdd-omv-key ||
        fatal 'Official OMV signing key is unreadable'
    grep '^fpr:' "$WORK/output" >/dev/null ||
        fatal 'Official OMV signing key has no fingerprint'
    run_target gpg --batch --yes --dearmor -o \
        /usr/share/keyrings/openmediavault-archive-keyring.gpg /tmp/my-cdd-omv-key
    rm -f /target/tmp/my-cdd-omv-key

    # Mirror priorities and the signed sources match upstream install.sh.
    mkdir -p /target/etc/apt/mirrors /target/etc/apt/sources.list.d
    cat > /target/etc/apt/mirrors/openmediavault.txt <<'EOF'
https://packages.openmediavault.org/public/ priority:1
https://packages.openmediavault.io/ priority:2
https://openmediavault.github.io/packages/ priority:3
https://downloads.sourceforge.net/project/openmediavault/packages/ priority:4
EOF
    cat > /target/etc/apt/sources.list.d/openmediavault.list <<'EOF'
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] mirror+file:/etc/apt/mirrors/openmediavault.txt synchrony main
## Uncomment the following line to add software from the proposed repository.
# deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] mirror+file:/etc/apt/mirrors/openmediavault.txt synchrony-proposed main
## This software is not part of OpenMediaVault, but is offered by third-party
## developers as a service to OpenMediaVault users.
# deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] mirror+file:/etc/apt/mirrors/openmediavault.txt synchrony partner
EOF
    run_target apt-get update

    # Preserve full default-No APT approval, but do not accept upstream's
    # unreviewed --allow-downgrades/--allow-change-held-packages flags.
    simulate_target install --no-install-recommends openmediavault
    check_critical_removals
    review_plan 'Official OpenMediaVault 8 package and dependencies' "$WORK/plan"
    run_target apt-get -y install --no-install-recommends openmediavault
    run_target dpkg --audit
    capture in-target dpkg-query -W '-f=${Version}\n' openmediavault ||
        fatal 'Cannot read installed OMV version'
    grep -Eq '^8\.' "$WORK/output" ||
        fatal 'Installed OMV package is not version 8'

    # Exactly the two post-install initialization operations in upstream.
    run_target omv-confdbadm populate
    run_target omv-salt deploy run hosts
    log 'OMV 8 installed and initialized; no custom SSH, update, notification or plugin changes'
}
````

</details>
