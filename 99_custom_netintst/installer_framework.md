# Installer framework — Build hooks, confirmations and the dispatcher

**Current dialogue workflow — 2026-11-21:** Native cdebconf profile selection → combined selected/unselected default-No confirmation. State-changing APT operations run once, without `-y`, under the existing `in-target debconf-apt-progress` path. The temporary target-side Perl helper relays the actual APT prompt to a native boolean question using the wrapper's Debconf descriptors; the same APT process receives the answer. If APT does not prompt, a transaction-scoped `DPkg::Pre-Install-Pkgs` protocol 2 hook uses the real package actions and asks before dpkg acts; downloads and existing preconfiguration hooks may precede that approval. Already approved transactions do not prompt a second time. Only kernel/firmware compatibility simulations remain. Apt-get update needs no transaction confirmation; the residual dpkg purge has one native boolean review. No persistent APT hook or terminal UI. The actual GTK/text rendering and integrated ISO remain unverified; see [validation](validation_and_pending.md).

**Approved stage 61–65 sequence (2026-11-20):** Early selection registers 61/63. Native `partman/early_command` calls `finish-order.sh` immediately before partitioning; the script checks all three originals before moving `14simple-cdd` → `62simple-cdd`, `15cdrom-detect` → `64cdrom-detect`, `20final-message` → `65final-message` in the installer ramdisk (not the ISO or upstream udebs). Missing originals or a failed move return nonzero to native preseed error handling, which does not guarantee installation termination. No extra stage-00 hook or custom repeated-execution restriction. Native `finish-install` 2.124 snapshots its hook glob before execution. Stage 10 preseed retained, 50/55 and 60 unchanged; 61 installs, 62 verifies, 63 checks markers, 64 ejects, 65 displays the original final message. Native 70–99 unchanged. No forced network backend or suppressed dialog. Sources: [Debian Trixie advanced preseed options](https://www.debian.org/releases/trixie/amd64/apbs05.en.html), [finish-install 2.124](https://sources.debian.org/src/finish-install/2.124/debian/postinst), [Simple-CDD 0.6.9](https://sources.debian.org/src/simple-cdd/0.6.9/debian/14simple-cdd). Runtime hook availability, partitioner re-entry, Back/failure behavior and normal finish/reboot require VM validation.

**Native operation status (2026-11-20):** Stage 61 initially updates Debian's native finish-install progress display using `db_progress INFO`. cdebconf 0.280 GTK replaces an existing bar on a new START, and the protocol can return success for INFO even when the bar was destroyed. After a handoff to the existing native APT/anna-install UI, start a separate native custom progress bar between native transactions, with a range equal to the selected profile count and SET equal to the number whose success markers have been written. Stop only the custom bar before another native transaction, failure or hook exit. This does not restore Debian's already-replaced outer bar. Status labels show actual operation/profile and firmware candidate count, not estimated completion time. No terminal widget, concurrent protocol writers, raw command arguments, credentials or new confirmation prompts. Native APT progress and prior review/error paths remain unchanged. GTK/text rendering requires VM testing.

**Outcome:** implement the part of the custom ISO that loads the real Simple-CDD checkboxes, asks for explicit approval, runs **only selected** profile functions and blocks misleading “Installation complete” messages when a feature fails.

**Before this chapter:** create the Simple-CDD project from [Build project](build_project.md) and shared helpers from [Shared profile helpers](profile_construction.md). This framework still needs the actual feature modules and their `.extra` manifests before it can build a complete image.

## Step 1 — Make the source directories

From `99_custom_netintst/my-cdd/`:

~~~sh
mkdir -p installer profiles
~~~

This creates the folders in which the installer code and media lists belong; it does not change your running Debian system.

## Step 2 — Create the shared media manifest and preseed

| File | Purpose |
| --- | --- |
| `profiles/default.extra` | Copies the shared hooks, templates, selector, dispatcher, APT interaction helper and generated defaults onto the ISO. |
| `profiles/default.preseed` | Uses Simple-CDD's original early profile question and Debian Installer's native finish-install hook sequence; no custom late command. |

Open each named file in a text editor, paste its **complete listing** from below, review the contents and save it at the specified path. The important distinction is timing: early selection records consent; the stage-61 native finish-install hook works on the installed Debian system under `/target`.

## Step 3 — Create early selection and native consent

| File | Purpose |
| --- | --- |
| `installer/profile-confirm.templates` | Defines native cdebconf questions for combined selection summary/confirmation, omissions, destructive ZRAM scope and targeted swapoff. Package approvals are generated from actual APT output by the helper. Approval defaults to **No**. |
| `installer/profile-confirm.sh` | Loads the *real* generated Simple-CDD choices, validates each name and dependency, displays a complete selected/unselected summary and stores the exact approved selection. |

Paste the complete matching listings below. The early hook must run **before** `anna-install simple-cdd-profiles`; otherwise the selection cannot be reviewed first. The existing Debian Installer GUI and text frontend own these dialogs.

## Step 4 — Create the late dispatcher and failure guard

| File | Purpose |
| --- | --- |
| `installer/run-selected.sh` | Supplies native Debconf review, command diagnostics and execution of the approved selected handlers at stage `61my-cdd`; writes an individual success marker after each selected handler returns successfully and an overall final status. |
| `installer/apt-interactive.pl` | Temporary target-side APT prompt relay and actual pre-install action fallback, reusing native progress and Debconf passthrough. |
| `installer/finish-order.sh` | Relocates the three unchanged native hooks via `partman/early_command` before partitioning. |
| `installer/63my-cdd-status` | Finish-install hook that backs up if selection confirmation, final `COMPLETE` status or any selected profile's success marker is missing. |

Paste all four entire listings below. **Do not trim `run-selected.sh` down to the short dispatcher excerpt.** It preserves native transaction approval and direct command failures, without a project-defined package-removal blacklist, APT operation whitelist, or unrelated environment preflights. Target stderr is redirected to stdout **inside the `in-target` chroot**, because Debian Installer otherwise sends it only to syslog. On failure, the native GTK/text note shows the failed command, return status, recognized APT/dpkg error lines and the last 100 lines of actual command output. The complete log is still retained in `/target/var/log/installer/my-cdd.log`. The guard uses Debian Installer's finish-install **exit status 10**, not a generic shell exit 1.

Each optional profile also has a native executable `profiles/<name>.postinst` verification script, whose complete source appears in its feature construction guide. The original Simple-CDD hook, relocated from `14simple-cdd` to `62simple-cdd`, executes selected verifiers within the target, not the installation handlers again. Enable executable permissions on those seven `.postinst` files, but not on the sourced feature handlers.

Mark the shared **entry points** as executable:

~~~sh
chmod +x installer/profile-confirm.sh installer/run-selected.sh installer/63my-cdd-status installer/finish-order.sh installer/apt-interactive.pl
~~~

The ordinary `installer/<profile>.sh` feature modules are *sourced*, and should not be given a separate entry point.

## Step 5 — Check the framework

~~~sh
sh -n installer/finish-order.sh
~~~

~~~sh
sh -n installer/profile-confirm.sh
~~~

This checks only the early hook's shell syntax; it does not show a GUI.

~~~sh
sh -n installer/run-selected.sh
~~~

This parses the late dispatcher without performing APT work or disk writes.

~~~sh
perl -c installer/apt-interactive.pl
~~~

This checks the temporary APT interaction helper's Perl syntax without starting an APT transaction. It uses the target's existing Perl and the unmodified progress wrapper; it does not run in the minimal udeb environment.

~~~sh
sh -n installer/63my-cdd-status
~~~

This checks the finish-install guard's syntax.

The APT helper is staged in a private temporary directory in `/target/tmp` for each real package transaction and removed afterwards. APT keeps its original progress-wrapper PID so cancellation signals reach APT. Its own English prompt is recognized with C locale, quiet level 0, color/PTY disabled and versions displayed; native package Debconf uses the existing passthrough. Only a recognized transaction question can receive an affirmative response, default is No, and the fallback hook is transaction-scoped. No permanent APT configuration is installed.

The complete files depend on [Shared profile helpers](profile_construction.md) and the seven feature functions. **Don't test a partial copy by executing it on your build host.** To test behavior, assemble the feature files, build the ISO and use a disposable VM.

## Step 6 — Understand the required integration

1. `profiles/default.preseed` loads generated editable defaults, then **early** selection and consent.
2. The accepted profile list is stored only in private installer work data. The generated preseed sets `passwd/root-login=false`, so native Debian account setup skips the initial root password fields and gives the first user sudo. Before optional profile operations, the late dispatcher verifies that the new account really belongs to the sudo group and that sudo exists; it then asks for a separate local root recovery password through Debian's own password questions.
3. Before **native** partitioning, `partman/early_command` checks and relocates the three native scripts. Debian continues with its native partitioning, mirror, accounts and tasksel screens.
4. Debian Installer runs native **`10apt-cdrom-setup`** with the unconditional `apt-setup/disable-cdrom-entries=true` setting, then native 50/55 network configuration, then 60cleanup, then the registered **`61my-cdd`** runner and relocated upstream **`62simple-cdd`**. The runner confirms the approved selection, establishes local root recovery and executes handlers in order: Debian tweaks → Backports → kernel → firmware → ZRAM → OMV → Docker. It never calls the CD-ROM hook again.
5. After each selected handler returns successfully, the runner writes its individual completion record. Only after **all** approved handlers succeed does it write overall `COMPLETE`. Relocated native `62simple-cdd` executes each selected executable `profiles/<name>.postinst` in-target to verify the record without rerunning the installer handler.
6. The final `63my-cdd-status` verifies the confirmed selection, overall `COMPLETE` and the presence of a completion marker **for every selected profile**. It returns native finish-install **exit 10** on failure, preventing an erroneous success screen.

**Next:** implement each feature from its chapter, run [Validation](validation_and_pending.md), and **test approvals and failure paths before production use**.

## Complete, copyable source files

Expand the file you want to create. **These are full files, not fragments.** Copy the contents between the code fences into the **exact path named in the heading**. After saving, use `git hash-object <path>` to calculate that file's Git blob SHA and compare it with the original SHA shown in the heading; a match proves a byte-for-byte copy. The command reads the file but makes no edits.


<details>
<summary><strong>Complete file: profiles/default.extra</strong> (11 lines, current Git blob <code>44ae9b4fe3ab6a3149e0f8a67be8eb838ae731f0</code>)</summary>

````text
# Common installer source assets for every build; copied by Simple-CDD.
# Each optional profile declares its own sources via a profile-specific .extra.
tmp/generated/defaults.preseed
installer/profile-confirm.sh
installer/profile-confirm.templates
installer/ordered-selection.sh
installer/run-selected.sh
installer/apt-interactive.pl
installer/profile-common.sh
installer/63my-cdd-status
installer/finish-order.sh
````

</details>


<details>
<summary><strong>Complete file: profiles/default.preseed</strong> (22 lines, current Git blob <code>a952c99bccedd032e05ca97c75456c7ddad4d832</code>)</summary>

````text
# my-cdd minimal default profile for Debian 13.
# Preserve ordinary interactive Debian Installer questions (locale, keyboard,
# networking/mirror, users, manual OS disk/partitions, tasksel and completion).
#
# Read the per-build editable defaults generated from profile_defaults.conf.
# This file is on the ISO under /cdrom/simple-cdd, next to default.preseed.
# Locale and keyboard defaults are set earlier via kernel boot parameters.
d-i preseed/include string defaults.preseed
#
# Decision approved 2026-11-14: early preseed hook, not a patched udeb.
# The script loads Simple-CDD's own generated multiselect and my-cdd's
# summary/confirmation templates before anna-install queues any profiles.
# Its failure MUST prevent anna-install from running.
# The upstream simple-cdd-profiles component remains unmodified.
d-i preseed/early_command string /bin/sh /cdrom/simple-cdd/profile-confirm.sh && anna-install simple-cdd-profiles
# Relocate only the three native hooks before the partitioner starts.
d-i partman/early_command string /bin/sh /cdrom/simple-cdd/finish-order.sh
# Let Debian Installer's existing finish-install hook order handle this:
# 10apt-cdrom-setup disables CD-ROM APT sources once. Native networking
# and stage 60 cleanup finish before 61my-cdd; native verifiers, eject
# and final-message follow at 62, 64 and 65. No backend or dialog override.
d-i apt-setup/disable-cdrom-entries boolean true
````

</details>


<details>
<summary><strong>Complete file: installer/profile-confirm.sh</strong> (130 lines, current Git blob <code>de6ae81dc7e1899d938a736dee34d4140dd05bca</code>)</summary>

````sh
#!/bin/sh
# Approved method A (2026-11-14): run in preseed/early_command BEFORE
# anna-install simple-cdd-profiles. Do not patch the upstream udeb.
# This script handles selection and confirmation only; it changes no APT,
# target partition, installed user/account, or optional profile state.
set -eu

CDDIR=/cdrom/simple-cdd
ORDER_HELPER="$CDDIR/ordered-selection.sh"
TEMPLATE_SIMPLE="$CDDIR/simple-cdd.templates"
TEMPLATE_CONFIRM="$CDDIR/profile-confirm.templates"
FINISH_RUNNER="$CDDIR/run-selected.sh"
FINISH_GUARD="$CDDIR/63my-cdd-status"

stop() {
    printf >&2 'my-cdd early profile gate: STOP: %s\n' "$*"
    exit 1
}
for required in "$ORDER_HELPER" "$TEMPLATE_SIMPLE" "$TEMPLATE_CONFIRM" "$FINISH_RUNNER" "$FINISH_GUARD"; do
    [ -r "$required" ] || stop "missing installer-media source: $required"
done
command -v debconf-loadtemplate >/dev/null 2>&1 ||
    stop 'debconf-loadtemplate is not available in the installer'

# Use Debian Installer's existing finish-install hook order:
# 10apt-cdrom-setup -> 50/55 networking -> 60cleanup -> 61my-cdd.
# Native verification/eject/final-message are relocated separately by
# partman/early_command before partitioning.
# Register the selected-profile runner and final completion gate here,
# before finish-install enumerates its hooks. Do not patch upstream scripts.
mkdir -p /usr/lib/finish-install.d ||
    stop 'Cannot locate Debian Installer finish-install hook directory'
cp "$FINISH_RUNNER" /usr/lib/finish-install.d/61my-cdd ||
    stop 'Cannot register selected-profile finish-install hook'
chmod 755 /usr/lib/finish-install.d/61my-cdd ||
    stop 'Cannot make selected-profile hook executable'
cp "$FINISH_GUARD" /usr/lib/finish-install.d/63my-cdd-status ||
    stop 'Cannot register custom finish-install completion gate'
chmod 755 /usr/lib/finish-install.d/63my-cdd-status ||
    stop 'Cannot make finish-install completion gate executable'

# Generated simple-cdd.templates has the actual Choices and empty Defaults.
# Load both template families explicitly; the original profile udeb has NOT
# been installed, so we must not assume its template is already registered.
debconf-loadtemplate simple-cdd "$TEMPLATE_SIMPLE" ||
    stop 'could not load upstream Simple-CDD profile question'
debconf-loadtemplate my-cdd "$TEMPLATE_CONFIRM" ||
    stop 'could not load the optional-profile summary questions'
. /usr/share/debconf/confmodule

ask_profiles() {
    # Ensure a normal, explicit seven-choice multiselect is actually shown.
    # Do not silently leave a previously seen/auto-selected value.
    db_fset simple-cdd/profiles seen false || return 1
    db_input high simple-cdd/profiles || return 1
    db_go || return 1
}

status_of() {
    case " $ordered " in
        *" $1 "*) profile_status='Selected' ;;
        *) profile_status='Not selected' ;;
    esac
}

