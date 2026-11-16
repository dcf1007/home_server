# Installer framework — Build hooks, confirmations and the dispatcher

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
| `profiles/default.extra` | Copies the shared hooks, templates, selector, dispatcher and generated defaults onto the ISO. |
| `profiles/default.preseed` | Connects the original Debian Installer's `preseed/early_command` and `preseed/late_command` hooks to our own scripts without patching an installer udeb. |

Open each named file in a text editor, paste its **complete listing** from below, review the contents and save it at the specified path. The important distinction is timing: early command makes choices and records consent; late command works on the now-installed Debian system under `/target`.

## Step 3 — Create early selection and native consent

| File | Purpose |
| --- | --- |
| `installer/profile-confirm.templates` | Defines the real native cdebconf questions: summary, package approval, omissions, destructive ZRAM scope and targeted swapoff. Default for destructive decisions is **No**. |
| `installer/profile-confirm.sh` | Loads the *real* generated Simple-CDD choices, validates each name and dependency, displays a complete selected/unselected summary and stores the exact approved selection. |

Paste the complete matching listings below. The early hook must run **before** `anna-install simple-cdd-profiles`; otherwise the selection cannot be reviewed first. The existing Debian Installer GUI and text frontend own these dialogs.

## Step 4 — Create the late dispatcher and failure guard

| File | Purpose |
| --- | --- |
| `installer/run-selected.sh` | Supplies `capture`, `fatal`, target-APT simulation and review helpers; checks local root recovery access; sources and runs only selected functions; writes completion markers directly in the profile loop and retains failure logs. |
| `installer/15my-cdd-status` | Finish-install hook that blocks success if status is not `COMPLETE` or a selected marker is absent. |

Paste both entire listings below. **Do not trim `run-selected.sh` down to the short dispatcher excerpt.** Its review and error-handling code is necessary for safety. The guard uses Debian Installer's finish-install **exit status 10**, not a generic shell exit 1.

Mark only the actual **entry points** as executable:

~~~sh
chmod +x installer/profile-confirm.sh installer/run-selected.sh installer/15my-cdd-status
~~~

The ordinary `installer/profile-*.sh` feature modules are *sourced*, and should not be given a separate entry point.

## Step 5 — Check the framework

~~~sh
sh -n installer/profile-confirm.sh
~~~

This checks only the early hook's shell syntax; it does not show a GUI.

~~~sh
sh -n installer/run-selected.sh
~~~

This parses the late dispatcher without performing APT work or disk writes.

~~~sh
sh -n installer/15my-cdd-status
~~~

This checks the finish-install guard's syntax.

The complete files depend on [Shared profile helpers](profile_construction.md) and the seven feature functions. **Don't test a partial copy by executing it on your build host.** To test behavior, assemble the feature files, build the ISO and use a disposable VM.

## Step 6 — Understand the required integration

1. `profiles/default.preseed` loads generated editable defaults, then **early** selection and consent.
2. The accepted profile list is stored only in private installer work data. During native Debian account setup, leave the root-password fields empty so the first user is granted sudo. Before optional profile operations, the late dispatcher verifies that the new account really belongs to the sudo group and that sudo exists; it then asks for a separate local root recovery password through Debian's own password questions.
3. Debian continues with **native** partitioning, mirror, accounts and tasksel screens.
4. The **late** dispatcher verifies the original selection and usable local root recovery, prepares target APT, and sources the chosen handlers in fixed order. **Debian tweaks now runs first**, ahead of Backports, kernel, firmware and the destructive ZRAM stage.
5. Each handler completes **before** its marker is created; the corresponding `.postinst` checks that marker only.
6. Finish-install's status guard refuses a normal-success screen if the overall status or any selected marker is missing.

**Next:** implement each feature from its chapter, run [Validation](validation_and_pending.md), and **test approvals and failure paths before production use**.

## Complete, copyable source files

Expand the file you want to create. **These are full files, not fragments.** Copy the contents between the code fences into the **exact path named in the heading**. After saving, use `git hash-object <path>` to calculate that file's Git blob SHA and compare it with the original SHA shown in the heading; a match proves a byte-for-byte copy. The command reads the file but makes no edits.


<details>
<summary><strong>Complete file: profiles/default.extra</strong> (9 lines, current Git blob <code>8b604a4a6d11f85904e1cc5670713cd7d795721d</code>)</summary>

