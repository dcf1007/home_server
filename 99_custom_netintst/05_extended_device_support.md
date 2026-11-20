# 05 — Recreate extended firmware and microcode support

**Current lifecycle — 2026-11-20:** Native stages 10, 50, 55 and 60 run before the selected-profile executor at `61my-cdd`; the unmodified Simple-CDD verifier, custom status guard, unmodified CD-ROM eject and unmodified final message follow at `62simple-cdd`, `63my-cdd-status`, `64cdrom-detect` and `65final-message`. The early selector registers 61/63; `partman/early_command` calls `finish-order.sh` before partitioning, checks all three original native scripts and then renames them. Native udebs and script contents are unchanged. The CD-ROM APT-source preseed remains; no forced network backend or suppressed completion dialog. Relocation failure returns nonzero to native preseed error handling, which does not guarantee installation termination. No stage-00 guard or additional repeated-execution restriction is introduced. ISO/GTK/text/first-boot testing is pending.

During candidate inspection, the native status reports the current firmware package and its position in the actual inventory. Preparation of each named license is also shown; the build-time automatic/interactive consent policy and APT approvals are unchanged.

**Outcome:** assemble the complete **selected-only firmware source** that handles a broad inventory, both CPU vendors' microcode packages, reviewed Backports fallbacks, individual omissions and **preauthorized named vendor licenses or the original interactive questions**. The normal Debian version is simpler: [04 — Firmware](../05_extended_device_support/README.md).

## Step 1 — Prepare the shared installer framework

Complete [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md) first. The profile cannot run independently because it requires `/target`, target APT, `capture`, native Debconf and the installed target's separate Debconf database.

Work inside `99_custom_netintst/my-cdd/` in a **test branch or scratch copy**. Do not run its source module as a shell script on a normal NAS.

## Step 2 — Create the five exact source files

| Path | Responsibility |
| --- | --- |
| `profiles/extended-device-support.description` | Human-readable checkbox for additional firmware and both CPU microcode packages. |
| `profiles/extended-device-support.extra` | Stages the firmware module, requested package inventory and generated firmware-license policy on the ISO. |
| `profiles/extended-device-support.postinst` | Native Simple-CDD completion verifier; checks a marker without rerunning feature installation. |
| `installer/extended-device-support.sh` | All selection, fallback, per-package omission, complete APT review and native vendor-license Debconf code. |
| `scripts/firmware-candidates.txt` | The full approved package inventory, including both Intel and AMD CPU microcode. |

Create the necessary source directories if absent:

~~~sh
mkdir -p profiles installer scripts
~~~

This is only filesystem organization, not package installation.

**1. Create `profiles/extended-device-support.description`.** Human-readable checkbox for additional firmware and both CPU microcode packages.

Open `profiles/extended-device-support.description` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.

**2. Create `profiles/extended-device-support.extra`.** Stages the firmware module, requested package inventory and generated firmware-license policy on the ISO.

Open `profiles/extended-device-support.extra` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.

**3. Create `installer/extended-device-support.sh`.** All selection, fallback, per-package omission, complete APT review and native vendor-license Debconf code.

Open `installer/extended-device-support.sh` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.

**4. Create `scripts/firmware-candidates.txt`.** The full approved package inventory, including both Intel and AMD CPU microcode.

Open `scripts/firmware-candidates.txt` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.




Do not mark the ordinary imported `extended-device-support.sh` source module as an independent program.

Native Debian Installer stage `61my-cdd` runs each approved selected handler **once**, then writes that profile's success marker. Unmodified Simple-CDD stage `62simple-cdd` executes the selected profile's verification-only `.postinst` **in-target**. Stage `63my-cdd-status` independently checks all approved markers and overall `COMPLETE`, returning native exit 10 rather than falsely reporting success.

## Step 3 — Understand why each operation exists