display_summary() {
    status_of debian-tweaks
    db_subst my-cdd/profile-confirm MYCDD_TWEAKS "$profile_status" || return 1
    status_of backports
    db_subst my-cdd/profile-confirm MYCDD_BACKPORTS "$profile_status" || return 1
    status_of ensure-7x-kernel
    db_subst my-cdd/profile-confirm MYCDD_KERNEL "$profile_status" || return 1
    status_of extended-device-support
    db_subst my-cdd/profile-confirm MYCDD_FIRMWARE "$profile_status" || return 1
    status_of zram-writeback
    db_subst my-cdd/profile-confirm MYCDD_ZRAM "$profile_status" || return 1
    status_of openmediavault
    db_subst my-cdd/profile-confirm MYCDD_OMV "$profile_status" || return 1
    status_of docker
    db_subst my-cdd/profile-confirm MYCDD_DOCKER "$profile_status" || return 1

    # All substitutions are single-line tokens: no embedded newline in
    # the line-oriented Debconf SUBST protocol.
    return 0
}

ask_profiles || stop 'selection screen unavailable or cancelled; no profile operations may start'
while :; do
    db_get simple-cdd/profiles || stop 'cannot read selected profiles'
    selected=$RET
    if ! ordered="$(/bin/sh "$ORDER_HELPER" "$selected")"; then
        db_fset my-cdd/profile-invalid seen false ||
            stop 'could not display the invalid-selection message'
        db_input critical my-cdd/profile-invalid ||
            stop 'invalid selection; profile question cannot be shown'
        db_go || stop 'invalid selection not acknowledged'
        ask_profiles || stop 'could not return to profile selection'
        continue
    fi

    display_summary || stop 'cannot prepare profile confirmation'
    db_set my-cdd/profile-confirm false || stop 'cannot set safe No default'
    db_fset my-cdd/profile-confirm seen false || stop 'cannot reset confirmation question'
    db_input critical my-cdd/profile-confirm || stop 'confirmation unavailable or cancelled'
    db_go || stop 'confirmation cancelled'
    db_get my-cdd/profile-confirm || stop 'cannot read confirmation'
    if [ "$RET" = true ]; then
        # The unmodified Simple-CDD udeb normally loads this template and
        # db_input's the same question after anna-install. Keep its already
        # answered value "seen" to avoid asking twice. This behavior must
        # be confirmed against actual Trixie GTK/text installer frontends.
        db_fset simple-cdd/profiles seen true ||
            stop 'cannot preserve approved selection for upstream Simple-CDD'
        # Preserve the exact user-approved set for the late native installer
        # executor; it must never reconstruct or expand selections by guesswork.
        umask 077
        printf '%s\n' "$ordered" > /tmp/my-cdd-confirmed-profiles ||
            stop 'Cannot persist the confirmed selection for finish-install'
        if [ -n "$ordered" ]; then
            printf '%s\n' "my-cdd early profile gate: confirmed profiles: $ordered"
        else
            printf '%s\n' 'my-cdd early profile gate: confirmed base Debian only'
        fi
        exit 0
    fi

    # An explicit No is a request to revisit the same original multiselect.
    # Never enable the kernel profile on ZRAM's behalf or add any profile.
    ask_profiles || stop 'could not return to profile selection'