````text
# Common installer source assets for every build; copied by Simple-CDD.
# Each optional profile declares its own sources via a profile-specific .extra.
tmp/generated/defaults.preseed
installer/profile-confirm.sh
installer/profile-confirm.templates
installer/ordered-selection.sh
installer/run-selected.sh
installer/profile-common.sh
installer/15my-cdd-status
````

</details>


<details>
<summary><strong>Complete file: profiles/default.preseed</strong> (20 lines, current Git blob <code>0d5971206483997eaba0de1f4dc2f2f4c734100f</code>)</summary>

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
# Let Debian's own late finish-install cleanup also disable an installer-
# only CD-ROM APT source. The custom 07preseed hook needs to do it earlier
# when selected profiles use network APT before that cleanup runs.
d-i apt-setup/disable-cdrom-entries boolean true
d-i preseed/late_command string /bin/sh /cdrom/simple-cdd/run-selected.sh
````

</details>


<details>
<summary><strong>Complete file: installer/profile-confirm.sh</strong> (125 lines, current Git blob <code>b88e2656d7365593cf0caa67e599db10997b9565</code>)</summary>

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
FINISH_GUARD="$CDDIR/15my-cdd-status"

stop() {
    printf >&2 'my-cdd early profile gate: STOP: %s\n' "$*"
    exit 1
}
for required in "$ORDER_HELPER" "$TEMPLATE_SIMPLE" "$TEMPLATE_CONFIRM" "$FINISH_GUARD"; do
    [ -r "$required" ] || stop "missing installer-media source: $required"
done
command -v debconf-loadtemplate >/dev/null 2>&1 ||
    stop 'debconf-loadtemplate is not available in the installer'

# Register the project's status gate before finish-install enumerates its
# hooks. 07preseed runs our late command; 14simple-cdd runs completion
# verifiers; this 15 hook stops success reporting unless all actually finish.
# No upstream udeb or installed target-system hook is patched.
mkdir -p /usr/lib/finish-install.d ||
    stop 'Cannot locate Debian Installer finish-install hook directory'
cp "$FINISH_GUARD" /usr/lib/finish-install.d/15my-cdd-status ||
    stop 'Cannot register custom finish-install completion gate'
chmod 755 /usr/lib/finish-install.d/15my-cdd-status ||
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
    db_subst my-cdd/profile-summary MYCDD_TWEAKS "$profile_status" || return 1
    status_of backports
    db_subst my-cdd/profile-summary MYCDD_BACKPORTS "$profile_status" || return 1
    status_of ensure-7x-kernel
    db_subst my-cdd/profile-summary MYCDD_KERNEL "$profile_status" || return 1
    status_of extended-device-support
    db_subst my-cdd/profile-summary MYCDD_FIRMWARE "$profile_status" || return 1
    status_of zram-writeback
    db_subst my-cdd/profile-summary MYCDD_ZRAM "$profile_status" || return 1
    status_of openmediavault
    db_subst my-cdd/profile-summary MYCDD_OMV "$profile_status" || return 1
    status_of docker
    db_subst my-cdd/profile-summary MYCDD_DOCKER "$profile_status" || return 1

    # All substitutions are single-line tokens: no embedded newline in
    # the line-oriented Debconf SUBST protocol.
    db_fset my-cdd/profile-summary seen false || return 1
    db_input critical my-cdd/profile-summary || return 1
    db_go || return 1
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

    display_summary || stop 'profile summary unavailable or cancelled'
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
<summary><strong>Complete file: installer/profile-confirm.templates</strong> (101 lines, current Git blob <code>6fefa7c97820932eec3faceb96b41bea8ad08c1a</code>)</summary>

````text
# Native Debconf templates for the user-approved early preseed confirmation.
# Loaded by /cdrom/simple-cdd/profile-confirm.sh BEFORE the original
# anna-install simple-cdd-profiles command; the upstream udeb is unmodified.

Template: my-cdd/profile-summary
Type: note
Description: Review the selected custom installation profiles
 All seven optional profiles are shown in their required execution order.
 .
  Debian tweaks: ${MYCDD_TWEAKS}
  Backports: ${MYCDD_BACKPORTS}
  Ensure Linux 7.x kernel: ${MYCDD_KERNEL}
  Extended device support: ${MYCDD_FIRMWARE}
  ZSTD ZRAM writeback: ${MYCDD_ZRAM}
  OpenMediaVault 8: ${MYCDD_OMV}
  Docker: ${MYCDD_DOCKER}
 .
 Selection does not grant permission for destructive partition changes,
 package transactions, or individual firmware omissions. The installer
 will request their separate approvals. Services installed through an
 approved package transaction follow their normal package startup defaults.