1. The optional checkbox is called `extended-device-support`, but the dispatch function is `profile_firmware()`, loaded from `installer/extended-device-support.sh`.
2. The `firmware-candidates.txt` file lists the **entire intended inventory**. **Both** `intel-microcode` and `amd64-microcode` remain listed even if the build machine uses only one CPU vendor. The installer does **not** limit packages to currently detected hardware.
3. The repeated `normal_suite()` lookup belongs to this firmware handler, not the shared helper module. The handler inspects every requested package's actual signed APT candidates. If Backports was **separately selected**, a compatible Backports package is considered first; otherwise only normal Debian suites are used. Each candidate is simulated with the **accumulated** approved package set. APT determines compatibility; any proposed package removals appear in the complete transaction for user approval, not a project blacklist.
4. If a package is absent or conflicting, the **specific** package and reason are displayed in a **default-No omission question**. The installer must not skip it without affirmative consent.
5. `firmware-ipw2x00` and `firmware-ivtv` may contain vendor license questions. Their *exact selected Debian package archives* are downloaded and verified; the native Boolean template is checked. With `AUTO_ACCEPT_FIRMWARE_LICENSES=true` (the build default), acceptance is preauthorized only for these two packages and logged with the selected version. With `false`, the original full Debconf templates are loaded into **the installer's existing GTK/text frontend** for explicit acceptance. In both cases accepted consent is conveyed to and verified in the **target** Debconf database. Review the vendor terms before enabling or distributing an automatically accepting ISO.
6. In interactive mode, a refused license means a separate explicit omission decision and a **new simulation of the remaining full package set**. Reject any dependency that would reinstall the declined package.
7. The final real APT transaction is shown with selected source suites, fallback/omission context and actual package changes for **one default-No approval**. There is no separate final review simulation. The approved set is installed into `/target`, followed by `dpkg --audit`. No unselected feature should install any of these packages just because the media carries the manifest.

**Why this is not one simple `apt install` command:** ordinary Debian's APT can display its native vendor license questions directly, whereas Debian Installer's cdebconf and the target's Debconf database are separate.

## Step 4 — Validate the file copies

~~~sh
sh -n installer/extended-device-support.sh
~~~

This checks only POSIX shell syntax; it does **not** select packages or show vendor licenses.



Build via `./build.sh` only after every shared input is in place. Use a **throwaway VM** to test default automatic acceptance without license dialogs; rebuild with `AUTO_ACCEPT_FIRMWARE_LICENSES=false` to test both full vendor license dialogs, a decline, an individual omitted package, absent Backports, safe fallback, conflict rejection and first-boot device logs.

## Complete source listings

These are **entire original files**, including the full license-handling code. You do not need to invent the missing half of a prior pseudocode example.
<details>
<summary><strong>Complete profiles/extended-device-support.description</strong> (1 lines; original blob <code>a45b1f2ac5a6b9e035870e1908a9bdc34f6ff28f</code>)</summary>

````text
Install all listed firmware and BOTH CPU microcodes; explicit approval for omissions
````

</details>

<details>
<summary><strong>Complete profiles/extended-device-support.extra</strong> (4 lines; current blob <code>3a8e9b33765f7bedd44bb82386447f1a3bd86f3d</code>)</summary>

````text
# extended-device-support: source assets copied by Simple-CDD (not automatically installed).
installer/extended-device-support.sh
scripts/firmware-candidates.txt
tmp/generated/firmware-license-policy
````

</details>



<details>
<summary><strong>Complete installer/extended-device-support.sh</strong> (226 lines; current blob <code>ab255d0f97b8fb5c63db6b278503f8cdee53ca9a</code>)</summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

# Used repeatedly for each firmware candidate; keep its suite-selection
# policy inside the only profile that needs it.
normal_suite() {
    best_suite=''
    best_version=''
    for suite in trixie-security trixie-updates trixie; do
        v="$(suite_version "$1" "$suite")"
        [ -n "$v" ] || continue
        if [ -z "$best_version" ] ||
            in-target dpkg --compare-versions "$v" gt "$best_version"; then
            best_suite=$suite
            best_version=$v
        fi
    done
    [ -n "$best_suite" ] || return 1
    printf '%s\n' "$best_suite"
}

