# 10 — Build the extended firmware and microcode installer profile

**Build goal:** implement one independently selectable profile that tries the complete approved firmware inventory and **both CPU microcode packages** inside `/target`; chooses compatible package suites; asks separately before omitting anything; and shows the original vendor license questions in Debian Installer's native GUI.

For a *running* Debian system, simply use the normal APT/interactive-license instructions in [04 — Firmware](../04_extended_device_support/README.md). The extra code below exists only because installer-side Debconf and the installed target's Debconf database are different.

## Step 1 — Create the profile's media inputs

Add `extended-device-support` to the selectable `profiles` string in `simple-cdd.conf` and write `profiles/extended-device-support.description`.

Create `profiles/extended-device-support.extra` with these two paths:

~~~text
installer/profile-firmware.sh
scripts/firmware-candidates.txt
~~~

The original [firmware-candidates.txt](my-cdd/scripts/firmware-candidates.txt) is a simple line-oriented package list. It deliberately includes `intel-microcode` and `amd64-microcode`. **Do not** generate a list based only on today's detected devices; the project's objective is broad future device support.

In the dispatcher keep:

~~~sh
extended-device-support) module=firmware; handler=profile_firmware ;;
~~~

Create the function `profile_firmware()` inside `installer/profile-firmware.sh`. It is sourced by the dispatcher, not executed as a standalone post-install script.

## Step 2 — Initialize the package decision records

Inside `profile_firmware`, refresh signed target APT indexes and ensure the staged manifest exists. Keep separate working files for:

- The exact package selectors that are still approved;
- Stable/normal suite fallbacks and their reasons;
- Individually approved omissions.

The tracked module begins:

~~~sh
update_signed_apt
[ -r "$MEDIA/firmware-candidates.txt" ] || fatal 'Required firmware inventory missing'
: > "$WORK/firmware-selectors"
: > "$WORK/firmware-fallbacks"
: > "$WORK/firmware-omissions"
~~~

The `: > file` syntax initializes a **temporary log/decision file** under the private installer work directory. It does not wipe a partition or touch the target's installed firmware.

## Step 3 — Implement safe per-package suite resolution

For every package name in the source inventory:

1. Reject invalid package-name characters.
2. Ask the shared `normal_suite` helper for the newest available normal Debian release candidate.
3. If the **Backports profile was separately selected**, look for a `trixie-backports` version too.
4. Simulate adding the preferred Backports candidate to the **cumulative** already-selected package set, not just on its own.
5. Reject a simulation that would remove critical kernel, GRUB, SSH, sudo, systemd, APT or dpkg packages.
6. If Backports is not available/compatible, simulate the normal Debian candidate and record the fallback reason and actual version.
7. If no viable candidate exists, ask **once for this package** whether omitting it is acceptable.

The critical source structure is:

~~~sh
if backports_is_selected; then
    bpo="$(suite_version "$pkg" trixie-backports)"
fi
~~~

The full module additionally validates `$pkg`, simulates the combined target APT transaction and chooses either `"$pkg/trixie-backports"` or `"$pkg/$stable"`. Those selectors are **exact package-and-suite choices**; they are not a global Backports priority override.

For an unresolvable item, call the existing native approval helper:

~~~sh
report_omission "$pkg" "$reason"
~~~

This substitutes the specific name and reason into `my-cdd/approve-omission`, a **default-No** question. Refusal **stops** the profile. Never silently skip an unavailable microcode or firmware package.

## Step 4 — Build the complete reviewable APT plan

Once the package list is complete, create one combined simulation:

~~~sh
simulate_target install $(cat "$WORK/firmware-selectors")
check_critical_removals
~~~

This excerpt is **existing installer source**; the whitespace-safe package-name validation earlier in the function makes this particular expansion controlled. The complete implementation writes a review file containing the chosen selectors, normal-suite fallbacks and reasons, approved omissions, **and the entire final APT plan**.

Ask permission through the shared native installer review helper:

~~~sh
review_plan 'Extended support: entire mixed-source firmware transaction' "$WORK/firmware-review"
~~~

The Debconf approval is **default No**. Do not run a real target `apt-get` just because the script has found some packages.

## Step 5 — Write the native firmware-license bridge

Two packages may carry vendor-licensed firmware requiring an explicit original consent question: `firmware-ipw2x00` and `firmware-ivtv`. A normal Debian APT session would display those prompts automatically. Here the installer uses the **cdebconf frontend**, while `/target` maintains a separate Debconf database.

Implement `firmware_license_decision(pkg, selector)` inside `installer/profile-firmware.sh`. It must:

1. Require that the name is **one of the two expected licensed packages**.
2. Determine the actual version selected from APT.
3. Download **only that selected `.deb`** into a root-owned temporary directory in the target, without installing it.
4. Verify the package's `Package` and `Version` fields, then extract its **actual, complete Debconf templates** using `dpkg-deb -e`.
5. Require the vendor's `<package>/license/accepted` question to exist.
6. Load those vendor-provided templates into the installer's native Debconf database, mark the question unseen and present it.
7. If accepted, feed that one consent into the installed target's Debconf database via `debconf-set-selections` and verify the answer; **never log or guess consent**.
8. If declined, return failure so the profile can present a separate explicit omission decision and resimulate all remaining packages.

This is the actual native-display sequence, after the downloaded templates have been verified:

~~~sh
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
~~~

**Why the complexity:** a response in the installer-side GUI is not automatically an accepted license in the installed target's Debconf database. The code must only propagate a **real explicit Yes** from the full vendor template.

The tracked source performs the target-database handoff through `chroot /target` using stdin; it does not put acceptance into arbitrary command arguments or replace legal text.

## Step 6 — Handle declined licenses without a hidden fallback

If a user declines a license, call `report_omission` with the package and the reason. With explicit omission approval:

- Remove **only** that package's selector.
- Simulate the **entire remaining package set** again.
- Reject a plan that would reinstall the declined licensed package as a dependency.
- Show the updated full plan and obtain **another default-No approval**.

If the omission is refused or another package still requires the declined package, stop and mark the profile failed.

## Step 7 — Run exactly the approved transaction

After the final approved plan, install the selectors in `/target` with the shared target APT wrapper:

~~~sh
run_target apt-get -y install $(cat "$WORK/firmware-selectors")
run_target dpkg --audit
~~~

The `-y` here follows the **separate, already completed GUI approval**, and the native license prompts have already been handled. Verify that package configuration is complete before writing a completion marker.

## Step 8 — Syntax-check, build and test

From `my-cdd/`, check the module parses:

~~~sh
sh -n installer/profile-firmware.sh
~~~

Then build via `./build.sh`. In a disposable VM test the actual **full vendor license** (both accepted and refused), an unavailable package, a conflicting Backports candidate, a normal-suite fallback, a declined omission, and no unexpected package removal. After first boot check real firmware logs.

**Source of truth:** [profile-firmware.sh](my-cdd/installer/profile-firmware.sh). The original complete package inventory belongs to [scripts/firmware-candidates.txt](my-cdd/scripts/firmware-candidates.txt).
