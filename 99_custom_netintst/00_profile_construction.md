# 00 — How to construct a Simple-CDD optional profile

This is the reusable **source-development procedure** for chapters 02, 03, 04, 06, 07, 09 and 10. It explains the source files you edit **on the build machine**. Do not run profile modules on a normal installed Debian system.

## Step 1 — Understand the source layout

Work inside `99_custom_netintst/my-cdd`. The existing project already contains the framework; **modify the corresponding file rather than creating a second competing dispatcher**.

| File or directory | Role |
| --- | --- |
| `simple-cdd.conf` | Lists the seven **offered** profiles and a separate build-only media profile |
| `profiles/<name>.description` | Human-facing text for a Simple-CDD choice |
| `profiles/<name>.extra` | List of source files to copy into the ISO's `/simple-cdd` directory |
| `installer/profile-<module>.sh` | One **sourced function** implementing the selected feature |
| `installer/run-selected.sh` | Shared late-stage entry point, approval helpers, fixed execution order |
| `profiles/<name>.postinst` | **Verification only**, checking the completion marker; never reruns operations |
| `installer/profile-confirm.templates` | Native Debian Installer (cdebconf) prompts and their defaults |
| `installer/profile-common.sh` | Reused package, suite and policy helpers |
| `scripts/` | Configuration templates staged in the ISO when needed |

For example the profile choice `ensure-7x-kernel` maps to `installer/profile-kernel.sh` and the function `profile_kernel`. **The selection name, module name and function name are not interchangeable.**

## Step 2 — Register the optional profile

In `simple-cdd.conf`, put its choice name in the `profiles="..."` line. **Do not** add it to either `auto_profiles` or `default_profiles`: both remain empty. These are actual lines from the project:

~~~sh
profiles="backports ensure-7x-kernel extended-device-support zram-writeback debian-tweaks openmediavault docker"
auto_profiles=""
default_profiles=""
build_profiles="installer-media"
~~~

The last line is **only for ISO dependencies**, not an eighth user choice. Add a one-line `profiles/<name>.description` so the menu communicates what a choice does.

## Step 3 — Stage its inputs in a .extra manifest

Create `profiles/<name>.extra` containing paths relative to `my-cdd/`. For instance, the current Docker profile contains:

~~~text
installer/profile-docker.sh
~~~

The ZRAM profile includes its module, disk selector and generator/monitor assets instead. Every file needed by the selected profile must be in its manifest or in the shared `profiles/default.extra`.

**Why:** Simple-CDD collects these inputs into the ISO's `/simple-cdd` directory. It does **not** execute a shell module merely because its file appears on the media.

## Step 4 — Write a sourceable installer function, not a standalone shell executable

The module is sourced by the shared late dispatcher. A minimal **illustrative shape** is:

~~~sh
#!/bin/sh
# Sourced by the confirmed installer dispatcher.
profile_example() {
    [ -r "$MEDIA/example.conf" ] || fatal 'Missing staged example'
    review_install 'Example package and dependencies' example-package
}
~~~

**Illustrative only:** this is a teaching pattern; `example-package` and `example.conf` do not exist in the project and must not be installed or staged. Actual modules are in `installer/profile-*.sh`.

The common dispatcher defines:

- `MEDIA` — `/cdrom/simple-cdd`; staged scripts and configuration assets;
- `WORK` — temporary, private installer working directory;
- `LOG` — installed-target log under `/target/var/log/installer`;
- `fatal "reason"` — mark failure, display diagnostics and stop;
- `capture in-target ...` — execute in the **installed target** while capturing stdout for reviews;
- `simulate_target install ...` — produce the complete APT dry-run;
- `review_plan "description" "$WORK/plan"` — display the plan and ask default-No approval;
- `review_install "description" package...` — simulation, approval, target APT install and audit;
- `run_target apt-get ...` — run an already-approved target transaction under Debian Installer progress;
- `yes_no my-cdd/<question>` — ask a named **default-No** native Debconf question.

**Never put an unconditional `apt-get install`, `swapoff` or disk write at file scope.** Every change belongs inside the selected profile's function and requires the correct approval path.

## Step 5 — Attach your function to the fixed dispatcher

The existing `run-selected.sh` reads the **approved, unchanged** list and maps choice names to module files and functions. The relevant pattern is:

~~~sh
for profile in $ordered; do
    case "$profile" in
        backports) module=backports; handler=profile_backports ;;
        ensure-7x-kernel) module=kernel; handler=profile_kernel ;;
        extended-device-support) module=firmware; handler=profile_firmware ;;
        zram-writeback) module=zram; handler=profile_zram ;;
        debian-tweaks) module=tweaks; handler=profile_tweaks ;;
        openmediavault) module=omv; handler=profile_omv ;;
        docker) module=docker; handler=profile_docker ;;
        *) fatal "Unknown selected profile: $profile" ;;
    esac
    [ -r "$MEDIA/profile-$module.sh" ] || fatal "Missing selected module: $module"
    . "$MEDIA/profile-$module.sh"
    "$handler"
    mark_complete "$profile"
done
~~~

**Do not add a second runner:** modify this mapping only if you introduce or rename a selectable profile. The completion marker is written **after** the handler succeeds.

## Step 6 — Make .postinst a verifier, not the implementation

The corresponding `profiles/<name>.postinst` must be executable and should only check for its marker. For example, the Backports verifier checks:

~~~sh
#!/bin/sh
set -eu
marker="/var/log/installer/my-cdd-completed/backports"
if [ ! -f "$marker" ]; then
    printf >&2 'Backports was selected but not applied.\n'
    exit 1
fi
~~~

This example has equivalent semantics to the existing Backports verifier; the tracked script contains a fuller diagnostic. It must **not** install the feature a second time.

## Step 7 — Add any native installer prompts

Create and document a separate template in `installer/profile-confirm.templates` for choices needing extra consent (for example a named firmware omission, targeted swapoff or destructive ZRAM conversion). Use `Type: boolean` and `Default: false` for state-changing approvals.

The code must display the exact operation before requesting approval. **Selecting a profile at the beginning is not consent to destroy a partition or remove a package**.

## Step 8 — Check the source and rebuild

From `my-cdd/`, the following checks parse shell syntax **without running the scripts**:

~~~sh
sh -n installer/profile-docker.sh
~~~

~~~sh
sh -n installer/run-selected.sh
~~~

Use the corresponding module name for the feature you changed. Then run `./build.sh`: it repeats these checks for every module, verifies staged sources and packages, and assembles the ISO. Build success **does not prove** that GTK/text Debconf, target APT or a destructive operation works.

Finally boot a **disposable VM** and test: profile unselected, selected+approved, selection denied, dependency missing, operation failed and first boot. The required cases are in [08 — Validation](08_validation_and_pending.md).

**Exact source:** [my-cdd installer](my-cdd/installer/) and [profile manifests](my-cdd/profiles/).
