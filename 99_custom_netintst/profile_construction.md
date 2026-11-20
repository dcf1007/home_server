# Shared profile helpers — Recreate selection rules and target APT helpers

This is a **build tutorial**. When you finish it you will have the two source files that every optional installer profile depends on. These run **inside Debian Installer**, not from a running NAS.

**Starting point:** A directory `99_custom_netintst/my-cdd/` with the Simple-CDD configuration from [Build project](build_project.md). If you are extending the existing repository, work on a separate Git branch. If you are reconstructing the project, start with [Build project](build_project.md), complete this chapter, then [Installer framework](installer_framework.md) and the feature you want.

## Step 1 — Know what each file provides

| Create this file | Why it exists |
| --- | --- |
| `installer/ordered-selection.sh` | Takes the user's checkbox selection, rejects unknown combinations and produces a fixed execution order. ZRAM cannot be selected without the separately selected kernel profile. |
| `installer/profile-common.sh` | Contains only the suite/version lookup, Backports-selection and signed-APT-refresh operations shared by multiple profiles. APT simulations and approvals belong to the dispatcher. |

These files **define functions only**. The late installer dispatcher *sources* them; you must not invoke them as standalone commands.

## Step 2 — Create the files

In the `my-cdd` directory, create the installer directory if absent:

~~~sh
mkdir -p installer
~~~

Open each listed file in a text editor (for example a text editor for `installer/ordered-selection.sh`), Save the document after reviewing the pasted contents. Repeat for `installer/profile-common.sh`.

**Copy every line**, including the shell header and comments. The shorter excerpts in older guides were not complete programs. The complete listings below are copied directly from the recorded repository revision.

## Step 3 — Understand the control flow

The selection parser first validates the approved profile names and cross-profile dependency; it never adds choices automatically. The shared source/version helpers inspect the **target system** in `/target`, not the installer's temporary package database. Repository refresh runs APT once and does not add an extra priority-policy check. One-time automatic-update configuration now belongs directly to the selected Debian tweaks module; no OpenSSH validation helper is retained. A complete APT plan is shown through the dispatcher's native Debconf UI before a target package transaction is performed.

The shared functions expect the dispatcher to provide `capture`, `fatal`, `WORK`, `LOG`, `MEDIA` and the cdebconf helper functions. That's why you must complete [Installer framework](installer_framework.md) before using a feature module.

## Step 4 — Check your copies

~~~sh
sh -n installer/ordered-selection.sh
~~~

This parses the selector without executing it. No output and exit status zero indicate syntax passed.

~~~sh
sh -n installer/profile-common.sh
~~~

This likewise checks the shared functions' shell syntax. Syntax validation cannot prove the APT logic works. Confirm the code is identical using the expected Git blob hashes in the file listings below (see the check instructions there).

**Next:** [Installer framework](installer_framework.md).

## Complete, copyable source files

Expand the file you want to create. **These are full files, not fragments.** Copy the contents between the code fences into the **exact path named in the heading**. After saving, use `git hash-object <path>` to calculate that file's Git blob SHA and compare it with the original SHA shown in the heading; a match proves a byte-for-byte copy. The command reads the file but makes no edits.


<details>
<summary><strong>Complete file: installer/ordered-selection.sh</strong> (25 lines, current Git blob <code>bdf73139a2e42499748fa570d763f3112d787312</code>)</summary>

````sh
#!/bin/sh
# Pure selection validation. Does NOT enable, disable or execute profiles.
# Usage: sh ordered-selection.sh 'docker, backports, ensure-7x-kernel'
set -eu
[ "$#" -eq 1 ] || { printf >&2 'Expected one comma-separated selection string\n'; exit 2; }
selected="$(printf %s "$1" | tr ',' ' ')"
order='debian-tweaks backports ensure-7x-kernel extended-device-support zram-writeback netplan-test openmediavault docker'
for token in $selected; do
  case " $order " in *" $token "*) ;; *)
    printf >&2 'Unknown/unapproved profile: %s\n' "$token"; exit 1;;
  esac
done
out=''
for token in $order; do
  case " $selected " in
    *" $token "*)
      if [ -n "$out" ]; then out="$out $token"; else out="$token"; fi ;;
  esac
done
case " $out " in *' zram-writeback '*)
  case " $out " in *' ensure-7x-kernel '*) ;; *)
    printf >&2 'ZRAM requires explicitly selected Ensure 7.x\n'; exit 1;;
  esac ;;
esac
printf '%s\n' "$out"
````

</details>


<details>
<summary><strong>Complete file: installer/profile-common.sh</strong> (18 lines, current Git blob <code>19fcba111715cf3dfdcd2b76ac0efe1fedcf9ed3</code>)</summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

suite_version() {
    capture in-target apt-cache madison "$1" ||
        fatal "Unable to inspect APT candidates for $1"
    awk -F '|' -v s="$2" 'index($3,s"/") {
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2; exit
    }' "$WORK/output"
}

backports_is_selected() {
    case " $ordered " in *' backports '*) return 0;; *) return 1;; esac
}

update_signed_apt() {
    run_target apt-get update
}

````

</details>
