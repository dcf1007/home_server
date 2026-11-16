# 05 — Recreate extended firmware and microcode support

**Outcome:** assemble the complete **selected-only firmware source** that handles a broad inventory, both CPU vendors' microcode packages, reviewed Backports fallbacks, individual omissions and **the package vendors' original license questions**. The normal Debian version is simpler: [04 — Firmware](../05_extended_device_support/README.md).

## Step 1 — Prepare the shared installer framework

Complete [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md) first. The profile cannot run independently because it requires `/target`, target APT, `capture`, native Debconf and the installed target's separate Debconf database.

Work inside `99_custom_netintst/my-cdd/` in a **test branch or scratch copy**. Do not run its source module as a shell script on a normal NAS.

## Step 2 — Create the five exact source files

| Path | Responsibility |
| --- | --- |
| `profiles/extended-device-support.description` | Human-readable checkbox for additional firmware and both CPU microcode packages. |
| `profiles/extended-device-support.extra` | Stages the firmware module and full list of requested packages on the ISO. |
| `profiles/extended-device-support.postinst` | Checks completion and must be executable, but performs no second install. |
| `installer/profile-firmware.sh` | All selection, fallback, per-package omission, complete APT review and native vendor-license Debconf code. |
| `scripts/firmware-candidates.txt` | The full approved package inventory, including both Intel and AMD CPU microcode. |

Create the necessary source directories if absent:

~~~sh
mkdir -p profiles installer scripts
~~~

This is only filesystem organization, not package installation.

**1. Create `profiles/extended-device-support.description`.** Human-readable checkbox for additional firmware and both CPU microcode packages.

Open `profiles/extended-device-support.description` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.

**2. Create `profiles/extended-device-support.extra`.** Stages the firmware module and full list of requested packages on the ISO.

Open `profiles/extended-device-support.extra` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.

**3. Create `profiles/extended-device-support.postinst`.** Checks completion and must be executable, but performs no second install.

Open `profiles/extended-device-support.postinst` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.

**4. Create `installer/profile-firmware.sh`.** All selection, fallback, per-package omission, complete APT review and native vendor-license Debconf code.

Open `installer/profile-firmware.sh` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.

**5. Create `scripts/firmware-candidates.txt`.** The full approved package inventory, including both Intel and AMD CPU microcode.

Open `scripts/firmware-candidates.txt` in a text editor, paste the indicated contents and save it at that path.

Open that specific file, expand the matching **complete source listing** below, paste all contents, Save the document after reviewing the pasted contents. This does **not** execute the file.


Allow Simple-CDD to execute the success-marker verifier:

~~~sh
chmod +x profiles/extended-device-support.postinst
~~~

Do not mark the ordinary imported `profile-firmware.sh` source module as an independent program.

## Step 3 — Understand why each operation exists

1. The optional checkbox is called `extended-device-support`, but the dispatch function is `profile_firmware()`, loaded from `installer/profile-firmware.sh`.
2. The `firmware-candidates.txt` file lists the **entire intended inventory**. **Both** `intel-microcode` and `amd64-microcode` remain listed even if the build machine uses only one CPU vendor. The installer does **not** limit packages to currently detected hardware.
3. The repeated `normal_suite()` lookup belongs to this firmware handler, not the shared helper module. The handler inspects every requested package's actual signed APT candidates. If Backports was **separately selected**, a compatible Backports package is considered first; otherwise only normal Debian suites are used. Each candidate is simulated with the **accumulated** approved package set and rejected if it causes critical removals. The same guard excludes only removal of the replaceable `systemd-timesyncd` time client; all other previously protected packages remain blocked.
4. If a package is absent or conflicting, the **specific** package and reason are displayed in a **default-No omission question**. The installer must not skip it without affirmative consent.
5. The complete combined APT transaction (including dependencies, selected source suites, recorded fallbacks and omissions) is displayed for **default-No approval before installation**.
6. `firmware-ipw2x00` and `firmware-ivtv` may contain vendor license questions. Their *exact selected Debian package archives* are downloaded, verified, and original full Debconf templates extracted and loaded into **the installer's existing GTK/text frontend**. Accepted consent is then conveyed to the **target** Debconf database.
7. A refused license means a separate explicit omission decision and a **new simulation of the remaining full package set**. Reject any dependency that would reinstall the declined package.
8. Only the finally approved set is installed into `/target`, followed by a `dpkg --audit` check. No unselected feature should install any of these packages just because the media carries the manifest.

**Why this is not one simple `apt install` command:** ordinary Debian's APT can display its native vendor license questions directly, whereas Debian Installer's cdebconf and the target's Debconf database are separate.

## Step 4 — Validate the file copies

~~~sh
sh -n installer/profile-firmware.sh
~~~

This checks only POSIX shell syntax; it does **not** select packages or show vendor licenses.

~~~sh
sh -n profiles/extended-device-support.postinst
~~~

This parses the marker verifier. To catch copy mistakes, use `git hash-object <path>` for each file and compare the output with the original blob SHA in its heading; the command reads the file without changing it.

Build via `./build.sh` only after every shared input is in place. Use a **throwaway VM** to test both full vendor license dialogs, a decline, an individual omitted package, absent Backports, safe fallback, conflict rejection and first-boot device logs.

## Complete source listings

These are **entire original files**, including the full license-handling code. You do not need to invent the missing half of a prior pseudocode example.
<details>
<summary><strong>Complete profiles/extended-device-support.description</strong> (1 lines; original blob <code>a45b1f2ac5a6b9e035870e1908a9bdc34f6ff28f</code>)</summary>

