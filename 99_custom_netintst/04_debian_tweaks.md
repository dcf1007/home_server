# 04 — Recreate the optional Debian tweaks installer profile

**Goal:** build the actual installer source for the opt-in filesystem, boot, SSH and manual-update changes. For a normal installed Debian system follow [06 — Debian tweaks](../06_debian_tweaks/README.md), not this installer code.

## Before you start

Finish the shared [ISO build project](01_custom_cdd_preparation.md), [common helpers](00_profile_construction.md) and [installer hooks](05_base_installation.md). Work from `99_custom_netintst/my-cdd/` in a test branch or disposable copy. This optional profile shares the common dispatcher; it is **not a standalone shell script**.

## Step 1 — Make the four feature files

| File | What it contributes |
| --- | --- |
| `profiles/debian-tweaks.description` | The label shown only when the optional tweaks checkbox is offered. |
| `profiles/debian-tweaks.extra` | Stages the selected-only tweaks module on the ISO. |
| `profiles/debian-tweaks.postinst` | Checks the marker after successful application; it does not reconfigure Debian. |
| `installer/profile-tweaks.sh` | Complete code that edits target GRUB, root ext4 fstab, SSH and the manual APT-update policy. |

The choice ID is `debian-tweaks`; the dispatcher sources `installer/profile-tweaks.sh` and calls `profile_tweaks()`.

## Step 2 — Copy the complete source into each file

If needed, create these source directories:

~~~sh
mkdir -p profiles installer
~~~

This makes directories only.

**1. Create `profiles/debian-tweaks.description`.** The label shown only when the optional tweaks checkbox is offered.

~~~sh
nano profiles/debian-tweaks.description
~~~

This opens the named file for editing; it does not run anything. Expand its identically named **complete listing below**, copy all lines, save with Ctrl+O and Enter, then exit with Ctrl+X.

**2. Create `profiles/debian-tweaks.extra`.** Stages the selected-only tweaks module on the ISO.

~~~sh
nano profiles/debian-tweaks.extra
~~~

This opens the named file for editing; it does not run anything. Expand its identically named **complete listing below**, copy all lines, save with Ctrl+O and Enter, then exit with Ctrl+X.

**3. Create `profiles/debian-tweaks.postinst`.** Checks the marker after successful application; it does not reconfigure Debian.

~~~sh
nano profiles/debian-tweaks.postinst
~~~

This opens the named file for editing; it does not run anything. Expand its identically named **complete listing below**, copy all lines, save with Ctrl+O and Enter, then exit with Ctrl+X.

**4. Create `installer/profile-tweaks.sh`.** Complete code that edits target GRUB, root ext4 fstab, SSH and the manual APT-update policy.

~~~sh
nano installer/profile-tweaks.sh
~~~

This opens the named file for editing; it does not run anything. Expand its identically named **complete listing below**, copy all lines, save with Ctrl+O and Enter, then exit with Ctrl+X.


Set execute permission on the marker-checking postinst only:

~~~sh
chmod +x profiles/debian-tweaks.postinst
~~~

The installer `profile-tweaks.sh` module is *sourced*, not independently executed.

## Step 3 — Understand each operation before building

1. The early profile selector makes `debian-tweaks` **optional**, never a normal Debian default. Its module runs only when that choice is approved.
2. The module changes the target's **`/etc/default/grub`** to remove `quiet` and add `fsck.repair=no`, preserving other boot options. It regenerates GRUB in the **target**.
3. It parses the **target's `/etc/fstab`** and requires one root ext4 entry. Only that entry receives `noatime,errors=panic`; EFI and NAS data mounts must remain unchanged. `errors=panic` is a deliberate failure-handling policy.
4. If a target OpenSSH daemon exists, the module creates an SSH drop-in with `PermitRootLogin no` and checks the **effective** SSH config. It does not install OpenSSH solely for the tweak.
5. The shared APT helper handles the project's **manual-only package update** policy; the administrator must then perform security updates manually.
6. The late dispatcher marks the profile complete only when every required operation succeeds.

The full source below includes the validations, error handling and file-editing logic. Earlier short AWK and `sed` fragments were **not complete enough to reproduce this behavior**.

## Step 4 — Validate and build