done
````

</details>


<details>
<summary><strong>Complete file: installer/profile-confirm.templates</strong> (95 lines, current Git blob <code>29ab30727e65114f2a84c5ff0664baadf9b9f711</code>)</summary>

````text
# Native Debconf templates for the user-approved early preseed confirmation.
# Loaded by /cdrom/simple-cdd/profile-confirm.sh BEFORE the original
# anna-install simple-cdd-profiles command; the upstream udeb is unmodified.

Template: my-cdd/profile-confirm
Type: boolean
Default: false
Description: Proceed with these profiles?
 Review all seven profiles in execution order:
 .
  Debian tweaks: ${MYCDD_TWEAKS}
  Backports: ${MYCDD_BACKPORTS}
  Ensure Linux 7.x kernel: ${MYCDD_KERNEL}
  Extended device support: ${MYCDD_FIRMWARE}
  ZSTD ZRAM writeback: ${MYCDD_ZRAM}
  OpenMediaVault 8: ${MYCDD_OMV}
  Docker: ${MYCDD_DOCKER}
 .
 Select No to change the selection.
 .
 Package changes, destructive partition operations and individual
 firmware omissions still require their own approvals.

Template: my-cdd/profile-invalid
Type: note
Description: Invalid or incomplete custom profile selection
 The selected profiles could not be validated. ZRAM requires the Ensure
 Linux 7.x profile to be separately selected; unknown profile names are
 not accepted. Return to profile selection and correct the choice.
 Nothing has been enabled automatically.

