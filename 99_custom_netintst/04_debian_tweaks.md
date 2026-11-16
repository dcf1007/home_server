# 04 — Build the Debian tweaks installer module

**Build goal:** implement **optional** changes to GRUB boot text, ext4 root options, SSH root login and unattended APT policy in the **installed target**. This is not where Debian Installer should configure language, keyboard, network, accounts or tasksel.

The ordinary full-Debian procedure is [06 — Debian tweaks](../06_debian_tweaks/README.md).

## Step 1 — Create and register the source module

Offer `debian-tweaks` as a checkbox, label it in `profiles/debian-tweaks.description`, and create this `profiles/debian-tweaks.extra` manifest:

~~~text
installer/profile-tweaks.sh
~~~

In `installer/run-selected.sh`, keep:

~~~sh
debian-tweaks) module=tweaks; handler=profile_tweaks ;;
~~~

Write a `profile_tweaks()` function in `installer/profile-tweaks.sh`. Its body must execute **only** when selected; its `.postinst` should check the marker instead of redoing the edits.

## Step 2 — Modify target GRUB arguments, not installer boot options

Inside `profile_tweaks`, require `/target/etc/default/grub` to exist. The module uses a narrow `sed` expression to **remove `quiet` and add `fsck.repair=no`** to `GRUB_CMDLINE_LINUX_DEFAULT` while keeping unrelated kernel arguments.

Then regenerate GRUB **inside the installed target**:

~~~sh
run_target update-grub
~~~

**Why this belongs here:** default language/keyboard settings are handled earlier in `profile_defaults.conf`; this opt-in feature concerns filesystem recovery policy after installation. `fsck.repair=no` may require console intervention on filesystem errors.

## Step 3 — Edit exactly one ext4 root fstab entry

Build a parser for `/target/etc/fstab` that:

1. Preserves comment lines and all non-root entries.
2. Matches only mount point `/` with type `ext4`.
3. Removes conflicting `atime`, `relatime`, `strictatime` and existing `errors=...` options.
4. Adds `noatime,errors=panic` while keeping unrelated options.
5. **Fails unless exactly one matching root entry was found**, before replacing the target `fstab`.

The critical source predicate is:

~~~awk
$2=="/" && $3=="ext4" {
    n=split($4, opts, ","); out=""
    # Retain safe options; remove conflicting access-time and errors choices.
    # Require exactly one match in the full AWK program before installing output.
}
~~~

This is **a teaching excerpt**, not a complete AWK program; do not execute it as-is. The existing `profile-tweaks.sh` contains the complete validator and staged replacement. Never change other mounts or assume root is ext4.

## Step 4 — Apply SSH policy only if OpenSSH exists

The selected module first detects `sshd` **inside the target**, without installing it when the user omitted the normal SSH task. If present, create `/target/etc/ssh/sshd_config.d/01-my-cdd-root-login.conf` containing:

~~~text
PermitRootLogin no
~~~

The code then checks target `sshd -T` and requires the **effective** `permitrootlogin no` value. This prohibits SSH root login but preserves the usable local root password established by the common preflight.

If SSH is absent, log the skip instead of adding a service.

## Step 5 — Enforce manual updates only when necessary

Reuse `ensure_manual_updates` from `installer/profile-common.sh`. It reads target `apt-config dump`, and writes a small `Unattended-Upgrade "0"` override **only when an active automatic setting is detected**. Avoid overriding an already-disabled configuration without need.

The OMV selected profile adds its own OMV and APT notification policy later; keep the two features independent.

## Step 6 — Syntax check, build and test

The file you are building is a POSIX shell module, so parse it before rebuilding:

~~~sh
sh -n installer/profile-tweaks.sh
~~~

Then run `./build.sh`. In a disposable VM compare **unselected** (no target change) with **selected** (expected GRUB, ext4, SSH and APT policies). Test missing/ext4-mismatch root, absent OpenSSH and effective SSH overrides. After reboot inspect `/proc/cmdline` and the actual root mount options.

**Source:** [profile-tweaks.sh](my-cdd/installer/profile-tweaks.sh) and [shared APT helper](my-cdd/installer/profile-common.sh).