~~~sh
sh -n installer/profile-tweaks.sh
~~~

This reads and syntax-checks the module without changing any GRUB or filesystem settings.

~~~sh
sh -n profiles/debian-tweaks.postinst
~~~

This similarly parses the marker checker.

Each complete listing includes its original Git blob SHA; `git hash-object <path>` calculates the hash of a recreated copy without modifying it. Match the two strings to verify exact bytes before attempting `./build.sh`.

Once the **shared framework and other expected build inputs** are present, run `./build.sh` and boot a **disposable VM**. Test this feature unchecked, selected, missing/ambiguous root fstab, no SSH installed, and first-boot effective mount/GRUB/SSH/APT configuration.

## Full source listings

Expand each filename and paste the **entire** content into the corresponding path. These are exact source files, not pseudocode.
<details>
<summary><strong>Complete profiles/debian-tweaks.description</strong> — 1 lines; Git blob <code>f68073e69d4106419c3c98a9c887fc8059299bee</code></summary>

````text
Optional Debian filesystem, boot, SSH and update-policy changes
````

</details>

<details>
<summary><strong>Complete profiles/debian-tweaks.extra</strong> — 2 lines; Git blob <code>1526ae3366f73ec5adcd386361f5ae79bc58b0e0</code></summary>

````text
# debian-tweaks: source assets copied by Simple-CDD (not automatically installed).
installer/profile-tweaks.sh
````

</details>

<details>
<summary><strong>Complete profiles/debian-tweaks.postinst</strong> — 11 lines; Git blob <code>c94115dde4672a867033610df8b34b90c1acc505</code></summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer late command, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/debian-tweaks"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'debian-tweaks'
    exit 1
fi
````

</details>

<details>
<summary><strong>Complete installer/profile-tweaks.sh</strong> — 51 lines; Git blob <code>053f6fdd2abb9afe9c51bccca0f53502aef4435b</code></summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

profile_tweaks() {
    [ -f /target/etc/default/grub ] || fatal 'GRUB defaults absent'
    # The user approved only removal of quiet and fsck.repair=no; retain
    # all other kernel arguments and normal GRUB behavior.
    sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ {
        s/"quiet([[:space:]]|")/"\1/g
        s/[[:space:]]quiet([[:space:]]|")/ \1/g
        s/="[[:space:]]+/="/
        s/[[:space:]]+"$/"/
        /fsck\.repair=no/! s/"$/ fsck.repair=no"/
    }' /target/etc/default/grub
    run_target update-grub

    [ -f /target/etc/fstab ] || fatal 'Target fstab absent'
    awk '
      /^[[:space:]]*#/ {print; next}
      $2=="/" && $3=="ext4" {
        n=split($4, opts, ","); out=""
        for (i=1;i<=n;i++) {
          if (opts[i]=="atime" || opts[i]=="relatime" || opts[i]=="strictatime") continue
          if (opts[i] ~ /^errors=/ || opts[i]=="noatime") continue
          out=out (out? ",":"") opts[i]
        }
        $4=out ",noatime,errors=panic"
        changed++
      }
      {print}
      END {if (changed!=1) exit 2}
    ' /target/etc/fstab > "$WORK/tweaks-fstab" ||
        fatal 'Cannot identify exactly one ext4 root mount in fstab'
    cp "$WORK/tweaks-fstab" /target/etc/fstab

    # The profile must not force OpenSSH onto a Debian installation where
    # the native tasksel SSH option was intentionally deselected.
    if capture in-target sh -c 'command -v sshd >/dev/null 2>&1'; then
        mkdir -p /target/etc/ssh/sshd_config.d
        printf 'PermitRootLogin no\n' > /target/etc/ssh/sshd_config.d/01-my-cdd-root-login.conf
        capture in-target sshd -T || fatal 'OpenSSH configuration invalid'
        grep -Fx 'permitrootlogin no' "$WORK/output" >/dev/null ||
            fatal 'Effective OpenSSH root-login setting is not no'
    else
        log 'Debian tweaks: OpenSSH not installed; no SSH policy file created'
    fi
    # Do not create a needless periodic-APT override if the policy is already
    # disabled. This guard is also checked after later selected profiles.
    ensure_manual_updates
}

````

</details>