# Read the original Debconf license question from the exact APT-selected
# .deb, never from a copied or shortened license. The build policy may
# preauthorize these two named agreements; otherwise show the original
# question in native cdebconf. Returns 0 on acceptance, 1 on refusal.
firmware_license_decision() {
    licensed_pkg=$1
    licensed_selector=$2
    case "$licensed_pkg" in
        firmware-ipw2x00|firmware-ivtv) : ;;
        *) fatal "Unrecognized license-restricted firmware: $licensed_pkg" ;;
    esac
    progress_status "Preparing vendor license: $licensed_pkg"
    licensed_suite=${licensed_selector#*/}
    licensed_version="$(suite_version "$licensed_pkg" "$licensed_suite")"
    [ -n "$licensed_version" ] ||
        fatal "Cannot identify selected license-bearing version: $licensed_selector"
    license_dir="/tmp/my-cdd-license-$licensed_pkg"
    [ ! -e "/target$license_dir" ] ||
        fatal "Unexpected existing temporary license directory: $license_dir"
    mkdir -m 700 "/target$license_dir" ||
        fatal "Cannot prepare temporary license directory for $licensed_pkg"

    # Download but do not install the selected candidate; the sandbox setting
    # confines this trusted APT download to our root-owned temporary folder.
    capture in-target sh -c '
        cd "$1" || exit 1
        apt-get -o APT::Sandbox::User=root download "$2"
    ' my-cdd "$license_dir" "$licensed_pkg=$licensed_version" ||
        fatal "Cannot download the exact licensed package: $licensed_selector"

    set -- "/target$license_dir"/*.deb
    [ "$#" -eq 1 ] && [ -f "$1" ] ||
        fatal "Expected exactly one downloaded .deb for $licensed_pkg"
    license_deb=${1#/target}
    capture in-target dpkg-deb -f "$license_deb" Package ||
        fatal "Cannot inspect downloaded $licensed_pkg package"
    grep -Fx "$licensed_pkg" "$WORK/output" >/dev/null ||
        fatal "Downloaded license package has wrong name: $licensed_pkg"
    capture in-target dpkg-deb -f "$license_deb" Version ||
        fatal "Cannot verify downloaded $licensed_pkg version"
    grep -Fx "$licensed_version" "$WORK/output" >/dev/null ||
        fatal "Downloaded $licensed_pkg license does not match selected APT version"
    capture in-target dpkg-deb -e "$license_deb" "$license_dir/control" ||
        fatal "Cannot extract native Debconf templates for $licensed_pkg"

    license_templates="/target$license_dir/control/templates"
    license_question="$licensed_pkg/license/accepted"
    [ -s "$license_templates" ] ||
        fatal "No vendor license templates in $licensed_pkg binary"
    grep -Fx "Template: $license_question" "$license_templates" >/dev/null ||
        fatal "No native license acceptance question for $licensed_pkg"
    if [ "$firmware_license_policy" = true ]; then
        log "PREAUTHORIZED LICENSE: $licensed_pkg; version=$licensed_version; policy=auto-accept"
    else
        debconf-loadtemplate "$licensed_pkg" "$license_templates" ||
            fatal "Cannot load vendor license for $licensed_pkg"
        db_set "$license_question" false ||
            fatal "Cannot reset $licensed_pkg license answer"
        db_fset "$license_question" seen false ||
            fatal "Cannot display native $licensed_pkg license"
        db_input critical "$license_question" ||
            fatal "Native $licensed_pkg license question unavailable"
        db_go || fatal "Native $licensed_pkg license dialog cancelled"
        db_get "$license_question" ||
            fatal "Cannot read the $licensed_pkg license decision"
        if [ "$RET" != true ]; then
            log "USER DECLINED LICENSE: $licensed_pkg"
            rm -rf -- "/target$license_dir"
            return 1
        fi
        log "USER ACCEPTED LICENSE: $licensed_pkg"
    fi

    # D-I and the installed target have different Debconf databases. Store
    # and verify only the accepted value, whether preauthorized at build time
    # or explicitly accepted in the native license dialog.
    # Feed selections via stdin, never through command arguments or logs.
    printf '%s %s boolean true\n' "$licensed_pkg" "$license_question" |
        capture chroot /target /usr/bin/debconf-set-selections ||
        fatal "Cannot record explicit license agreement in target: $licensed_pkg"
    printf 'GET %s\n' "$license_question" |
        capture chroot /target /usr/bin/env DEBIAN_FRONTEND=noninteractive \
            /usr/bin/debconf-communicate "$licensed_pkg" ||
        fatal "Cannot verify target license answer: $licensed_pkg"
    grep -Fx '0 true' "$WORK/output" >/dev/null ||
        fatal "Target Debconf license consent not retained for $licensed_pkg"
    rm -rf -- "/target$license_dir"
    return 0
}

profile_firmware() {
    [ -r "$MEDIA/firmware-license-policy" ] ||
        fatal 'Missing build-time firmware license policy'
    firmware_license_policy="$(cat "$MEDIA/firmware-license-policy")"
    case "$firmware_license_policy" in
        true|false) ;;
        *) fatal 'Invalid build-time firmware license policy' ;;
    esac
    update_signed_apt
    [ -r "$MEDIA/firmware-candidates.txt" ] || fatal 'Required firmware inventory missing'
    : > "$WORK/firmware-selectors"
    : > "$WORK/firmware-fallbacks"
    : > "$WORK/firmware-omissions"
    firmware_candidates="$(grep -Ev '^[[:space:]]*(#|$)' "$MEDIA/firmware-candidates.txt" || :)"
    firmware_total=0
    for pkg in $firmware_candidates; do firmware_total=$((firmware_total + 1)); done
    firmware_index=0
    for pkg in $firmware_candidates; do
        firmware_index=$((firmware_index + 1))
        case "$pkg" in
            ''|*[!a-zA-Z0-9.+-]*) fatal "Unsafe inventory package: $pkg";;
        esac
        progress_status "Checking firmware $firmware_index of $firmware_total: $pkg"
        stable="$(normal_suite "$pkg")" || stable=''
        bpo=''
        if backports_is_selected; then bpo="$(suite_version "$pkg" trixie-backports)"; fi
        selector=''
        reason=''
        if [ -n "$bpo" ]; then
            candidate="$pkg/trixie-backports"
            if capture in-target apt-get -s install $(cat "$WORK/firmware-selectors") "$candidate"; then
                selector=$candidate
            else
                reason='Backports candidate incompatible with existing requested set; details in complete APT log'
            fi
        fi
        if [ -z "$selector" ] && [ -n "$stable" ]; then
            candidate="$pkg/$stable"
            if capture in-target apt-get -s install $(cat "$WORK/firmware-selectors") "$candidate"; then
                selector=$candidate
                if backports_is_selected; then
                    [ -n "$reason" ] || reason='No published Backports version'
                    stable_version="$(suite_version "$pkg" "$stable")"
                    printf '%s: version=%s, origin=%s, fallback reason=%s\n' \
                        "$pkg" "$stable_version" "$stable" "$reason" >> "$WORK/firmware-fallbacks"
                fi
            fi
        fi
        if [ -z "$selector" ]; then
            if [ -z "$bpo" ] && [ -z "$stable" ]; then
                reason='No published candidate in the enabled approved Debian repositories'
            else
                detail="$(grep -m1 '^E:' "$WORK/output" | cut -c1-160 || true)"
                [ -n "$detail" ] ||
                    detail='APT refused the selected package combination (full diagnostics in target log)'
                reason="Package dependency/conflict: $detail"
            fi
            report_omission "$pkg" "$reason"
            printf '%s: %s\n' "$pkg" "$reason" >> "$WORK/firmware-omissions"
        else
            printf '%s\n' "$selector" >> "$WORK/firmware-selectors"
        fi
    done
    [ -s "$WORK/firmware-selectors" ] || fatal 'No approved firmware packages remain'
    # Ask the two complete package-native license questions BEFORE unpack.
    # Declines require a separate per-package omission approval and a
    # compatibility check before the actual APT transaction approval.
    license_omitted=false
    for licensed_pkg in firmware-ipw2x00 firmware-ivtv; do
        licensed_selector="$(grep "^$licensed_pkg/" "$WORK/firmware-selectors" || true)"
        [ -n "$licensed_selector" ] || continue
        if firmware_license_decision "$licensed_pkg" "$licensed_selector"; then
            :
        else
            report_omission "$licensed_pkg" 'The full vendor firmware license was declined in Debian Installer'
            printf '%s: license declined; individually approved omission\n' "$licensed_pkg" >> "$WORK/firmware-omissions"
            awk -v prefix="$licensed_pkg/" 'index($0,prefix)!=1 {print}' \
                "$WORK/firmware-selectors" > "$WORK/firmware-license-filtered"
            mv "$WORK/firmware-license-filtered" "$WORK/firmware-selectors" ||
                fatal "Cannot exclude declined firmware: $licensed_pkg"
            license_omitted=true
        fi
    done
    [ -s "$WORK/firmware-selectors" ] ||
        fatal 'No approved firmware packages remain after license decisions'
    if [ "$license_omitted" = true ]; then
        simulate_target install $(cat "$WORK/firmware-selectors")
        for licensed_pkg in firmware-ipw2x00 firmware-ivtv; do
            if grep -q "^$licensed_pkg: license declined;" "$WORK/firmware-omissions"; then
                if grep -Eq "^Inst $licensed_pkg([ :]|$)" "$WORK/plan"; then
                    fatal "Declined $licensed_pkg license is still required as a dependency"
                fi
            fi
        done
    fi
    {
        echo 'Selected firmware and microcode packages:'
        cat "$WORK/firmware-selectors"
        if [ -s "$WORK/firmware-fallbacks" ]; then
            echo
            echo 'Normal repository fallbacks and reasons:'
            cat "$WORK/firmware-fallbacks"
        fi
        if [ -s "$WORK/firmware-omissions" ]; then
            echo
            echo 'Individually approved omissions:'
            cat "$WORK/firmware-omissions"
        fi
    } > "$WORK/firmware-review"
    APT_REVIEW_LABEL='Extended device support' APT_REVIEW_FILE="$WORK/firmware-review" \
        run_target apt-get install $(cat "$WORK/firmware-selectors")
    run_target dpkg --audit
}


````

</details>

<details>
<summary><strong>Complete scripts/firmware-candidates.txt</strong> (41 lines; original blob <code>bf28f4a9b91413c1d1f585c2fc368dc5b797d38c</code>)</summary>

````text
# Provisional Debian 13 binary firmware candidates from 10_extended_device_support.md.
# These are NOT auto-installed; resolve the full set at install time.
# With Backports explicitly selected, prefer viable targeted Backports versions.
# Each unavailable/conflicting package requires its own omission consent.
intel-microcode
amd64-microcode
firmware-linux
firmware-linux-nonfree
firmware-misc-nonfree
firmware-intel-misc
firmware-realtek
firmware-bnx2
firmware-bnx2x
firmware-cavium
firmware-marvell-prestera
firmware-myricom
firmware-netronome
firmware-netxen
firmware-qlogic
firmware-atheros
firmware-brcm80211
firmware-iwlwifi
firmware-ipw2x00
firmware-libertas
firmware-mediatek
firmware-ti-connectivity
firmware-ath9k-htc
firmware-carl9170
firmware-zd1211
firmware-amd-graphics
firmware-intel-graphics
firmware-nvidia-graphics
firmware-ast
firmware-qcom-soc
firmware-samsung
firmware-siano
firmware-ivtv
firmware-cirrus
firmware-intel-sound
firmware-sof-signed
bluez-firmware
````

</details>

## Native Simple-CDD completion verifier

Create `profiles/extended-device-support.postinst` from the full source below, alongside its `.description` and `.extra` files. The stage-61 runner writes its record after successful handler execution; the original `62simple-cdd` hook runs this verifier in-target without installing the feature twice.

~~~sh
chmod +x profiles/extended-device-support.postinst
sh -n profiles/extended-device-support.postinst
~~~

The syntax check is read-only. The final `63my-cdd-status` guard also checks this selected profile's record, returning exit 10 if any required record is missing.

<details>
<summary><strong>profiles/extended-device-support.postinst</strong> — complete native verifier (11 lines; Git blob <code>a897ce39caf367193921590895e531dc256cb4af</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer stage-11 runner, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/extended-device-support"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'extended-device-support'
    exit 1
fi
````

</details>