Template: my-cdd/profile-invalid
Type: note
Description: Invalid or incomplete custom profile selection
 The selected profiles could not be validated. ZRAM requires the Ensure
 Linux 7.x profile to be separately selected; unknown profile names are
 not accepted. Return to profile selection and correct the choice.
 Nothing has been enabled automatically.

Template: my-cdd/profile-confirm
Type: boolean
Default: false
Description: Proceed with exactly these selected installation profiles?
 Select No to return to the profile selection screen. The default is No.
 Other required operation-specific confirmations still apply.

# These existing cdebconf question types are reused by the selected-profile
# late_command; all state-changing approvals default to No.
Template: my-cdd/transaction-approve
Type: boolean
Default: false
Description: Approve the reviewed operation: ${MYCDD_OPERATION}?
 The complete transaction, versions, origins, proposed removals and
 consequences were displayed immediately before this question.
 Choose No to stop without executing the proposed operation.

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
 The first choice stops without changing any partition. Selecting a
 partition does NOT approve its conversion; a separate confirmation follows.

Template: my-cdd/zram-destructive
Type: boolean
Default: false
Description: Convert ${MYCDD_PARTITION} into raw ZRAM backing?
 Confirmed partition: ${MYCDD_PARTITION}
 Confirmed PARTUUID: ${MYCDD_PARTUUID}
 Confirmed size: ${MYCDD_SIZE}
 Parent disk: ${MYCDD_DISK}
 Selection: ${MYCDD_SELECTION}
 .
 Reusing this partition may break conventional swap in another operating
 system, including one not currently running.
 The first 1 MiB of ONLY this partition will be erased, destroying its
 existing swap signature and any data in that area. The partition will
 become GPT type 8300 with PARTLABEL zram-writeback, without a
 filesystem or ordinary swap activation. Default is No.

Template: my-cdd/zram-swapoff
Type: boolean
Default: false
Description: Deactivate exactly ${MYCDD_PARTITION} as swap before conversion?
 This specific partition currently contains ${MYCDD_USED} bytes of used swap.
 Moving those pages into RAM may cause memory pressure or failure.
 Only this partition will be passed to swapoff. Default is No.

Template: my-cdd/approve-removal
Type: boolean
Default: false
Description: Remove the package ${MYCDD_REMOVAL}?
 This is one individually identified package from the displayed APT
 autoremove/purge simulation. Choose No to stop the cleanup rather than
 execute an unapproved removal.
````

</details>


<details>
<summary><strong>Complete file: installer/run-selected.sh</strong> (356 lines, current Git blob <code>5fd68f3bf8b4bb2974f7b5113ad841509b3907af</code>)</summary>