Template: my-cdd/approve-omission
Type: boolean
Default: false
Description: Approve omission of ${MYCDD_PACKAGE}?
 Reason: ${MYCDD_REASON}
 .
 This approval applies ONLY to this named firmware/microcode package.
 Choose No to stop instead of silently dropping it from the installation.

Template: my-cdd/zram-backing-select
Type: select
Choices-C: ${MYCDD_BACKING_IDS}
Choices: ${MYCDD_BACKING_LABELS}
Default: none
Description: Select the partition for ZRAM raw writeback backing
 No swap partition could be identified uniquely from this installation's
 /etc/fstab. Select the specific swap or previously converted raw backing
 partition you wish to use. Partitions may belong to another operating
 system; using one can permanently disrupt that other system.
 .
 The first choice stops without changing any partition. Selecting a
 partition does NOT approve its conversion; a separate confirmation follows.

Template: my-cdd/zram-destructive
Type: boolean
Default: false
Description: Convert the selected partition to ZRAM backing?
  Partition: ${MYCDD_PARTITION}
  Parent disk: ${MYCDD_DISK}
  Capacity: ${MYCDD_SIZE}
  PARTUUID: ${MYCDD_PARTUUID}
  Selection: ${MYCDD_SELECTION}
 .
 Only this partition is changed:
 .
  Erase its first 1 MiB and existing swap signature.
  Set GPT type to Linux data (8300).
  Set PARTLABEL to zram-writeback.
  Remove its old swap activation and obsolete resume reference.
 .
 Existing data in the erased area will be lost. Reusing this partition
 may break swap in another operating system.
 .
 No filesystem is created. Select No to stop without conversion.

Template: my-cdd/zram-swapoff
Type: boolean
Default: false
Description: Deactivate the selected swap partition?
  Partition: ${MYCDD_PARTITION}
  Used swap: ${MYCDD_USED} bytes
 .
 Moving these pages into RAM may cause memory pressure or failure.
 Only the selected partition will be passed to swapoff.
 .
 Select No to stop before conversion.

Template: my-cdd/progress
Type: text
Description: ${MYCDD_STATUS}

Template: my-cdd/progress-title
Type: text
Description: Configuring selected installation profiles
````

</details>


<details>
<summary><strong>Complete file: installer/run-selected.sh</strong> (415 lines, current Git blob <code>1897d71b861f4a1fea452c16c738b15ca17047b5</code>)</summary>

