# 02 — Recreate the optional Debian tweaks profile

**Current lifecycle — 2026-11-20:** Native stages 10, 50, 55 and 60 run before the selected-profile executor at `61my-cdd`; the unmodified Simple-CDD verifier, custom status guard, unmodified CD-ROM eject and unmodified final message follow at `62simple-cdd`, `63my-cdd-status`, `64cdrom-detect` and `65final-message`. The early selector registers 61/63; `partman/early_command` calls `finish-order.sh` before partitioning, checks all three original native scripts and then renames them. Native udebs and script contents are unchanged. The CD-ROM APT-source preseed remains; no forced network backend or suppressed completion dialog. Relocation failure returns nonzero to native preseed error handling, which does not guarantee installation termination. No stage-00 guard or additional repeated-execution restriction is introduced. ISO/GTK/text/first-boot testing is pending.

**Goal:** build the actual installer source for the opt-in filesystem, boot, SSH and manual-update changes. For a normal installed Debian system follow [02 — Debian tweaks](../02_debian_tweaks/README.md), not this installer code.

## Before you start

Finish the shared [Build project](build_project.md), [Shared profile helpers](profile_construction.md) and [Installer framework](installer_framework.md). Work from `99_custom_netintst/my-cdd/` in a test branch or disposable copy. This optional profile shares the common dispatcher; it is **not a standalone shell script**.

## Step 1 — Make the four feature files

| File | What it contributes |
| --- | --- |
| `profiles/debian-tweaks.description` | The label shown only when the optional tweaks checkbox is offered. |
| `profiles/debian-tweaks.extra` | Stages the selected-only tweaks module on the ISO. |
| `profiles/debian-tweaks.postinst` | Native Simple-CDD completion verifier; checks a marker without rerunning feature installation. |
| `installer/debian-tweaks.sh` | Complete code that edits target GRUB, root filesystem fstab, SSH and the manual APT-update policy. |

The choice ID is `debian-tweaks`; the dispatcher sources `installer/debian-tweaks.sh` and calls `profile_tweaks()`.

## Step 2 — Copy the complete source into each file

If needed, create these source directories:

~~~sh
mkdir -p profiles installer
~~~

This makes directories only.

**1. Create `profiles/debian-tweaks.description`.** The label shown only when the optional tweaks checkbox is offered.

Open `profiles/debian-tweaks.description` in a text editor, paste the indicated contents and save it at that path.

This opens the named file for editing; it does not run anything. Expand its identically named **complete listing below**, Save the document after reviewing the pasted contents.

**2. Create `profiles/debian-tweaks.extra`.** Stages the selected-only tweaks module on the ISO.

Open `profiles/debian-tweaks.extra` in a text editor, paste the indicated contents and save it at that path.

This opens the named file for editing; it does not run anything. Expand its identically named **complete listing below**, Save the document after reviewing the pasted contents.

**3. Create `installer/debian-tweaks.sh`.** Complete code that edits target GRUB, root filesystem fstab, SSH and the manual APT-update policy.

Open `installer/debian-tweaks.sh` in a text editor, paste the indicated contents and save it at that path.

This opens the named file for editing; it does not run anything. Expand its identically named **complete listing below**, Save the document after reviewing the pasted contents.




The installer `debian-tweaks.sh` module is *sourced*, not independently executed.

Native Debian Installer stage `61my-cdd` runs each approved selected handler **once**, then writes that profile's success marker. Unmodified Simple-CDD stage `62simple-cdd` executes the selected profile's verification-only `.postinst` **in-target**. Stage `63my-cdd-status` independently checks all approved markers and overall `COMPLETE`, returning native exit 10 rather than falsely reporting success.

## Step 3 — Understand each operation before building

