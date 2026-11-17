# 03 — Recreate the Backports installer profile

**Goal:** build this exact optional feature from its source files, not operate the completed installer. A **normal Debian system** uses [the simpler Backports guide](../03_backports/README.md).

## Before you start

Complete the shared [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md) first. Their scripts are **shared prerequisites** for every feature. Work in `99_custom_netintst/my-cdd/`, using a test branch or scratch copy of the repository.

## Step 1 — Identify the files you need

| Create this path | What it does |
| --- | --- |
| `profiles/backports.description` | The checkbox's plain-language label. |
| `profiles/backports.extra` | Which Backports module and source template must be copied to installer media. |
| `profiles/backports.postinst` | Native Simple-CDD completion verifier; checks a marker without rerunning feature installation. |
| `installer/backports.sh` | The complete selected-only function: signed source, reviewed upgrade, individual cleanup consent and audit. |
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

**3. Open `installer/backports.sh`.** The complete selected-only function: signed source, reviewed upgrade, individual cleanup consent and audit.

Open `installer/backports.sh` in a text editor, paste the indicated contents and save it at that path.

Expand the **matching complete file listing below**, Save the document after reviewing the pasted contents. This editor command does not execute the file.

**4. Open `scripts/debian-backports.sources`.** The signed Trixie Backports configuration installed in the target only when selected.

Open `scripts/debian-backports.sources` in a text editor, paste the indicated contents and save it at that path.

Expand the **matching complete file listing below**, Save the document after reviewing the pasted contents. This editor command does not execute the file.




This sets the permission expected by Simple-CDD. `installer/backports.sh` is **sourced** by the dispatcher and should not be run directly.

Native Debian Installer stage `11my-cdd` runs each approved selected handler **once**, then writes that profile's success marker. Unmodified Simple-CDD stage `14simple-cdd` executes the selected profile's verification-only `.postinst` **in-target**. Stage `15my-cdd-status` independently checks all approved markers and overall `COMPLETE`, returning native exit 10 rather than falsely reporting success.

## Step 3 — Understand how the code works

1. `simple-cdd.conf` offers `backports` as a **user-selected checkbox**; `auto_profiles` remains empty.
2. The `.extra` file places the complete handler and signed source on the ISO. Staging is **not** installing.
3. The dispatcher maps the selected ID `backports` to `profile_backports()` inside `installer/backports.sh`.
4. The function adds the signed source to `/target` and refreshes package indexes. Debian APT applies repository priorities and resolves dependencies; the profile does not create its own priority-refusal policy.
5. It performs its own full-upgrade simulation and obtains default-No native Debconf approval directly in `profile_backports()`. The complete plan, including any removals, is reviewed by the user; the profile adds no package blacklist.
6. Cleanup is reviewed **per named package** before removal. The module finishes with package audits.

## Step 4 — Check the files, then build

~~~sh
sh -n installer/backports.sh
~~~

This checks the handler's POSIX syntax **without running APT**.


This checks the selected handler's syntax. For every file below, `git hash-object <file>` prints the **Git blob SHA**; compare it with the value in the listing heading to detect omissions or accidental edits. This is read-only.

After all shared files and the other expected Simple-CDD profile inputs are in place, run `./build.sh` from `my-cdd`. **Do not run the handler on your Debian host.** Boot a disposable VM and test unchecked, accepted, declined, full APT removal-plan review and cleanup-approval cases. An ISO build alone does not prove runtime behavior.

## Complete source — nothing omitted

Each collapsible listing is the **entire original file**, not an excerpt. Paste it into exactly the named path; include its final newline.
<details>
<summary><strong>Complete profiles/backports.description</strong> (1 lines; original blob <code>1be4769ae5b9df6a885e4775200ba431a3ff7e6c</code>)</summary>

````text
Enable Debian Backports (priority 100) with reviewed upgrade and cleanup
````

</details>

<details>
<summary><strong>Complete profiles/backports.extra</strong> (3 lines; original blob <code>088721f50462951be7f6a4a97669f88b84283d35</code>)</summary>

````text
# backports: source assets copied by Simple-CDD (not automatically installed).
installer/backports.sh
scripts/debian-backports.sources
````

</details>



<details>
<summary><strong>Complete installer/backports.sh</strong> (49 lines; original blob <code>f8ac2e847636e5eb367afdde23d5b3283851ffeb</code>)</summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_backports() {
    [ -r "$MEDIA/debian-backports.sources" ] ||
        fatal 'Signed Backports repository template missing'
    mkdir -p /target/etc/apt/sources.list.d
    cp "$MEDIA/debian-backports.sources" /target/etc/apt/sources.list.d/debian-backports.sources
    chmod 644 /target/etc/apt/sources.list.d/debian-backports.sources
    update_signed_apt
    # Review this profile's complete Backports upgrade, then execute it.
    simulate_target dist-upgrade
    review_plan 'Backports: complete eligible-package full-upgrade' "$WORK/plan"
    run_target apt-get -y dist-upgrade
    run_target dpkg --audit
    simulate_target autoremove --purge
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

## Native Simple-CDD completion verifier

Create `profiles/backports.postinst` from the full source below, alongside its `.description` and `.extra` files. The stage-11 runner writes its record after successful handler execution; the original `14simple-cdd` hook runs this verifier in-target without installing the feature twice.

~~~sh
chmod +x profiles/backports.postinst
sh -n profiles/backports.postinst
~~~

The syntax check is read-only. The final `15my-cdd-status` guard also checks this selected profile's record, returning exit 10 if any required record is missing.

<details>
<summary><strong>profiles/backports.postinst</strong> — complete native verifier (11 lines; Git blob <code>bd9f5388acaff6a133665e46de7bfa041779300a</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer stage-11 runner, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/backports"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'backports'
    exit 1
fi
````

</details>
