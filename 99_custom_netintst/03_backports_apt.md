# 03 — Recreate the Backports installer profile

**Goal:** build this exact optional feature from its source files, not operate the completed installer. A **normal Debian system** uses [the simpler Backports guide](../03_backports/README.md).

## Before you start

Complete the shared [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md) first. Their scripts are **shared prerequisites** for every feature. Work in `99_custom_netintst/my-cdd/`, using a test branch or scratch copy of the repository.

## Step 1 — Identify the files you need

| Create this path | What it does |
| --- | --- |
| `profiles/backports.description` | The checkbox's plain-language label. |
| `profiles/backports.extra` | Which Backports module and source template must be copied to installer media. |
| `profiles/backports.postinst` | A success-marker verifier only; it must be executable. |
| `installer/profile-backports.sh` | The complete selected-only function: signed source, APT priority, upgrade consent, individual cleanup and audit. |
| `scripts/debian-backports.sources` | The signed Trixie Backports configuration installed in the target only when selected. |

## Step 2 — Create those exact files

From the `my-cdd` directory, first create the folders if absent:

~~~sh
mkdir -p profiles installer scripts
~~~

This creates source directories only; it does **not** install Backports.

**1. Open `profiles/backports.description`.** The checkbox's plain-language label.

Open `profiles/backports.description` in a text editor, paste the indicated contents and save it at that path.

Expand the **matching complete file listing below**, Save the document after reviewing the pasted contents. This editor command does not execute the file.

**2. Open `profiles/backports.extra`.** Which Backports module and source template must be copied to installer media.

Open `profiles/backports.extra` in a text editor, paste the indicated contents and save it at that path.

Expand the **matching complete file listing below**, Save the document after reviewing the pasted contents. This editor command does not execute the file.

**3. Open `profiles/backports.postinst`.** A success-marker verifier only; it must be executable.

Open `profiles/backports.postinst` in a text editor, paste the indicated contents and save it at that path.

Expand the **matching complete file listing below**, Save the document after reviewing the pasted contents. This editor command does not execute the file.

**4. Open `installer/profile-backports.sh`.** The complete selected-only function: signed source, APT priority, upgrade consent, individual cleanup and audit.

Open `installer/profile-backports.sh` in a text editor, paste the indicated contents and save it at that path.

Expand the **matching complete file listing below**, Save the document after reviewing the pasted contents. This editor command does not execute the file.

**5. Open `scripts/debian-backports.sources`.** The signed Trixie Backports configuration installed in the target only when selected.

Open `scripts/debian-backports.sources` in a text editor, paste the indicated contents and save it at that path.

Expand the **matching complete file listing below**, Save the document after reviewing the pasted contents. This editor command does not execute the file.


Make the marker verifier executable:

~~~sh
chmod +x profiles/backports.postinst
~~~

This sets the permission expected by Simple-CDD. `installer/profile-backports.sh` is **sourced** by the dispatcher and should not be run directly.

## Step 3 — Understand how the code works

1. `simple-cdd.conf` offers `backports` as a **user-selected checkbox**; `auto_profiles` remains empty.
2. The `.extra` file places the complete handler and signed source on the ISO. Staging is **not** installing.
3. The dispatcher maps the selected ID `backports` to `profile_backports()` inside `installer/profile-backports.sh`.
4. The function adds the signed source to `/target`, refreshes package indexes and confirms Backports' effective default priority **100**. It rejects an unexpected high-priority override.
5. It runs **APT simulations first**, checks essential-package removals, displays the *complete* plan via native Debconf and asks default-No consent before a real upgrade.
6. Cleanup is reviewed **per named package** before removal. The module finishes with package audits.
7. The dispatcher writes a completion marker **only if the handler succeeds**; `backports.postinst` verifies that marker and does not repeat the installation.

## Step 4 — Check the files, then build

~~~sh
sh -n installer/profile-backports.sh
~~~

This checks the handler's POSIX syntax **without running APT**.

~~~sh
sh -n profiles/backports.postinst
~~~

This checks the verifier's syntax. For every file below, `git hash-object <file>` prints the **Git blob SHA**; compare it with the value in the listing heading to detect omissions or accidental edits. This is read-only.

After all shared files and the other expected Simple-CDD profile inputs are in place, run `./build.sh` from `my-cdd`. **Do not run the handler on your Debian host.** Boot a disposable VM and test unchecked, accepted, declined, unsafe-removal and cleanup-approval cases. An ISO build alone does not prove runtime behavior.

## Complete source — nothing omitted