````sh
#!/bin/sh
# Debian Installer-side executor: native cdebconf, no patched udeb.
# Called at the existing preseed/late_command stage before 14simple-cdd.
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
capture() {
    # Debian Installer's in-target consumes stdout into its syslog unless
    # --pass-stdout is explicitly given. Every APT review and status parser
    # must receive the real command output, so apply this in one place.
    if [ "$1" = in-target ]; then
        shift
        set -- in-target --pass-stdout "$@"
    fi
    log "COMMAND: $*"
    if "$@" > "$WORK/output" 2>&1; then rc=0; else rc=$?; fi
    cat "$WORK/output" >> "$LOG"
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
review_serial=0
show_note() {
    name=$1
    file=$2
    review_serial=$((review_serial + 1))
    q="my-cdd/review-$review_serial"
    template="$WORK/review-$review_serial.templates"
    {
        printf 'Template: %s\nType: note\nDescription: %s\n' "$q" "$name"
        while IFS= read -r line || [ -n "$line" ]; do
            if [ -z "$line" ]; then echo ' .'; else printf ' %s\n' "$line"; fi
        done < "$file"
    } > "$template"
    debconf-loadtemplate my-cdd "$template" || return 1
    db_fset "$q" seen false || return 1
    db_input critical "$q" || return 1
    db_go || return 1
}
fatal() {
    printf "FAILED\n" > "$STATUS"
    log "FATAL: $*"
    {
        printf 'Installation stopped: %s\n' "$*"
        echo "Unredacted diagnostics: $LOG"
        echo 'The installer USB is not assumed writable.'
        echo 'Manual log export: use an installer shell and a verified,'
        echo 'already-mounted writable removable data location.'
        echo
        tail -n 70 "$LOG"
    } > "$WORK/failure"
    show_note 'Custom profile failure and recovery' "$WORK/failure" || true
    cat "$WORK/failure" >&2
    export_log || true
    exit 1
}
approve() {
    db_subst my-cdd/transaction-approve MYCDD_OPERATION "$1" ||
        fatal 'Cannot prepare transaction approval'
    db_set my-cdd/transaction-approve false ||
        fatal 'Cannot reset transaction approval'
    db_fset my-cdd/transaction-approve seen false ||
        fatal 'Cannot display transaction approval'
    db_input critical my-cdd/transaction-approve ||
        fatal 'Transaction approval cancelled or unavailable'
    db_go || fatal 'Transaction confirmation cancelled'
    db_get my-cdd/transaction-approve ||
        fatal 'Cannot read transaction confirmation'
    [ "$RET" = true ] || fatal "Transaction declined: $1"
    log "USER APPROVED TRANSACTION: $1"
}
yes_no() {
    db_set "$1" false || fatal "Cannot reset $1"
    db_fset "$1" seen false || fatal "Cannot display $1"
    db_input critical "$1" || fatal "Prompt unavailable: $1"
    db_go || fatal "Prompt cancelled: $1"
    db_get "$1" || fatal "Cannot read response: $1"
    [ "$RET" = true ]
}
review_plan() {
    [ -s "$2" ] || fatal "Missing complete plan: $1"
    cat "$2" >> "$LOG"
    show_note "Review: $1" "$2" ||
        fatal "Cannot display complete plan: $1"
    approve "$1"
}
run_target() {
    # Profiles call apt-get directly. For approved package transactions,
    # show native Debian Installer GTK/text progress via Debconf.
    # Preserve their exact arguments; no implicit APT command translation.
    if [ "$1" = apt-get ]; then
        shift
        case "$1" in
            update)
                [ "$#" -eq 1 ] || fatal 'Unexpected apt-get update arguments'
                ;;
            -y)
                case "${2-}" in
                    dist-upgrade|install|autoremove) : ;;
                    *) fatal "Unsupported reviewed apt-get transaction: $*" ;;
                esac
                ;;
            *) fatal "Unexpected apt-get operation: $*" ;;
        esac
        # Never force DEBIAN_FRONTEND=noninteractive for package installs.
        capture in-target debconf-apt-progress --logstderr -- apt-get "$@" ||
            fatal "Target APT transaction failed: apt-get $*"
    else
        capture in-target "$@" || fatal "Target command failed: $*"
    fi
}
simulate_target() {
    # APT simulations and real operations both use apt-get directly.
    case "$1" in
        dist-upgrade|install|autoremove) : ;;
        *) fatal "Unsupported APT simulation: $*" ;;
    esac
    capture in-target apt-get -s "$@" ||
        fatal "APT simulation failed: apt-get -s $*"
    cp "$WORK/output" "$WORK/plan"
}
check_critical_removals() {
    if grep -E '^Remv (linux-image|linux-headers|grub|openssh-server|sudo|systemd|apt |dpkg )' "$WORK/plan" > "$WORK/critical"; then
        cat "$WORK/critical" >> "$LOG"
        fatal 'Proposed removal of boot/essential administration packages; explicit manual resolution required'
    fi
}
review_install() {
    name=$1
    shift
    simulate_target install "$@"
    check_critical_removals
    review_plan "$name" "$WORK/plan"
    run_target apt-get -y install "$@"
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
    # Debian's initial root password should be left blank to give the
    # first ordinary account sudo. Verify it rather than granting sudo
    # to an unexpected account silently.
    db_get passwd/username || fatal 'Cannot read the native installer username'
    recovery_user=$RET
    [ -n "$recovery_user" ] || fatal 'Missing installer-created admin account'
    capture in-target id -nG "$recovery_user" ||
        fatal 'Installer-created admin account is unavailable'
    case " $(cat "$WORK/output") " in
        *' sudo '*) log 'Verified native sudo administrator account' ;;
        *) fatal 'Installer-created user is not in sudo group; leave initial root-password fields empty during Debian setup' ;;
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
ensure_root_recovery