````sh
#!/bin/sh
# Debian Installer-side executor: native cdebconf, no patched udeb.
# Registered at 61my-cdd, after native network finalization and APT cleanup.
set -eu
umask 077
MEDIA=/cdrom/simple-cdd
LOG_DIR=/target/var/log/installer
LOG="$LOG_DIR/my-cdd.log"
STATUS="$LOG_DIR/my-cdd-status"
WORK=/tmp/my-cdd-install
CONFIRMED=/tmp/my-cdd-confirmed-profiles
mkdir -p "$WORK"
chmod 700 "$WORK"
[ -d /target/etc ] || { echo 'my-cdd: target missing' >&2; exit 1; }
mkdir -p "$LOG_DIR/my-cdd-completed"
chmod 700 "$LOG_DIR/my-cdd-completed"
touch "$LOG"
chmod 600 "$LOG"
printf "INCOMPLETE\n" > "$STATUS"
chmod 600 "$STATUS"
log() { printf '%s\n' "$*" >> "$LOG"; }
FAILED_CAPTURE_COMMAND=''
FAILED_CAPTURE_STATUS=''
capture() {
    # in-target uses log-output: --pass-stdout forwards stdout, but stderr
    # goes to installer syslog. Redirect stderr *inside* the target so both
    # streams reach our command log and can be shown in the GTK/text dialog.
    FAILED_CAPTURE_COMMAND=''
    FAILED_CAPTURE_STATUS=''
    if [ "$1" = in-target ]; then
        shift
        command_label="in-target --pass-stdout $*"
        set -- in-target --pass-stdout /bin/sh -c 'exec "$@" 2>&1' my-cdd "$@"
    else
        command_label="$*"
    fi
    log "COMMAND: $command_label"
    if "$@" > "$WORK/output" 2>&1; then rc=0; else rc=$?; fi
    cat "$WORK/output" >> "$LOG"
    if [ "$rc" -ne 0 ]; then
        FAILED_CAPTURE_COMMAND=$command_label
        FAILED_CAPTURE_STATUS=$rc
    fi
    return "$rc"
}
export_log() {
    # Never repartition, remount the ISO, or guess which device is the USB.
    usb=/cdrom/my-cdd-logs
    if [ -d "$usb" ] && [ -w "$usb" ]; then
        case "$(findmnt -n -o OPTIONS --target "$usb" 2>/dev/null)" in
            *rw*) cp -- "$LOG" "$usb/my-cdd.log" &&
                log "Copied log to $usb/my-cdd.log" ||
                log 'Failed to copy log to writable USB directory' ;;
            *) log 'No writable installer-USB log destination' ;;
        esac
    else
        log 'No pre-existing writable installer-USB log directory'
    fi
}
# Must load current Debian Installer's GTK or text cdebconf frontend.
. /usr/share/debconf/confmodule
# Observational UI only. Native finish-install initially owns the bar.
# cdebconf GTK replaces (rather than nests) bars and may return success
# for INFO even when no bar remains. After handing off to native APT or
# anna, open our own bar between native transactions, never over them.
# Only caller-supplied single-line, non-secret status text reaches Debconf.
progress_context='Account recovery'
progress_detached=false
progress_owned=false
profile_total=0
profile_completed=0
progress_stop_local() {
    if [ "$progress_owned" = true ]; then
        db_progress STOP || :
        progress_owned=false
    fi
    return 0
}
progress_handoff() {
    progress_stop_local
    progress_detached=true
}
progress_status() {
    if [ "$progress_detached" = true ] && [ "$progress_owned" = false ] &&
       [ "$profile_total" -gt 0 ]; then
        if db_progress START 0 "$profile_total" my-cdd/progress-title; then
            progress_owned=true
        fi
    fi
    if db_subst my-cdd/progress MYCDD_STATUS "$1 [$progress_context]"; then
        db_progress INFO my-cdd/progress || :
        if [ "$progress_owned" = true ]; then
            # Count only successfully completed profiles, never fake time/percent.
            db_progress SET "$profile_completed" || :
        fi
    fi
    return 0
}
# Only close progress displays created by this script on unexpected exits.
trap 'progress_stop_local' 0
review_serial=0
show_dialog() {
    name=$1
    file=$2
    dialog_type=$3
    review_serial=$((review_serial + 1))
    q="my-cdd/review-$review_serial"
    template="$WORK/review-$review_serial.templates"
    {
        printf 'Template: %s\nType: %s\n' "$q" "$dialog_type"
        [ "$dialog_type" != boolean ] || printf 'Default: false\n'
        printf 'Description: %s\n' "$name"
        while IFS= read -r line || [ -n "$line" ]; do
            # Debconf needs TWO spaces for preformatted lines and a dot for
            # paragraph breaks. Preserve actual output and meaningful breaks.
            if [ -z "$line" ]; then echo ' .'; else printf '  %s\n' "$line"; fi
        done < "$file"
    } > "$template"
    debconf-loadtemplate my-cdd "$template" || return 1
    if [ "$dialog_type" = boolean ]; then db_set "$q" false || return 1; fi
    db_fset "$q" seen false || return 1
    db_input critical "$q" || return 1
    db_go || return 1
    if [ "$dialog_type" = boolean ]; then
        db_get "$q" || return 1
        [ "$RET" = true ] || return 1
    fi
    return 0
}
show_note() { show_dialog "$1" "$2" note; }
fatal() {
    progress_stop_local
    printf "FAILED\n" > "$STATUS"
    log "FATAL: $*"
    {
        printf 'Installation stopped: %s\n' "$*"
        if [ -n "$FAILED_CAPTURE_COMMAND" ]; then
            printf '\nFAILED COMMAND: %s\nEXIT STATUS: %s\n' \
                "$FAILED_CAPTURE_COMMAND" "$FAILED_CAPTURE_STATUS"
            printf '\nACTUAL COMMAND OUTPUT (including stderr; last 100 lines):\n'
            if [ -s "$WORK/output" ]; then
                # Put recognizable APT/dpkg errors at the top of the dialog
                # before any lengthy contextual output.
                if grep -E '^(Err:|E:|W:|Error:|ERROR:|dpkg: error:|fatal:)' \
                    "$WORK/output" > "$WORK/errors"; then
                    echo 'Reported error/warning lines:'
                    tail -n 30 "$WORK/errors"
                    echo
                fi
                tail -n 100 "$WORK/output"
            else
                echo 'No output was captured from the failed command.'
                if [ -r /var/log/syslog ]; then
                    echo 'Recent installer syslog entries:'
                    tail -n 30 /var/log/syslog
                fi
            fi
        else
            echo
            echo 'RECENT INSTALLER LOG:'
            tail -n 70 "$LOG"
        fi
        echo
        echo "Full unredacted diagnostics: $LOG"
        echo 'The installer USB is not assumed writable.'
        echo 'Manual log export: use an installer shell and a verified,'
        echo 'already-mounted writable removable data location.'
    } > "$WORK/failure"
    show_note 'Custom profile failure and recovery' "$WORK/failure" || true
    cat "$WORK/failure" >&2
    export_log || true
    exit 1
}
yes_no() {
    db_set "$1" false || fatal "Cannot reset $1"
    db_fset "$1" seen false || fatal "Cannot display $1"
    db_input critical "$1" || fatal "Prompt unavailable: $1"
    db_go || fatal "Prompt cancelled: $1"
    db_get "$1" || fatal "Cannot read response: $1"
    [ "$RET" = true ]
}
apt_interactive() {
    # Stage only this transaction's helper in a private target directory.
    # The helper uses target Perl already required by debconf-apt-progress.
    apt_work="$(mktemp -d /target/tmp/my-cdd-apt.XXXXXX)" ||
        fatal 'Cannot create temporary APT approval directory'
    apt_path=${apt_work#/target}
    cp "$MEDIA/apt-interactive.pl" "$apt_work/apt-interactive.pl" &&
        chmod 700 "$apt_work/apt-interactive.pl" ||
        fatal 'Cannot stage temporary APT approval helper'
    {
        printf '%s\n\nCommand: apt-get %s\n' "${APT_REVIEW_LABEL:-$progress_context}" "$*"
        if [ -n "${APT_REVIEW_FILE:-}" ]; then
            printf '\n'
            cat "$APT_REVIEW_FILE"
        fi
    } > "$apt_work/context" || fatal 'Cannot prepare APT approval context'
    cat "$apt_work/context" >> "$LOG"
    if capture in-target debconf-apt-progress --logstderr -- "$apt_path/apt-interactive.pl" "$@"; then
        apt_result=0
    else
        apt_result=$?
    fi
    apt_decision=''
    if [ -f "$apt_work/decision" ]; then apt_decision="$(cat "$apt_work/decision")"; fi
    rm -f "$apt_work/apt-interactive.pl" "$apt_work/context" "$apt_work/decision" &&
        rmdir "$apt_work" || log 'Could not remove temporary APT approval directory'
    if [ "$apt_result" -ne 0 ]; then
        case "$apt_decision" in
            declined) fatal "Package transaction declined by user: apt-get $*" ;;
            cancelled) fatal "Package transaction confirmation cancelled: apt-get $*" ;;
            unavailable) fatal "Package transaction approval unavailable: apt-get $*" ;;
            *) [ "$apt_result" != 30 ] || fatal "Package transaction cancelled: apt-get $*"
               fatal "Target APT transaction failed: apt-get $*" ;;
        esac
    fi
    if [ "$apt_decision" = approved ]; then
        log "USER APPROVED ACTUAL APT TRANSACTION: apt-get $*"
    fi
}
run_target() {
    # Preserve native APT progress and ask about the real state-changing
    # package transaction, not a separate simulated transaction.
    if [ "$1" = apt-get ]; then
        if [ "$2" = update ]; then
            progress_status 'Updating package indexes'
            progress_handoff
            capture in-target debconf-apt-progress --logstderr -- "$@" ||
                fatal "Target APT index refresh failed: $*"
        else
            progress_status 'Resolving package changes'
            progress_handoff
            shift
            apt_interactive "$@"
        fi
    else
        case "$1" in
            update-grub) progress_status 'Regenerating GRUB configuration' ;;
            update-initramfs) progress_status 'Regenerating initramfs images' ;;
            dpkg) progress_status 'Checking or updating package state' ;;
            systemctl) progress_status 'Applying service configuration' ;;
            *) progress_status 'Applying target configuration' ;;
        esac
        capture in-target "$@" || fatal "Target command failed: $*"
    fi
}
simulate_target() {
    progress_status 'Checking package dependency compatibility'
    capture in-target apt-get -s "$@" ||
        fatal "APT simulation failed: apt-get -s $*"
    cp "$WORK/output" "$WORK/plan"
}
review_install() {
    apt_label=$1
    shift
    APT_REVIEW_LABEL="$apt_label" run_target apt-get install "$@"
    run_target dpkg --audit
}
report_omission() {
    db_subst my-cdd/approve-omission MYCDD_PACKAGE "$1" ||
        fatal 'Cannot present named omission'
    db_subst my-cdd/approve-omission MYCDD_REASON "$2" ||
        fatal 'Cannot present omission reason'
    if yes_no my-cdd/approve-omission; then
        log "USER APPROVED OMISSION: $1; reason: $2"
    else
        fatal "Omission declined: $1"
    fi
}
[ -r "$MEDIA/profile-common.sh" ] || fatal 'Missing shared profile helpers'
[ -r "$MEDIA/ordered-selection.sh" ] || fatal 'Missing selection validator'
[ -r "$CONFIRMED" ] || fatal 'No approved early profile selection was recorded'
. "$MEDIA/profile-common.sh"