````text
Install all listed firmware and BOTH CPU microcodes; explicit approval for omissions
````

</details>

<details>
<summary><strong>Complete profiles/extended-device-support.extra</strong> (3 lines; original blob <code>ac99474eb0d3999646e2601d19354a5a2e658306</code>)</summary>

````text
# extended-device-support: source assets copied by Simple-CDD (not automatically installed).
installer/profile-firmware.sh
scripts/firmware-candidates.txt
````

</details>

<details>
<summary><strong>Complete profiles/extended-device-support.postinst</strong> (11 lines; original blob <code>a01a9471ed75662f4e85059a0dc34df793e6af54</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer late command, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/extended-device-support"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'extended-device-support'
    exit 1
fi
````

</details>

<details>
<summary><strong>Complete installer/profile-firmware.sh</strong> (223 lines; original blob <code>77c9361bff98f675b9212bdd2340af2f9f1ca586</code>)</summary>

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
# .deb, never from a copied or shortened license. Uses Simple-CDD's existing
# .extra mechanism and Debian Installer's native cdebconf graphical frontend.
# Returns 0 on explicit acceptance and 1 on explicit refusal.
firmware_license_decision() {
    licensed_pkg=$1
    licensed_selector=$2
    case "$licensed_pkg" in
        firmware-ipw2x00|firmware-ivtv) : ;;
        *) fatal "Unrecognized license-restricted firmware: $licensed_pkg" ;;
    esac
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

    # D-I and the installed target have different Debconf databases. Only
    # after the above explicit GUI consent, store and verify the matching
    # target boolean; the package's own preinst then sees its accepted value.
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
    update_signed_apt
    [ -r "$MEDIA/firmware-candidates.txt" ] || fatal 'Required firmware inventory missing'
    : > "$WORK/firmware-selectors"
    : > "$WORK/firmware-fallbacks"
    : > "$WORK/firmware-omissions"
    # systemd-timesyncd is a replaceable NTP client, not the systemd init
    # package. Reject all other previously protected removals.
    for pkg in $(grep -Ev '^[[:space:]]*(#|$)' "$MEDIA/firmware-candidates.txt"); do
        case "$pkg" in
            ''|*[!a-zA-Z0-9.+-]*) fatal "Unsafe inventory package: $pkg";;
        esac
        stable="$(normal_suite "$pkg")" || stable=''
        bpo=''
        if backports_is_selected; then bpo="$(suite_version "$pkg" trixie-backports)"; fi
        selector=''
        reason=''
        if [ -n "$bpo" ]; then
            candidate="$pkg/trixie-backports"
            if capture in-target apt-get -s install $(cat "$WORK/firmware-selectors") "$candidate"; then
                if ! grep -E '^Remv (linux-image|linux-headers|grub|openssh-server|sudo|systemd|apt |dpkg )' "$WORK/output" |
                    grep -Ev '^Remv systemd-timesyncd([[:space:]:]|$)' >/dev/null; then
                    selector=$candidate
                fi
            fi
            [ -n "$selector" ] ||
                reason='Backports candidate incompatible with existing requested set; details in complete APT log'
        fi
        if [ -z "$selector" ] && [ -n "$stable" ]; then
            candidate="$pkg/$stable"
            if capture in-target apt-get -s install $(cat "$WORK/firmware-selectors") "$candidate"; then
                if ! grep -E '^Remv (linux-image|linux-headers|grub|openssh-server|sudo|systemd|apt |dpkg )' "$WORK/output" |
                    grep -Ev '^Remv systemd-timesyncd([[:space:]:]|$)' >/dev/null; then
                    selector=$candidate
                    if backports_is_selected; then
                        [ -n "$reason" ] || reason='No published Backports version'
                        stable_version="$(suite_version "$pkg" "$stable")"
                        printf '%s: version=%s, origin=%s, fallback reason=%s\n' \
                            "$pkg" "$stable_version" "$stable" "$reason" >> "$WORK/firmware-fallbacks"
                    fi
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
    simulate_target install $(cat "$WORK/firmware-selectors")
    check_critical_removals
    {
        echo 'All chosen firmware/microcode package selectors:'
        cat "$WORK/firmware-selectors"
        echo 'Normal source fallbacks and specific reasons:'
        cat "$WORK/firmware-fallbacks"
        echo 'Individually approved package omissions:'
        cat "$WORK/firmware-omissions"
        echo 'Complete final joint APT simulation:'
        cat "$WORK/plan"
    } > "$WORK/firmware-review"
    review_plan 'Extended support: entire mixed-source firmware transaction' "$WORK/firmware-review"

    # Ask the two complete package-native license questions BEFORE unpack.
    # Declines require a separate per-package omission approval and a
    # fresh full APT simulation and transaction review.
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
        check_critical_removals
        for licensed_pkg in firmware-ipw2x00 firmware-ivtv; do
            if grep -q "^$licensed_pkg: license declined;" "$WORK/firmware-omissions"; then
                if grep -Eq "^Inst $licensed_pkg([ :]|$)" "$WORK/plan"; then
                    fatal "Declined $licensed_pkg license is still required as a dependency"
                fi
            fi
        done
        {
            echo 'Package selectors after individually approved license omissions:'
            cat "$WORK/firmware-selectors"
            echo 'Individually approved omissions:'
            cat "$WORK/firmware-omissions"
            echo 'Recomputed joint APT simulation:'
            cat "$WORK/plan"
        } > "$WORK/firmware-license-review"
        review_plan 'Extended support: revised transaction after license omissions' "$WORK/firmware-license-review"
    fi
    run_target apt-get -y install $(cat "$WORK/firmware-selectors")
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