# Debian Installer's in-target wrapper already installs a temporary policy-rc.d
# that rejects maintainer-script service starts. Check that native protection
# before any selected custom APT transaction; do not create another policy,
# mask units, or change target first-boot enablement.
if [ -n "$ordered" ]; then
    capture in-target sh -c '
        [ -x /usr/sbin/policy-rc.d ] || exit 1
        /usr/sbin/policy-rc.d my-cdd-installer-preflight start
        [ "$?" -eq 101 ]
    ' || fatal 'Debian Installer target service-start protection is missing'
    log 'Confirmed native in-target package-service startup suppression'
fi

# Debian Installer apt-setup may leave its CD-ROM APT source active until
# finish-install's later 10apt-cdrom-setup hook. Our custom APT transactions
# run in 07preseed, BEFORE that native cleanup. APT update cannot refresh
# a cdrom: source; disable only those local entries in the target APT list.
# Do not change the installer medium, remove online sources, or alter mirrors.
disable_installer_cdrom_sources() {
    for source in /target/etc/apt/sources.list /target/etc/apt/sources.list.d/*.list; do
        [ -f "$source" ] || continue
        if grep -Eq '^[[:space:]]*deb(-src)?[[:space:]]+(\[[^]]*\][[:space:]]+)?cdrom:' "$source"; then
            sed -i -E '/^[[:space:]]*deb(-src)?[[:space:]]+(\[[^]]*\][[:space:]]+)?cdrom:/s/^/# my-cdd: disabled installer CD-ROM source: /' "$source" ||
                fatal "Cannot disable installer-only APT CD-ROM entry in $source"
            log "Disabled installer CD-ROM APT entry in $source"
        fi
    done
    # Keep unfamiliar deb822 arrangements intact rather than disabling a
    # stanza that may mix CD-ROM and online URIs.
    for source in /target/etc/apt/sources.list.d/*.sources; do
        [ -f "$source" ] || continue
        if grep -Eiq '^[[:space:]]*URIs:[[:space:]]+cdrom:' "$source"; then
            fatal "Unexpected active deb822 CD-ROM source in $source; manual APT-source review required"
        fi
    done
    # Fail closed if an active legacy CD-ROM source escaped the narrow edit.
    for source in /target/etc/apt/sources.list /target/etc/apt/sources.list.d/*.list; do
        [ -f "$source" ] || continue
        if grep -Eq '^[[:space:]]*deb(-src)?[[:space:]]+(\[[^]]*\][[:space:]]+)?cdrom:' "$source"; then
            fatal "Installer CD-ROM entry remains active in $source"
        fi
    done
}

if [ -n "$ordered" ]; then
    disable_installer_cdrom_sources
fi

for profile in $ordered; do
    log "PROFILE BEGIN: $profile"
    case "$profile" in
        debian-tweaks) module=tweaks; handler=profile_tweaks ;;
        backports) module=backports; handler=profile_backports ;;
        ensure-7x-kernel) module=kernel; handler=profile_kernel ;;
        extended-device-support) module=firmware; handler=profile_firmware ;;
        zram-writeback) module=zram; handler=profile_zram ;;
        openmediavault) module=omv; handler=profile_omv ;;
        docker) module=docker; handler=profile_docker ;;
        *) fatal "Unknown selected profile: $profile" ;;
    esac
    [ -r "$MEDIA/profile-$module.sh" ] || fatal "Missing selected module: $module"
    . "$MEDIA/profile-$module.sh"
    "$handler"
    printf 'Completed: %s\n' "$profile" > "$LOG_DIR/my-cdd-completed/$profile"
    chmod 600 "$LOG_DIR/my-cdd-completed/$profile"
    log "PROFILE COMPLETE: $profile"
done
log 'All selected optional profiles completed.'
printf 'COMPLETE\n' > "$STATUS"
export_log
exit 0
````

</details>


<details>
<summary><strong>Complete file: installer/15my-cdd-status</strong> (25 lines, current Git blob <code>7da85e3e09c57c9b184748a083cc30c4fa801b3f</code>)</summary>

````sh
#!/bin/sh
# Run by Debian Installer's unmodified finish-install after 07preseed
# and Simple-CDD's 14simple-cdd, BEFORE its 20final-message.
# Exit 10 is the documented finish-install "back up" code, unlike exit 1
# which finish-install only warns about before continuing to "Complete".
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

logger -t my-cdd 'Custom profiles are incomplete; stopping finish-install before its success message' || :
printf >&2 '%s\n' 'my-cdd: selected profiles did not complete. See /target/var/log/installer/my-cdd.log and my-cdd-status.' \
    'Returning to Debian Installer main menu instead of reporting Installation complete.'
exit 10
````

</details>