# No unconditional target policy changes in the base-only installation.
# Optional changes run only after explicitly selected profile confirmation.
# Check rescue/emergency-console access BEFORE running any selected profile.
# Debian Installer may create a sudo-capable user while leaving root locked.
# A local root password is needed by the normal sulogin recovery console.
# Use the existing Debian Installer password-type Debconf questions; never
# log or write a password to a preseed, the ISO, or a command argument.
ensure_root_recovery() {
    # The native passwd/root-login=false preseed grants the first ordinary
    # account sudo. Verify it rather than granting sudo to an unexpected
    # account silently.
    db_get passwd/username || fatal 'Cannot read the native installer username'
    recovery_user=$RET
    [ -n "$recovery_user" ] || fatal 'Missing installer-created admin account'
    capture in-target id -nG "$recovery_user" ||
        fatal 'Installer-created admin account is unavailable'
    case " $(cat "$WORK/output") " in
        *' sudo '*) log 'Verified native sudo administrator account' ;;
        *) fatal 'Installer-created user is not in sudo group; verify native passwd/root-login=false preseed' ;;
    esac
    capture in-target sh -c 'command -v sudo >/dev/null 2>&1' ||
        fatal 'sudo is not available in the installed target'
    capture in-target passwd -S root ||
        fatal 'Cannot inspect installed root account for emergency recovery'
    root_state="$(awk '$1 == "root" { print $2 }' "$WORK/output")"
    case "$root_state" in
        P)
            log 'Emergency recovery preflight: local root password already configured'
            return 0 ;;
        L|NP)
            log 'Emergency recovery preflight: root is locked or has no password' ;;
        *)
            fatal 'Unrecognized root account password state; refusing optional operations' ;;
    esac

    # These are native user-setup-udeb templates, not project custom files.
    # Native user-setup clears them after initial account creation; clear them
    # again before and immediately after each attempt.
    for recovery_question in passwd/root-password passwd/root-password-again; do
        db_set "$recovery_question" '' ||
            fatal 'Cannot clear temporary root-password question'
    done
    while :; do
        for recovery_question in passwd/root-password passwd/root-password-again; do
            db_fset "$recovery_question" seen false ||
                fatal 'Cannot show the native root-password prompt'
            db_input critical "$recovery_question" ||
                fatal 'Native root-password prompt unavailable'
        done
        db_go || fatal 'Root-password prompt was cancelled'
        db_get passwd/root-password || fatal 'Cannot read the new root password'
        root_password=$RET
        db_get passwd/root-password-again || fatal 'Cannot read the confirmation password'
        root_confirmation=$RET
        # Never leave credentials in the installer Debconf database.
        db_set passwd/root-password '' || fatal 'Cannot clear root password from Debconf'
        db_set passwd/root-password-again '' || fatal 'Cannot clear root password confirmation'

        recovery_error=''
        if [ -z "$root_password" ]; then
            recovery_error='A non-empty local root password is required for rescue and emergency access.'
        elif [ "$root_password" != "$root_confirmation" ]; then
            recovery_error='The two root passwords did not match. Please re-enter both values.'
        elif printf '%s' "$root_password" | LC_ALL=C grep -q '[[:cntrl:]]'; then
            recovery_error='The password contains unsupported control characters. Please choose another.'
        fi
        root_confirmation=''
        if [ -n "$recovery_error" ]; then
            root_password=''
            printf '%s\n' "$recovery_error" > "$WORK/root-recovery-explanation"
            show_note 'Local emergency recovery password required' "$WORK/root-recovery-explanation" ||
                fatal 'Cannot display password correction request'
            continue
        fi
        # in-target reserves stdin for its Debconf passthrough. Feed chpasswd
        # through a direct target chroot instead; no secret enters argv, a
        # temporary file, or the custom installer logs.
        if printf 'root:%s\n' "$root_password" | capture chroot /target /usr/sbin/chpasswd; then
            password_changed=true
        else
            password_changed=false
        fi
        root_password=''
        [ "$password_changed" = true ] ||
            fatal 'Failed to establish local root recovery password'
        capture in-target passwd -S root ||
            fatal 'Cannot verify new local root password'
        grep -E '^root[[:space:]]+P[[:space:]]' "$WORK/output" >/dev/null ||
            fatal 'Root account remains locked after password setup'
        log 'Emergency recovery preflight: usable local root password confirmed'
        return 0
    done
}

