# 02 — Build the optional Backports installer profile

**Build goal:** create the source files that allow a user to select signed Debian Trixie Backports during installation, inspect the effective priority, approve eligible upgrades and separately approve cleanup. The code runs under Debian Installer, against `/target`.

For the easy post-install procedure, use [02 — Normal Debian Backports](../02_backports/README.md). Start with the [shared profile construction pattern](00_profile_construction.md).

## Step 1 — Register a selectable profile and its media inputs

In `simple-cdd.conf`, include `backports` in `profiles` but leave `auto_profiles` and `default_profiles` empty. Put its menu label into `profiles/backports.description`.

Create `profiles/backports.extra`:

~~~text
installer/profile-backports.sh
scripts/debian-backports.sources
~~~

**Why:** the module and its source template must exist under the ISO's `/cdrom/simple-cdd` directory. The manifest copies them; it does **not** automatically activate Backports.

## Step 2 — Construct the signed source template

Create `scripts/debian-backports.sources`. The tracked template specifies Debian's mirror, `trixie-backports`, the components and Debian's archive key. Its contents are standard Deb822 APT source configuration:

~~~text
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
~~~

Do **not** add an APT preference assigning Backports priority 900; its normal priority should remain **100**. The installed Debian guide uses the same source but a human edits it on the running machine.

## Step 3 — Create the selected-only module

Create `installer/profile-backports.sh` with a function named `profile_backports()`, called only by the dispatcher when `backports` is selected.

The first operations verify and copy the staged file into the installed target, then update APT and check its effective policy. A source excerpt shows the intended structure:

~~~sh
[ -r "$MEDIA/debian-backports.sources" ] ||
    fatal 'Signed Backports repository template missing'
[ ! -e /target/etc/apt/preferences.d/90-local-backports.pref ] ||
    fatal 'Unexpected old Backports pin; manual review required'
mkdir -p /target/etc/apt/sources.list.d
cp "$MEDIA/debian-backports.sources" /target/etc/apt/sources.list.d/debian-backports.sources
chmod 644 /target/etc/apt/sources.list.d/debian-backports.sources
update_signed_apt
~~~

Place this logic **inside** `profile_backports()`. The common `update_signed_apt` helper calls target `apt-get update`, then reads `apt-cache policy` into the review output. The module verifies that every Backports priority shown is 100 and rejects inconsistent priority records.

**Reason:** a source file's presence alone does not prove APT will prefer Stable over Backports.

## Step 4 — Build the upgrade review and approval

The shared `reviewed_upgrade` helper performs the complete process:

1. Simulate a target `dist-upgrade` without changing installed packages.
2. Fail if the plan would remove essential boot, kernel, SSH, sudo or package-manager components.
3. Display the complete plan with a native GTK/text Debconf note.
4. Ask a separate **default-No** approval before executing the upgrade.
5. Run the approved target APT transaction through `debconf-apt-progress`.
6. Audit package state and simulate again to ensure eligible changes were not left unapplied.

The module calls:

~~~sh
reviewed_upgrade
~~~

**Do not** replace this with unconditional `in-target apt-get -y dist-upgrade`; the `-y` is permitted only *after* the installer user approves the complete simulation.

## Step 5 — Implement cleanup without silently removing packages

Build cleanup in the profile with the following **real source excerpt**:

~~~sh
simulate_target autoremove --purge
check_critical_removals
~~~

Read the generated `$WORK/plan`. If it proposes packages marked `Remv` or `Purg`, show **the full plan**. Ask the existing native `my-cdd/approve-removal` default-No question **once for each individual package**. Only after all proposed removals have been approved may the module run:

~~~sh
run_target apt-get -y autoremove --purge
~~~

It then looks for `dpkg -l` entries in the `rc` state (removed package, residual configuration), displays the exact list, obtains a separate review and runs `dpkg --purge` only on those reviewed names.

Finish with `dpkg --audit` and another cleanup simulation. If newly proposed changes remain, stop instead of silently repeating removal.

## Step 6 — Wire completion and test the profile

In `installer/run-selected.sh`, the actual mapping is:

~~~sh
backports) module=backports; handler=profile_backports ;;
~~~

Keep `profiles/backports.postinst` as a marker **verification** only; do not perform APT work twice. Add no Backports packages to an unconditional boot profile.

Parse the module for shell errors before building:

~~~sh
sh -n installer/profile-backports.sh
~~~

Run the whole ISO build via `./build.sh`, then boot a disposable VM. Check the profile **unselected**, **selected but approval denied**, a safe upgrade, an unsafe removal plan and each individual cleanup approval. The installed target should have the signed source and normal priority 100.

**Exact implementation:** [profile-backports.sh](my-cdd/installer/profile-backports.sh), [shared helpers](my-cdd/installer/profile-common.sh), [Backports source](my-cdd/scripts/debian-backports.sources). The guide explains the construction; these tracked files remain the authoritative source.
