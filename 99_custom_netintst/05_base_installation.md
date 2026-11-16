# 05 — Build the base installer framework and custom profile hooks

This is **how to wire the custom scripts into Debian Installer**, not a walk-through of installer screens. The ordinary base installation remains Debian's own program; don't write a replacement partitioner or duplicate language/account prompts.

## Step 1 — Create the editable installer defaults

Put suggested locale, timezone, keyboard, hostname, admin username, DHCP and tasksel options into `my-cdd/profile_defaults.conf`, **not** into the optional Debian-tweaks module. The build script validates them and generates `tmp/generated/defaults.preseed` and an early boot `KERNEL_PARAMS` setting.

Use `?=` for early language/keyboard defaults (asked before the ISO preseed is read), and `seen false` for later editable Debconf questions. Avoid any fixed password, username authorization, selected profile flags or disk path.

**Limitation:** tasksel may ignore the unseen tasksel defaults. Keep a visible build warning and explicitly verify SSH server + standard utilities, **without a desktop**, during the VM test.

## Step 2 — Create the early preseed hook

Add to `profiles/default.preseed`:

~~~text
d-i preseed/early_command string /bin/sh /cdrom/simple-cdd/profile-confirm.sh && anna-install simple-cdd-profiles
~~~

This ordering matters. `installer/profile-confirm.sh` runs **before** installing the upstream Simple-CDD profile udeb, so it must load the real generated `simple-cdd.templates` itself, plus `profile-confirm.templates`. It uses Debian Installer's **existing cdebconf frontend** to display all seven real profile checkboxes.

The implementation's essential screen calls are:

~~~sh
debconf-loadtemplate simple-cdd "$TEMPLATE_SIMPLE"
debconf-loadtemplate my-cdd "$TEMPLATE_CONFIRM"
. /usr/share/debconf/confmodule
db_fset simple-cdd/profiles seen false
db_input high simple-cdd/profiles
db_go
~~~

The source checks every call's return status. Do not make the screen silently optional.

## Step 3 — Validate exact profile names and dependencies

Use `installer/ordered-selection.sh` to translate the selected comma-separated set into the **one fixed execution order**. It rejects unknown names and checks that a selected `zram-writeback` has an **independently selected `ensure-7x-kernel`**.

Do not automatically add the kernel profile. If validation fails, the early hook shows an explanation and returns to the same profile multiselect.

## Step 4 — Implement the review and default-No confirmation

Add `my-cdd/profile-summary` and `my-cdd/profile-confirm` templates in `installer/profile-confirm.templates`. The summary displays a **Selected/Not selected** state for every profile in execution order.

The `profile-confirm` question is:

~~~text
Template: my-cdd/profile-confirm
Type: boolean
Default: false
Description: Proceed with exactly these selected installation profiles?
~~~

**No** returns to selection. **Yes** records the exact approved list in the private installer-side `/tmp/my-cdd-confirmed-profiles` file, then allows Debian Installer to load the original `simple-cdd-profiles` udeb. Profile selection approval **does not authorize APT transactions or partition destruction**.

## Step 5 — Write the late-command entry point

Set the late preseed hook:

~~~text
d-i preseed/late_command string /bin/sh /cdrom/simple-cdd/run-selected.sh
~~~

Write `installer/run-selected.sh` to:

1. Set a private work directory and write `INCOMPLETE` into `/target/var/log/installer/my-cdd-status` before any change.
2. Source `/usr/share/debconf/confmodule` for graphical/text review screens.
3. Provide `capture`, `fatal`, `review_plan`, `simulate_target`, `run_target` and `review_install` helpers once, **not reimplemented by every profile**.
4. Check that the current Simple-CDD selection exactly matches the previously confirmed list.
5. Check a usable **local root recovery password** and, if needed, ask through Debian's original password questions before optional changes.
6. Confirm Debian Installer's native `policy-rc.d` service-start suppression when installing target packages. Do not permanently mask Docker or OMV units.
7. Disable only installer-specific active `cdrom:` target APT entries before network transactions; preserve real network sources.
8. Source and execute the **selected** profile functions in the defined order; write a completion marker **only after a function succeeds**.
9. Mark `COMPLETE` only after all selected work finishes; on errors mark `FAILED`, show the user diagnostics and preserve logs.

A critical helper implementation ensures the output of `in-target` commands can actually be displayed in Debconf reviews:

~~~sh
if [ "$1" = in-target ]; then
    shift
    set -- in-target --pass-stdout "$@"
fi
~~~

Without `--pass-stdout`, target command output may go only to installer syslog, leaving plan review and parsers empty. The complete capture wrapper also records output in the target log and returns the real command status.

## Step 6 — Attach and verify individual profiles

Use the dispatch loop described in [00 — Construct a profile](00_profile_construction.md). Each module defines a function such as `profile_omv()` or `profile_zram()`. The source file is **not** run by itself; the common dispatcher sources it only when its profile was selected.

For approved package operations, `simulate_target` creates the complete APT dry-run, `review_plan` displays it and requests default-No approval, and `run_target` runs the already-approved operation with native Debian Installer package progress.

Each `profiles/<name>.postinst` checks the marker created after the corresponding function completes. It must **not repeat installation work**.

## Step 7 — Build the finish-install failure guard

Place `installer/15my-cdd-status` in the common media manifest and register it early under `/usr/lib/finish-install.d`. Debian Installer's normal hook order runs it after the selected-profile verifier but before the final success message.

The guard checks:

- The stored status says `COMPLETE`;
- The approved selection still exists;
- Every selected profile has its completion marker.

If not, the guard uses Debian Installer finish-install's **exit code 10** to return to its menu instead of reporting a successful installation. Ordinary exit 1 is insufficient for this particular native hook.

## Step 8 — Stage, build and test these entry points

Add the early hook, templates, ordered selector, dispatcher, shared helpers and status guard to `profiles/default.extra`. Check that the entry scripts are executable and the shell syntax parses. Run `./build.sh` from `my-cdd/`, then inspect the ISO staging directory to verify all common files are present.

In a throwaway VM test: zero selected profiles, every initial checkbox unchecked, Yes/No cycles, invalid ZRAM dependency, root password recovery, APT refusal, failed optional profile, and guard behavior. Test both GTK and text frontends: **their actual behavior has not been confirmed end to end**.

**Source:** [profile-confirm.sh](my-cdd/installer/profile-confirm.sh), [run-selected.sh](my-cdd/installer/run-selected.sh), [15my-cdd-status](my-cdd/installer/15my-cdd-status), [default.preseed](my-cdd/profiles/default.preseed).