db_get simple-cdd/profiles || fatal 'Cannot read Simple-CDD profile selection'
ordered="$(/bin/sh "$MEDIA/ordered-selection.sh" "$RET")" ||
    fatal 'Invalid selected profiles or missing kernel prerequisite'
[ "$ordered" = "$(cat "$CONFIRMED")" ] ||
    fatal 'Selection changed after approval; do not run unapproved profiles'
db_get my-cdd/profile-confirm || fatal 'Missing early summary approval'
[ "$RET" = true ] || fatal 'The early profile summary was not approved'
log "CONFIRMED SELECTION: $ordered"

progress_status 'Verifying administrator and recovery access'
ensure_root_recovery

# Count only the approved profiles, maintaining their existing fixed order.
profile_total=0
for profile in $ordered; do profile_total=$((profile_total + 1)); done
profile_index=0
for profile in $ordered; do
    profile_index=$((profile_index + 1))
    progress_context="$profile (profile $profile_index/$profile_total)"
    progress_status 'Preparing selected profile'
    log "PROFILE BEGIN: $profile"
    case "$profile" in
        debian-tweaks) module=debian-tweaks; handler=profile_tweaks ;;
        backports) module=backports; handler=profile_backports ;;
        ensure-7x-kernel) module=ensure-7x-kernel; handler=profile_kernel ;;
        extended-device-support) module=extended-device-support; handler=profile_firmware ;;
        zram-writeback) module=zram-writeback; handler=profile_zram ;;
        openmediavault) module=openmediavault; handler=profile_omv ;;
        docker) module=docker; handler=profile_docker ;;
        *) fatal "Unknown selected profile: $profile" ;;
    esac
    [ -r "$MEDIA/$module.sh" ] || fatal "Missing selected module: $module"
    . "$MEDIA/$module.sh"
    "$handler"
    printf 'Completed: %s\n' "$profile" > "$LOG_DIR/my-cdd-completed/$profile"
    chmod 600 "$LOG_DIR/my-cdd-completed/$profile"
    log "PROFILE COMPLETE: $profile"
    profile_completed=$profile_index
    progress_status 'Completed'
done
progress_context='Custom installation'
progress_status 'Finalizing completion records'
log 'All selected optional profiles completed.'
printf 'COMPLETE\n' > "$STATUS"
export_log
progress_stop_local
exit 0
````

</details>


<details>
<summary><strong>Complete file: installer/63my-cdd-status</strong> (24 lines, current Git blob <code>71a504dd9b6491fffc1bb991148596deb38e1acd</code>)</summary>

````sh
#!/bin/sh
# Debian Installer finish-install stage 63, after native Simple-CDD stage 62.
# Keep native per-profile postinst checks and independently check each approved
# profile's completion marker. Exit 10 stops a misleading success screen.
set -eu
status=/target/var/log/installer/my-cdd-status
confirmed=/tmp/my-cdd-confirmed-profiles
markers=/target/var/log/installer/my-cdd-completed

if [ -f "$status" ] && [ "$(cat "$status")" = COMPLETE ] &&
   [ -r "$confirmed" ]; then
    valid=true
    for profile in $(cat "$confirmed"); do
        [ -f "$markers/$profile" ] || valid=false
    done
    if [ "$valid" = true ]; then
        exit 0
    fi
fi

logger -t my-cdd 'Selected profiles did not all complete; returning to main menu' || :
printf >&2 '%s\n' 'my-cdd: selected profiles did not all complete. See /target/var/log/installer/my-cdd.log and my-cdd-status.' \
    'Returning to Debian Installer main menu instead of reporting Installation complete.'
exit 10
````

</details>

<details>
<summary><strong>Complete file: installer/apt-interactive.pl</strong> (175 lines, current Git blob <code>a706865ea5d30bcada661dfa94d7859bdacfffb4</code>)</summary>

````perl
#!/usr/bin/perl
# Temporary target-side command for Debian's native debconf-apt-progress.
# The APT process remains the original progress-wrapper child (including PID).
use strict;
use warnings;
use IO::Handle;
use IO::Select;
use File::Basename qw(dirname);
use POSIX ();

$^F = 6;
my $self = $0;
my $dir = dirname($self);
die "Invalid temporary APT helper path\n" unless $self =~ m{^/[A-Za-z0-9_./-]+$};

sub read_text {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot read $path: $!\n";
    local $/;
    return <$fh> // '';
}
sub decision_state {
    return -f "$dir/decision" ? read_text("$dir/decision") : '';
}
sub record_decision {
    my ($state) = @_;
    open my $fh, '>', "$dir/decision" or die "Cannot record APT decision: $!\n";
    print {$fh} $state or die "Cannot write APT decision: $!\n";
    close $fh or die "Cannot close APT decision: $!\n";
    print STDERR "APT transaction approval: $state\n";
}