1. The early profile selector makes `debian-tweaks` **optional**, never a normal Debian default. Its module runs only when that choice is approved.
2. The module changes the target's **`/etc/default/grub`** to remove `quiet` and add `fsck.repair=no`, preserving other boot options. It regenerates GRUB in the **target**.
3. It finds the single root entry in the **target's `/etc/fstab`**, makes a persistent backup, and adds `noatime` on any root filesystem. For ext2/ext3/ext4 it adds `errors=panic`; for Btrfs it uses `fatal_errors=panic`; for XFS and other filesystems it preserves native error handling rather than adding an unsupported option. Other mount entries are unchanged.
4. If `/target/etc/ssh/sshd_config` exists, the module sets `PermitRootLogin no` directly at the start of that existing file, before `Include` or `Match`. It creates no drop-in and does not attempt to run or validate the SSH daemon before first boot.
5. The selected profile checks whether **`unattended-upgrades` is installed and periodic automatic installations are enabled**. Only if so, it disables the setting in Debian's existing `20auto-upgrades` file when available, otherwise uses one local override. No subsequent post-install checks or other profiles alter this policy. Disabling it also disables automated security updates, so the administrator must update manually.
6. The late dispatcher marks the profile complete only when every required operation succeeds.

The full source below includes the validations, error handling and file-editing logic. Earlier short AWK and `sed` fragments were **not complete enough to reproduce this behavior**.

## Step 4 — Validate and build

~~~sh
sh -n installer/debian-tweaks.sh
~~~

This reads and syntax-checks the module without changing any GRUB or filesystem settings.



Each complete listing includes its original Git blob SHA; `git hash-object <path>` calculates the hash of a recreated copy without modifying it. Match the two strings to verify exact bytes before attempting `./build.sh`.

Once the **shared framework and other expected build inputs** are present, run `./build.sh` and boot a **disposable VM**. Test unchecked/selected profiles, root filesystems ext4/Btrfs/XFS, missing or ambiguous root entries, no SSH installed, and first-boot mount/GRUB/SSH/APT behavior. The previous pre-boot sshd failure must not recur.

## Full source listings

Expand each filename and paste the **entire** content into the corresponding path. These are exact source files, not pseudocode.
<details>
<summary><strong>Complete profiles/debian-tweaks.description</strong> — 1 lines; Git blob <code>f68073e69d4106419c3c98a9c887fc8059299bee</code></summary>

````text
Optional Debian filesystem, boot, SSH and update-policy changes
````

</details>

<details>
<summary><strong>Complete profiles/debian-tweaks.extra</strong> — 2 lines; Git blob <code>e8d508af94f5f133ebf5652cfb27318f8e4d2b7c</code></summary>

````text
# debian-tweaks: source assets copied by Simple-CDD (not automatically installed).
installer/debian-tweaks.sh
````

</details>



<details>
<summary><strong>Complete installer/debian-tweaks.sh</strong> — 76 lines; Git blob <code>6b363c62770cb6536179ea9111c38b937443f8dc</code></summary>

````sh
#!/bin/sh
# Sourced only when the Debian tweaks profile is explicitly selected.