Each collapsible listing is the **entire original file**, not an excerpt. Paste it into exactly the named path; include its final newline.
<details>
<summary><strong>Complete profiles/backports.description</strong> (1 lines; original blob <code>1be4769ae5b9df6a885e4775200ba431a3ff7e6c</code>)</summary>

````text
Enable Debian Backports (priority 100) with reviewed upgrade and cleanup
````

</details>

<details>
<summary><strong>Complete profiles/backports.extra</strong> (3 lines; original blob <code>2f1be9aab59ffd224af6624024eb70fa28b6b297</code>)</summary>

````text
# backports: source assets copied by Simple-CDD (not automatically installed).
installer/profile-backports.sh
scripts/debian-backports.sources
````

</details>

<details>
<summary><strong>Complete profiles/backports.postinst</strong> (11 lines; original blob <code>0c54457530c5fb5141e35fb3a2d3d8b7d3f41236</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer late command, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/backports"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'backports'
    exit 1
fi
````

</details>

<details>
<summary><strong>Complete installer/profile-backports.sh</strong> (60 lines; original blob <code>511655af80b34ad5fd807024bfee24bacaf7de77</code>)</summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_backports() {
    [ -r "$MEDIA/debian-backports.sources" ] ||
        fatal 'Signed Backports repository template missing'
    [ ! -e /target/etc/apt/preferences.d/90-local-backports.pref ] ||
        fatal 'Unexpected old Backports pin; manual review required'
    mkdir -p /target/etc/apt/sources.list.d
    cp "$MEDIA/debian-backports.sources" /target/etc/apt/sources.list.d/debian-backports.sources
    chmod 644 /target/etc/apt/sources.list.d/debian-backports.sources
    update_signed_apt
    grep -E '^[[:space:]]*100[[:space:]].*trixie-backports' "$WORK/output" >/dev/null ||
        fatal 'Cannot confirm effective Backports priority 100'
    if grep -E '^[[:space:]]*[0-9]+[[:space:]].*trixie-backports' "$WORK/output" |
        grep -Ev '^[[:space:]]*100[[:space:]]' > "$WORK/pin-errors"; then
        cat "$WORK/pin-errors" >> "$LOG"
        fatal 'Backports repository has an unexpected effective priority'
    fi
    reviewed_upgrade
    simulate_target autoremove --purge
    check_critical_removals
    if grep -E '^Remv |^Purg ' "$WORK/plan" >/dev/null; then
        show_note 'Backports: review full autoremove/purge simulation' "$WORK/plan" ||
            fatal 'Could not display the complete cleanup plan'
        awk '/^Remv / || /^Purg / {print $2}' "$WORK/plan" |
            sort -u > "$WORK/removal-list"
        [ -s "$WORK/removal-list" ] ||
            fatal 'Cleanup simulation proposed changes but no package names could be identified'
        while IFS= read -r pkg; do
            db_subst my-cdd/approve-removal MYCDD_REMOVAL "$pkg" ||
                fatal "Could not show approval for removal of $pkg"
            yes_no my-cdd/approve-removal ||
                fatal "Individual removal not approved: $pkg"
            log "USER APPROVED REMOVAL: $pkg"
        done < "$WORK/removal-list"
        run_target apt-get -y autoremove --purge
    fi
    capture in-target dpkg -l || fatal 'Cannot list residual dpkg configuration'
    awk '$1=="rc" {print $2}' "$WORK/output" > "$WORK/residual"
    if [ -s "$WORK/residual" ]; then
        {
            echo 'The following exact residual configurations will be purged:'
            cat "$WORK/residual"
        } > "$WORK/residual-review"
        review_plan 'Backports: purge only explicitly reviewed residual configurations' "$WORK/residual-review"
        while IFS= read -r pkg; do
            case "$pkg" in
                ''|*[!a-zA-Z0-9.+:~-]*) fatal "Invalid residual package: $pkg";;
            esac
            run_target dpkg --purge "$pkg"
        done < "$WORK/residual"
    fi
    run_target dpkg --audit
    simulate_target autoremove --purge
    if grep -E '^Remv |^Purg ' "$WORK/plan" >/dev/null; then
        fatal 'Autoremove still proposes changes after approved cleanup'
    fi
}

````

</details>

<details>
<summary><strong>Complete scripts/debian-backports.sources</strong> (8 lines; original blob <code>67f76bdba5cd51c1ba7248a15dde6cc98bb76f3f</code>)</summary>

````text
# Only install into /etc/apt/sources.list.d/ AFTER the Backports
# profile has been explicitly selected and approved. Build-time presence
# of this template MUST NOT enable Backports in the target system.
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
````

</details>
