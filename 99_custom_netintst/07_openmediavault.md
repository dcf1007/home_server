# 07 — Recreate OpenMediaVault 8 installer support

**Outcome:** build the full **optional OMV 8 profile source** for the custom Debian netinst image, not a script someone must run manually after installation. On a running Debian server, follow [07 — Manual OMV setup](../07_openmediavault/README.md); that guide uses the OMV GUI and requires **no external project Python helper**.

## Step 1 — Prepare the shared installer code

Complete [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md), then work inside `99_custom_netintst/my-cdd/` on a test branch or scratch copy.

The optional profile ID is `openmediavault`. Its installer handler is `installer/openmediavault.sh`, which defines `profile_omv()` and runs **only when selected**. OMV packages are installed during Debian Installer, but the two upstream initialization commands are now run once by a dedicated systemd service on the installed system's first boot.

## Step 2 — Create these complete files

| Source path | Responsibility |
| --- | --- |
| `profiles/openmediavault.description` | The OMV 8 checkbox label. |
| `profiles/openmediavault.extra` | Stages the OMV installer handler and first-boot assets on the ISO. |
| `profiles/openmediavault.postinst` | Verifies the successful package installation and first-boot scheduling marker, not post-boot initialization. |
| `installer/openmediavault.sh` | Reviewed package installation and registration of the one-time first-boot job. |
| `installer/openmediavault-firstboot.sh` | Runs the same upstream commands once after boot, logs the result and removes the temporary service and itself. |
| `installer/openmediavault-firstboot.service` | Native systemd oneshot unit, enabled only when OMV is selected. |

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

**3. Create `installer/openmediavault.sh`.** Reviewed OMV package installation and first-boot job registration.

Open `installer/openmediavault.sh` in a text editor, paste the indicated contents and save it at that path.

Use the matching complete listing below and save it at this path; editing does not execute installer code.




**4. Create `installer/openmediavault-firstboot.sh` and `installer/openmediavault-firstboot.service`.** Copy their **complete** source listings below. The handler stages these files only when OMV is approved, and enables the unit without starting it in Debian Installer. The first-boot script must be executable in the installed target (the handler sets mode 0755).

Do **not** mark the imported OMV handler as a standalone installer or execute any of these files on the build machine.

Native Debian Installer stage `11my-cdd` runs each approved selected handler **once**, then writes that profile's success marker. Unmodified Simple-CDD stage `14simple-cdd` executes the selected profile's verification-only `.postinst` **in-target**. Stage `15my-cdd-status` independently checks all approved markers and overall `COMPLETE`, returning native exit 10 rather than falsely reporting success.

## Step 3 — Understand the limited installer scope