profile_tweaks() {
    [ -f /target/etc/default/grub ] || fatal 'GRUB defaults absent'
    # Keep unrelated kernel arguments; remove quiet and request no automatic fsck repair.
    sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ {
        s/"quiet([[:space:]]|")/"\1/g
        s/[[:space:]]quiet([[:space:]]|")/ \1/g
        s/="[[:space:]]+/="/
        s/[[:space:]]+"$/"/
        /fsck\.repair=no/! s/"$/ fsck.repair=no"/
    }' /target/etc/default/grub
    run_target update-grub

    # Edit only the root mount entry. noatime is generic; the panic option
    # depends on the actual root filesystem.
    [ -f /target/etc/fstab ] || fatal 'Target fstab absent'
    awk '
      /^[[:space:]]*#/ {print; next}
      $2=="/" {
        fs=$3; n=split($4, opts, ","); out=""
        for (i=1;i<=n;i++) {
          if (opts[i]=="atime" || opts[i]=="relatime" ||
              opts[i]=="strictatime" || opts[i]=="noatime") continue
          if (fs ~ /^ext[234]$/ && opts[i] ~ /^errors=/) continue
          if (fs=="btrfs" && opts[i] ~ /^fatal_errors=/) continue
          out=out (out ? "," : "") opts[i]
        }
        $4=out (out ? "," : "") "noatime"
        if (fs ~ /^ext[234]$/) $4=$4 ",errors=panic"
        else if (fs=="btrfs") $4=$4 ",fatal_errors=panic"
        changed++
      }
      {print}
      END {if (changed!=1) exit 2}
    ' /target/etc/fstab > "$WORK/tweaks-fstab" ||
        fatal 'Cannot identify exactly one root filesystem in fstab'
    cp -p /target/etc/fstab /target/etc/fstab.before-tweaks ||
        fatal 'Cannot preserve the original root mount configuration'
    cp "$WORK/tweaks-fstab" /target/etc/fstab ||
        fatal 'Cannot install root mount options'

    # Fresh Debian installation: place the global setting before Include
    # and Match, without adding a project-owned sshd_config.d file.
    if [ -f /target/etc/ssh/sshd_config ]; then
        if [ "$(head -n 1 /target/etc/ssh/sshd_config)" != 'PermitRootLogin no' ]; then
            sed -i '1iPermitRootLogin no' /target/etc/ssh/sshd_config ||
                fatal 'Cannot disable root login in the existing SSH configuration'
        fi
    else
        log 'Debian tweaks: OpenSSH not installed; no SSH configuration changed'
    fi

    # This is a one-time, selected-profile policy; later profiles do not
    # reconfigure APT automatic updates.
    if capture in-target dpkg-query -W '-f=${Status}\n' unattended-upgrades &&
        grep -Fx 'install ok installed' "$WORK/output" >/dev/null; then
        capture in-target apt-config dump ||
            fatal 'Cannot inspect Debian automatic-update settings'
        if grep -Eiq '^APT::Periodic::Unattended-Upgrade[[:space:]]+"?([1-9][0-9]*|yes|true)' "$WORK/output"; then
            native_apt=/target/etc/apt/apt.conf.d/20auto-upgrades
            if [ -f "$native_apt" ] &&
                grep -Eq '^[[:space:]]*APT::Periodic::Unattended-Upgrade[[:space:]]+' "$native_apt"; then
                sed -i -E 's@^[[:space:]]*APT::Periodic::Unattended-Upgrade[[:space:]]+[^;]*;@APT::Periodic::Unattended-Upgrade "0";@' "$native_apt" ||
                    fatal 'Cannot disable periodic upgrades in Debian APT configuration'
                log 'Disabled automatic upgrades in Debian native 20auto-upgrades'
            else
                mkdir -p /target/etc/apt/apt.conf.d
                printf 'APT::Periodic::Unattended-Upgrade "0";\n' > \
                    /target/etc/apt/apt.conf.d/99-my-cdd-manual-updates
                log 'Disabled automatic upgrades with one APT override'
            fi
        fi
    fi
}
````

</details>

## Native Simple-CDD completion verifier

Create `profiles/debian-tweaks.postinst` from the full source below, alongside its `.description` and `.extra` files. The stage-61 runner writes its record after successful handler execution; the original `62simple-cdd` hook runs this verifier in-target without installing the feature twice.

~~~sh
chmod +x profiles/debian-tweaks.postinst
sh -n profiles/debian-tweaks.postinst
~~~

The syntax check is read-only. The final `63my-cdd-status` guard also checks this selected profile's record, returning exit 10 if any required record is missing.

<details>
<summary><strong>profiles/debian-tweaks.postinst</strong> — complete native verifier (11 lines; Git blob <code>50857ab897f2bbdefc48555e6425bff553235508</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer stage-11 runner, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/debian-tweaks"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'debian-tweaks'
    exit 1
fi
````

</details>
