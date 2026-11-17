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
| `installer/profile-omv.sh` | Official OMV 8 installation scope: single official signed APT source, reviewed installation and two upstream initialization commands. |

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

**3. Create `installer/profile-omv.sh`.** Official OMV 8 installation scope: single official signed APT source, reviewed installation and two upstream initialization commands.

Open `installer/profile-omv.sh` in a text editor, paste the indicated contents and save it at that path.

Use the matching complete listing below and save it at this path; editing does not execute installer code.




Do **not** mark the imported OMV module as a standalone installer and execute it on the build machine.

Only the native Debian Installer `11my-cdd` runner executes these selected-profile functions; `15my-cdd-status` verifies one overall completion state. Simple-CDD's own stage 14 is left unchanged.

## Step 3 — Understand the limited installer scope

The OMV handler runs **only when selected**. It uses the same signed-APT installation pattern as the [Docker profile](08_docker.md), while restricting OMV-specific actions to its official installation and initialization. The repository entry comes from [OMV's manual Debian installation guide](https://docs.openmediavault.org/en/8.x/installation/on_debian.html):

1. Confirm Debian Trixie, supported architecture and no installed desktop display manager.
2. Install the signing/download tools with reviewed APT approval, retrieve the official public key, set its keyring to mode `0644` so APT's `_apt` signature verifier can read it despite the installer's private umask, and configure the first signed APT repository listed in [OMV's manual Debian installation guide](https://docs.openmediavault.org/en/8.x/installation/on_debian.html), without extra suites.
3. Refresh signed APT metadata, show the entire `openmediavault` transaction (including proposed package removals) and require **default-No approval** before installation. The profile does not impose its own package-removal blacklist. The official script's permissive downgrade/held-package flags remain omitted; APT's ordinary dependency and confirmation semantics apply.
4. Check that OMV 8 was installed and run the two official initialization commands: `omv-confdbadm populate` and `omv-salt deploy run hosts`.

**Not allowed in the OMV CDD profile:** SSH configuration, user/group changes, automatic-update or notification policy, extra services, OMV-Extras, Docker, plugins or NAS configuration. OMV's own package maintainer scripts may modify services as part of normal installation; the CDD adds no further policy. OMV's manual guide additionally warns that `systemd-resolved` and DNS must be configured before installation; verify this independently rather than silently changing network policy in the OMV handler.

## Step 4 — Verify source and build

~~~sh
sh -n installer/profile-omv.sh
~~~

This parses the handler's POSIX shell syntax without installing anything.


This checks the post-install verifier's syntax. For byte-for-byte checking, `git hash-object <path>` prints a Git blob SHA; compare it with the SHA printed in the complete file heading below.

Once the entire shared framework is assembled, run `./build.sh`. Boot a **disposable VM** and test selected/unselected, APT's signature verification of the single signed source, refused package approval, OMV 8 version, database population, hosts deployment and first-boot reachability. Confirm the OMV module made **no SSH, account, update or notification changes**. **None of these runtime tests are claimed as passed.**

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
<summary><strong>installer/profile-omv.sh</strong> — complete file (56 lines; Git blob <code>9ce6dd3f9373e838b8abf86a996337b99b883347</code>)</summary>

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
    # The installer uses umask 077; APT's _apt user must read this public key.
    run_target chmod 0644 /usr/share/keyrings/openmediavault-archive-keyring.gpg
    rm -f /target/tmp/my-cdd-omv-key

    # Single official signed repository: first entry in OMV 8's
    # manual Debian installation guide. No mirror list or extra suites.
    mkdir -p /target/etc/apt/sources.list.d
    cat > /target/etc/apt/sources.list.d/openmediavault.list <<'EOF'
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] http://packages.openmediavault.org/public/ synchrony main
EOF
    update_signed_apt
    # Preserve full default-No APT approval, but do not accept upstream's
    # unreviewed --allow-downgrades/--allow-change-held-packages flags.
    simulate_target install --no-install-recommends openmediavault
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