The OMV handler runs **only when selected**. It uses the same signed-APT installation pattern as the [Docker profile](08_docker.md), while restricting OMV-specific actions to its official installation and initialization. The repository entry comes from [OMV's manual Debian installation guide](https://docs.openmediavault.org/en/8.x/installation/on_debian.html):

1. Confirm Debian Trixie, supported architecture and no installed desktop display manager.
2. Install the signing/download tools with reviewed APT approval, retrieve the official public key, set its keyring to mode `0644` so APT's `_apt` signature verifier can read it despite the installer's private umask, and configure the first signed APT repository listed in [OMV's manual Debian installation guide](https://docs.openmediavault.org/en/8.x/installation/on_debian.html), without extra suites.
3. Refresh signed APT metadata, show the entire `openmediavault` transaction (including proposed package removals) and require **default-No approval** before installation. The profile does not impose its own package-removal blacklist. The official script's permissive downgrade/held-package flags remain omitted; APT's ordinary dependency and confirmation semantics apply.
4. Check that OMV 8 packages installed and passed `dpkg --audit`, then stage the two official commands in a **one-time** systemd service instead of executing them in the unfinished installer target.
5. On first boot, run `omv-confdbadm populate` followed by `omv-salt deploy run hosts` in the running systemd/D-Bus environment. Write the one retained log (`/var/log/installer/my-cdd-omv-firstboot.log`) **before** executing either command; it serves as the attempted-run record and keeps command outputs and final result. On success **or failure**, disable and remove the temporary systemd unit, enablement symlink and runner script, then reload systemd. No permanent status file, attempt marker or login notice is created. Console/journal show first-boot progress and errors. If interrupted before cleanup, a later invocation cleans up only, without retrying either OMV command.

**Not allowed in the OMV CDD profile:** SSH configuration, user/group changes, automatic-update policy, unrelated services, OMV-Extras, Docker, plugins or NAS configuration. The sole new service is the explicitly approved, one-time OMV initialization job which removes itself after the first attempt, retaining only the log. OMV's own package maintainer scripts may modify services as part of normal installation; the CDD adds no further policy. OMV's manual guide additionally warns that `systemd-resolved` and DNS must be configured before installation; verify this independently rather than silently changing network policy in the OMV handler.

## Step 4 — Verify source and build

~~~sh
sh -n installer/openmediavault.sh
~~~

This parses the installer handler's POSIX shell syntax without installing anything.

~~~sh
sh -n installer/openmediavault-firstboot.sh
~~~

This checks the separate first-boot runner's syntax without executing either OMV command.


This checks the selected handler's syntax. For byte-for-byte checking, `git hash-object <path>` prints a Git blob SHA; compare it with the SHA printed in the complete file heading below.

Once the entire shared framework is assembled, run `./build.sh`. Boot a **disposable VM** and test selected/unselected, APT signature verification, refusal of the package plan, OMV 8 version, registration of the unit **without** executing `populate` in the installer, and first-boot database population/hosts deployment. Deliberately fail each command in isolation, check that `FAILED` identifies the failing command and exit code, verify console/journal output and retained log, inspect removal of the unit/symlink/runner, and reboot to confirm there is **no automatic retry**. Confirm the OMV module made **no SSH, account, update or notification changes**. **Six isolated shell mock tests passed: success, failure of either command, interruption recovery, cleanup recovery, and a disable-command failure. An end-to-end ISO/VM first-boot test has not been performed for this self-cleaning revision.**

## Exact source files

Expand each file to obtain the full contents you must save; earlier descriptive snippets were incomplete.
<details>
<summary><strong>profiles/openmediavault.description</strong> — complete file (1 lines; Git blob <code>61fef6231366beb1447da3ea81d0648548d02ddf</code>)</summary>

````text
OpenMediaVault 8 NAS installation; management services available after first boot
````

</details>

<details>
<summary><strong>profiles/openmediavault.extra</strong> — complete file (4 lines; Git blob <code>a6f6018246692fbda9631f3f2acca790ecfddc31</code>)</summary>

````text
# openmediavault: source assets copied by Simple-CDD (not automatically installed).
installer/openmediavault.sh
installer/openmediavault-firstboot.sh
installer/openmediavault-firstboot.service
````

</details>



<details>
<summary><strong>installer/openmediavault.sh</strong> — complete file (99 lines; Git blob <code>bc0ee4df4aaff054b2c1e26f4af8d663c5a3f64f</code>)</summary>

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
    progress_status 'Downloading and verifying OMV repository signing key'
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

    # OMV's upstream initialization requires a running systemd/D-Bus.
    # Stage it for the first boot; do not execute it in Debian Installer.
    [ -r "$MEDIA/openmediavault-firstboot.sh" ] ||
        fatal 'OMV first-boot script missing from installer media'
    [ -r "$MEDIA/openmediavault-firstboot.service" ] ||
        fatal 'OMV first-boot service missing from installer media'

    mkdir -p /target/usr/local/sbin /target/etc/systemd/system ||
        fatal 'Cannot create OMV first-boot directories'

    cp "$MEDIA/openmediavault-firstboot.sh" \
        /target/usr/local/sbin/my-cdd-omv-firstboot.sh ||
        fatal 'Cannot install OMV first-boot script'
    chmod 0755 /target/usr/local/sbin/my-cdd-omv-firstboot.sh ||
        fatal 'Cannot make OMV first-boot script executable'

    cp "$MEDIA/openmediavault-firstboot.service" \
        /target/etc/systemd/system/my-cdd-omv-firstboot.service ||
        fatal 'Cannot install OMV first-boot service'
    chmod 0644 \
        /target/etc/systemd/system/my-cdd-omv-firstboot.service ||
        fatal 'Cannot set OMV service file permissions'

    # Only enable here: no OMV initialization in the installer chroot.
    # The one-time service deletes its own files after the first attempt;
    # only /var/log/installer/my-cdd-omv-firstboot.log remains.
    run_target systemctl enable my-cdd-omv-firstboot.service

    cat > "$WORK/omv-firstboot-info" <<'EOT'
OpenMediaVault 8 packages were installed successfully.

Final initialization runs automatically on first boot:
  1. omv-confdbadm populate
  2. omv-salt deploy run hosts

Progress, the result and any errors appear on the boot console and
in /var/log/installer/my-cdd-omv-firstboot.log.

After success or failure, the temporary service and script remove
themselves. No automatic retry occurs. The log is retained.
EOT
    show_note 'OpenMediaVault first-boot initialization' \
        "$WORK/omv-firstboot-info" ||
        log 'Could not display OMV first-boot note; installer log remains'

    log 'OMV 8 packages installed; one-time first-boot initialization scheduled'
}
````

</details>

<details>
<summary><strong>installer/openmediavault-firstboot.sh</strong> — complete file (97 lines; Git blob <code>56d7ed069e2380785fc126dd2e4c42e9ff420edc</code>)</summary>

````sh
#!/bin/sh
# Official OMV initialization on the first real systemd boot, then self-delete.
# Only the root-readable log is retained; never retry the OMV commands.
set -eu
umask 077

SERVICE=my-cdd-omv-firstboot.service
UNIT=/etc/systemd/system/my-cdd-omv-firstboot.service
LINK=/etc/systemd/system/multi-user.target.wants/my-cdd-omv-firstboot.service
SCRIPT=/usr/local/sbin/my-cdd-omv-firstboot.sh
LOG=/var/log/installer/my-cdd-omv-firstboot.log
step='preparing first-boot initialization'

mkdir -p /var/log/installer

cleanup() {
    cleanup_rc=0
    # Do not stop the running service: disable, never disable --now.
    if ! systemctl disable "$SERVICE" >> "$LOG" 2>&1; then
        printf '%s\n' 'WARNING: systemctl disable failed; removing the link directly' >> "$LOG" || :
    fi
    for file in "$LINK" "$UNIT" "$SCRIPT"; do
        if ! rm -f -- "$file" >> "$LOG" 2>&1; then
            printf 'CLEANUP FAILED: %s\n' "$file" >> "$LOG" || :
            cleanup_rc=1
        fi
    done
    if ! systemctl daemon-reload >> "$LOG" 2>&1; then
        printf '%s\n' 'CLEANUP FAILED: systemctl daemon-reload' >> "$LOG" || :
        cleanup_rc=1
    fi
    return "$cleanup_rc"
}

finish() {
    rc=$1
    trap - 0 HUP INT TERM
    if [ "$rc" -eq 0 ]; then
        printf '%s\n' 'RESULT: COMPLETE (both OMV commands succeeded)' >> "$LOG" || :
        printf '%s\n' 'OpenMediaVault first-boot initialization completed successfully.'
    else
        printf 'RESULT: FAILED; command=%s; exit_status=%s\n' \
            "$step" "$rc" >> "$LOG" || :
        printf >&2 'OpenMediaVault initialization FAILED: %s (exit %s).\n' "$step" "$rc" || :
        printf >&2 'Details: %s\n' "$LOG" || :
    fi

    # Perform the same cleanup on success and failure.
    # Keep the log so the reason for failure survives self-removal.
    if ! cleanup; then
        printf >&2 'OMV first-boot cleanup FAILED; see %s\n' "$LOG" || :
        [ "$rc" -ne 0 ] || rc=1
    fi
    exit "$rc"
}

# If a previous attempt was interrupted before cleanup, leave its log
# intact and clean up ONLY. Never rerun either OMV command.
if [ -e "$LOG" ]; then
    if grep -q '^RESULT: ' "$LOG"; then
        printf '%s\n' 'RECOVERY: removing leftover one-time service files; OMV commands not rerun.' >> "$LOG" || :
    else
        printf '%s\n' 'RESULT: INTERRUPTED; previous attempt did not finish; OMV commands not rerun.' >> "$LOG" || :
    fi
    printf 'Prior OMV attempt detected. Cleaning up without rerunning. Log: %s\n' "$LOG"
    cleanup
    exit $?
fi

# The log is the sole durable attempt record; create it before any OMV command.
# noclobber makes creation exclusive even if called outside systemd.
if ! (set -C; : > "$LOG") 2>/dev/null; then
    printf >&2 'Cannot create OMV attempt log: %s\n' "$LOG"
    exit 1
fi
printf '%s\n' 'STARTED: one-time OMV first-boot initialization' >> "$LOG"
# Flush the attempt record before making changes to minimize reboot replay risk.
sync "$LOG" || :

trap 'finish "$?"' 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

run_step() {
    step=$1
    shift
    printf 'RUNNING: %s\n' "$step" >> "$LOG"
    printf 'RUNNING: %s\n' "$step"
    "$@" >> "$LOG" 2>&1
    printf 'COMPLETED: %s\n' "$step" >> "$LOG"
    printf 'COMPLETED: %s\n' "$step"
}

# Exactly the two upstream install.sh initialization commands, unchanged.
run_step 'omv-confdbadm populate' omv-confdbadm populate
run_step 'omv-salt deploy run hosts' omv-salt deploy run hosts
````

</details>

<details>
<summary><strong>installer/openmediavault-firstboot.service</strong> — complete file (15 lines; Git blob <code>e07349bfdb12c16e7497505ebbbc45dcfd27a305</code>)</summary>

````ini
[Unit]
Description=Self-cleaning one-time OpenMediaVault first-boot initialization
Documentation=https://docs.openmediavault.org/en/8.x/installation/on_debian.html
Wants=dbus.socket
After=dbus.socket network.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/my-cdd-omv-firstboot.sh
StandardOutput=journal+console
StandardError=journal+console
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
````

</details>


## Native Simple-CDD completion verifier

Create `profiles/openmediavault.postinst` from the full source below, alongside its `.description` and `.extra` files. The stage-11 runner writes this record after successful OMV **package installation and first-boot service registration**. Original `14simple-cdd` checks that record; it does not claim that post-boot initialization is already `COMPLETE`.

~~~sh
chmod +x profiles/openmediavault.postinst
sh -n profiles/openmediavault.postinst
~~~

The syntax check is read-only. The final `15my-cdd-status` guard also checks this selected profile's record, returning exit 10 if any required record is missing.

<details>
<summary><strong>profiles/openmediavault.postinst</strong> — complete native verifier (11 lines; Git blob <code>56de86b591b15ce71f0a1ccd63f0a2522633d36d</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer stage-11 runner, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/openmediavault"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'openmediavault'
    exit 1
fi
````

</details>