# debconf-apt-progress already supplies and relays these two descriptors.
# Do not open a separate frontend, write to its parent shell's protocol, or
# replace the native package Debconf/progress mechanisms.
sub dc {
    my ($command) = @_;
    open my $out, '>&', 6 or die "Debconf write fd: $!\n";
    open my $in, '<&', 5 or die "Debconf read fd: $!\n";
    $out->autoflush(1);
    print {$out} "$command\n" or die "Debconf request failed: $!\n";
    my $reply = '';
    while (1) {
        my $n = sysread($in, my $c, 1);
        die "Debconf reply missing\n" unless defined($n) && $n == 1;
        last if $c eq "\n";
        $reply .= $c;
    }
    return $reply;
}
sub checked_dc {
    my $reply = dc($_[0]);
    die "Debconf rejected command: $reply\n" unless $reply =~ /^0(?: |$)/;
    return $reply;
}
sub encoded {
    my ($s) = @_;
    $s =~ s/[^\n]*\r//g; # omit overwritten progress counters, not transaction lines
    $s =~ s/[\x00-\x08\x0b-\x1f\x7f]//g;
    $s =~ s/\\/\\\\/g;
    $s =~ s/\n/\\n/g;
    return $s;
}
sub ask {
    my ($details) = @_;
    my $q = "my-cdd/apt-approval-$$";
    my $state = eval {
        my $heading = read_text("$dir/context");
        checked_dc("DATA $q type boolean");
        checked_dc("DATA $q description Apply these package changes?");
        checked_dc("DATA $q extended_description " . encoded("$heading\n\n$details"));
        checked_dc("SET $q false");
        checked_dc("FSET $q seen false");
        checked_dc("INPUT critical $q");
        my $go = dc('GO');
        if ($go =~ /^30(?: |$)/) { 'cancelled' }
        else {
            die "Debconf could not display approval: $go\n" unless $go =~ /^0(?: |$)/;
            my $reply = checked_dc("GET $q");
            if ($reply eq '0 true') { 'approved' }
            elsif ($reply eq '0 false') { 'declined' }
            else { die "Unexpected approval response\n"; }
        }
    };
    if ($@) { warn "APT approval unavailable: $@"; $state = 'unavailable'; }
    record_decision($state);
    return $state eq 'approved';
}

# APT can omit its ordinary yes/no prompt for explicitly requested changes.
# In that case use its actual Pre-Install-Pkgs protocol 2 action list before
# dpkg acts. Downloads may have finished. Already approved transactions do
# not prompt again. A failed or refused hook is a native APT failure.
sub preinstall {
    local $/;
    my $payload = <STDIN> // '';
    my ($header, $actions) = split /\n\n/, $payload, 2;
    die "Invalid APT pre-install protocol\n"
        unless defined($header) && $header =~ /^VERSION 2\n/ && defined($actions);
    print STDERR "Actual APT pre-install actions (protocol 2):\n$actions";
    my $state = decision_state();
    return $state eq 'approved' ? 0 : 1 if $state ne '';
    my @lines;
    for my $line (split /\n/, $actions) {
        my ($package, $old, $direction, $new, $action) = split ' ', $line, 5;
        if (defined $action) {
            $action = $action =~ m{^/} ? 'UNPACK' : $action;
            $action =~ s/^\*\*(.+)\*\*$/$1/;
            push @lines, "$package: $old $direction $new ($action)";
        } else { push @lines, $line; }
    }
    return ask("Actual package actions before dpkg runs (old version, direction, new version):\n\n"
        . join("\n", @lines) . "\n\nPackages may already have been downloaded.") ? 0 : 1;
}
exit preinstall() if @ARGV && $ARGV[0] eq '--pre-install';

# Keep APT's prompt language predictable without altering package Debconf's
# existing frontend or bypassing APT's own authentication/safety checks.
$ENV{LC_ALL} = 'C';
delete $ENV{LANGUAGE};
my $hook = "$self --pre-install";
pipe(my $apt_in, my $answer) or die "APT input pipe: $!\n";
pipe(my $output, my $apt_out) or die "APT output pipe: $!\n";
my $relay = fork();
die "APT relay fork: $!\n" unless defined $relay;
if ($relay) {
    close $answer; close $output;
    open STDIN, '<&', $apt_in or die "APT stdin: $!\n";
    open STDOUT, '>&', $apt_out or die "APT stdout: $!\n";
    open STDERR, '>&', \*STDOUT or die "APT stderr: $!\n";
    close $apt_in; close $apt_out;
    # Keep the original PID so debconf-apt-progress cancels APT itself.
    exec('apt-get', @ARGV, '-o', 'quiet=0', '-o', 'APT::Get::Assume-Yes=false',
        '-o', 'APT::Get::Show-Versions=true', '-o', 'APT::Color=false',
        '-o', 'Dpkg::Use-Pty=0', '-o', "DPkg::Pre-Install-Pkgs::=$hook",
        '-o', "DPkg::Tools::options::$self\::Version=2") or die "APT exec: $!\n";
}
# Do not keep APT's native status descriptor alive from the output relay.
POSIX::close(4);
close $apt_in; close $apt_out;
$answer->autoflush(1);
STDOUT->autoflush(1);
my $select = IO::Select->new($output, \*STDIN);
my $transcript = '';
while ($select->exists($output)) {
    for my $fh ($select->can_read()) {
        my $n = sysread($fh, my $data, 8192);
        die "APT relay read: $!\n" unless defined $n;
        if (!$n) { $select->remove($fh); next; }
        if (fileno($fh) == fileno($output)) {
            print $data;
            $transcript .= $data;
            # APT's real confirmation is flushed without a final newline.
            if ($transcript =~ /(?:^|\n)((?:Do you want to continue\?|Continue\?|Continue anyway\?) \[(?:Y\/n|y\/N)\] )$/) {
                my $prompt = $1;
                my $details = substr($transcript, 0, length($transcript)-length($prompt));
                my $ok = decision_state() eq '' && ask($details);
                print {$answer} ($ok ? "y\n" : "n\n") or die "APT response: $!\n";
                $transcript = '';
            } elsif ($transcript =~ /\[(?:Y\/n|y\/N)\] $/) {
                # Never answer yes to an unrecognized APT question.
                print {$answer} "n\n" or die "APT response: $!\n";
                $transcript = '';
            } elsif (decision_state() ne '' && length($transcript) > 1024) {
                # After a decision we only need the tail to recognize prompts.
                $transcript = substr($transcript, -1024);
            }
        } else {
            # Native debconf-apt-progress can send a media-change response.
            print {$answer} $data or die "APT media response: $!\n";
        }
    }
}
close $answer;
exit 0;
````

</details>

<details>
<summary><strong>Complete file: installer/finish-order.sh</strong> (15 lines, current Git blob <code>f5d3c3d46c65407e9cbf199b04c112c68a4883c4</code>)</summary>

````sh
#!/bin/sh
# Run via partman/early_command before native partitioning.
# Rename only the three existing native hooks in the installer ramdisk.
set -eu
cd /usr/lib/finish-install.d
# Check all original scripts before changing any filename.
for hook in 14simple-cdd 15cdrom-detect 20final-message; do
    if [ ! -f "$hook" ]; then
        printf >&2 'my-cdd: missing native finish-install hook: %s\n' "$hook"
        exit 1
    fi
done
mv 14simple-cdd 62simple-cdd
mv 15cdrom-detect 64cdrom-detect
mv 20final-message 65final-message
````
</details>
