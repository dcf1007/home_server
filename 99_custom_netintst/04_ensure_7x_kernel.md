# 04 — Recreate the Linux 7.x installer profile

**Outcome:** reconstruct the **entire** installer-side Linux 7.x profile and understand which part is responsible for package-source selection, real APT changes and verification. The normal Debian how-to is [03 — Linux 7.x](../04_kernel_7x/README.md).

## Before you start

Build the common Simple-CDD project in [Build project](build_project.md), shared code in [Shared profile helpers](profile_construction.md) and dispatcher/selection UI in [Installer framework](installer_framework.md). This feature cannot run without that framework. Work from the directory `99_custom_netintst/my-cdd/` on a test branch or scratch copy.

## Step 1 — Identify your four files

| Path to create | Purpose |
| --- | --- |
| `profiles/ensure-7x-kernel.description` | User-visible description for the separate kernel checkbox. |
| `profiles/ensure-7x-kernel.extra` | Copies the kernel installer module to the ISO. |
| `profiles/ensure-7x-kernel.postinst` | Verifies the success marker, without executing the install twice. |
| `installer/profile-kernel.sh` | The full suite-selection, 7.x dependency, package-consent and boot-verification code. |

The **selection name** is `ensure-7x-kernel`. The **module file** is `installer/profile-kernel.sh`. The **function called by the dispatcher** is `profile_kernel()`. All three names are deliberately different; do not rename one without updating its dispatcher mapping.

## Step 2 — Write the exact sources

If necessary, make the project source folders:

~~~sh
mkdir -p profiles installer
~~~

This prepares directories, not system packages.

**1. Create `profiles/ensure-7x-kernel.description`.** User-visible description for the separate kernel checkbox.

Open `profiles/ensure-7x-kernel.description` in a text editor, paste the indicated contents and save it at that path.

This opens that file for editing. **Expand the complete listing with the identical path at the end of this guide** and paste the entire listing, including comments and final newline. Save the document after reviewing the pasted contents. Nothing runs merely because the file has been saved.

**2. Create `profiles/ensure-7x-kernel.extra`.** Copies the kernel installer module to the ISO.

Open `profiles/ensure-7x-kernel.extra` in a text editor, paste the indicated contents and save it at that path.

This opens that file for editing. **Expand the complete listing with the identical path at the end of this guide** and paste the entire listing, including comments and final newline. Save the document after reviewing the pasted contents. Nothing runs merely because the file has been saved.

**3. Create `profiles/ensure-7x-kernel.postinst`.** Verifies the success marker, without executing the install twice.

Open `profiles/ensure-7x-kernel.postinst` in a text editor, paste the indicated contents and save it at that path.

This opens that file for editing. **Expand the complete listing with the identical path at the end of this guide** and paste the entire listing, including comments and final newline. Save the document after reviewing the pasted contents. Nothing runs merely because the file has been saved.

**4. Create `installer/profile-kernel.sh`.** The full suite-selection, 7.x dependency, package-consent and boot-verification code.

Open `installer/profile-kernel.sh` in a text editor, paste the indicated contents and save it at that path.

This opens that file for editing. **Expand the complete listing with the identical path at the end of this guide** and paste the entire listing, including comments and final newline. Save the document after reviewing the pasted contents. Nothing runs merely because the file has been saved.


Set executable permission on only the completion verifier:

~~~sh
chmod +x profiles/ensure-7x-kernel.postinst
~~~

The main module is **sourced** by `run-selected.sh`; never execute it as a standalone installer.

## Step 3 — Follow the handler's logic

1. The early Simple-CDD checkbox offers the kernel profile but does not select it by default. **ZRAM requires this separate selection**; ZRAM must not automatically select a kernel.
2. The dispatcher maps this profile ID to `profile_kernel()`, after any selected Backports stage has completed.
3. The function inspects available **signed target APT repositories**. If Backports was selected, it tries a viable Backports pair first; otherwise it considers normal Debian suites only. It **does not add a repository**.
4. It reads the image and header metapackage dependencies and requires **Linux 7.x**. APT simulations for both packages are reviewed together and must not remove the existing working kernel or GRUB.
5. A default-No Debian Installer approval shows the complete transaction. Only after approval does the function install into `/target`, regenerate initramfs/GRUB, check `dpkg --audit` and verify **an installed 7.x image has headers with the same ABI**.
6. First boot still needs verification: the installed package presence does not prove the running kernel is actually 7.x.

**Important limitation from the actual source:** its checks establish that the moving packages depend on 7.x and verify an exact installed image/header match **after** installation; the guide should not imply that all image/header ABI strings are paired before installing.

## Step 4 — Parse and verify the rebuilt source

~~~sh
sh -n installer/profile-kernel.sh
~~~

This checks shell grammar but does **not** install a kernel.

~~~sh
sh -n profiles/ensure-7x-kernel.postinst
~~~

This checks the verifier's shell syntax.

~~~sh
chmod +x profiles/ensure-7x-kernel.postinst
~~~

This only ensures the verifier has executable permission; it does not run it. You can use `git hash-object <filename>` to compare each recreated file with the original blob SHA in the listings below; differences mean the file content was not copied exactly.

When the common framework and complete feature manifests are ready, run the project's `./build.sh`. Boot a **disposable VM** and test no 7.x candidate, a declined plan, Backports selected/unselected, unsafe removals, actual `uname -r` and matching headers after boot. **The current project has not yet passed those end-to-end checks.**

## Exact, complete source listings

These are actual full source files from the tracked reference revision—not shortened examples.
<details>
<summary><strong>profiles/ensure-7x-kernel.description</strong> — complete file (1 lines; blob <code>42d78a024266247f24c13853dc9bfdccb493ec5d</code>)</summary>

````text
Linux 7.x image and headers; review source and kernel transaction
````

</details>

<details>
<summary><strong>profiles/ensure-7x-kernel.extra</strong> — complete file (2 lines; blob <code>8792517327ba43ba76b56c7b66714d1d8aad1655</code>)</summary>

````text
# ensure-7x-kernel: source assets copied by Simple-CDD (not automatically installed).
installer/profile-kernel.sh
````

</details>

<details>
<summary><strong>profiles/ensure-7x-kernel.postinst</strong> — complete file (11 lines; blob <code>09aa36918289732ea8b981191e2d524eee00d324</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer late command, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/ensure-7x-kernel"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'ensure-7x-kernel'
    exit 1
fi
````

</details>

<details>
<summary><strong>installer/profile-kernel.sh</strong> — complete file (89 lines; blob <code>3134cb92c50632722d71a4974099a0fbf4c6a0f0</code>)</summary>

````sh
#!/bin/sh
# Sourced by the approved installer dispatcher; no automatic execution.

is_7x_metapackage() {
    [ -n "$2" ] || return 1
    capture in-target apt-cache show "$1=$2" || return 1
    case "$1" in
        linux-image-amd64) grep -E '^Depends: .*linux-image-7\.[0-9]' "$WORK/output" >/dev/null;;
        linux-headers-amd64) grep -E '^Depends: .*linux-headers-7\.[0-9]' "$WORK/output" >/dev/null;;
        *) return 1;;
    esac
}

try_kernel_suite() {
    ks=$1
    iv="$(suite_version linux-image-amd64 "$ks")"
    hv="$(suite_version linux-headers-amd64 "$ks")"
    [ -n "$iv" ] && [ -n "$hv" ] || return 1
    is_7x_metapackage linux-image-amd64 "$iv" || return 1
    is_7x_metapackage linux-headers-amd64 "$hv" || return 1
    if capture in-target apt-get -s install "linux-image-amd64/$ks" "linux-headers-amd64/$ks"; then
        cp "$WORK/output" "$WORK/plan"
        if grep -E '^Remv (linux-image|linux-headers|grub)' "$WORK/plan" >/dev/null; then
            log "Rejected candidate kernel suite: $ks would remove initial fallback/boot support"
            return 1
        fi
        KERNEL_SUITE=$ks
        KERNEL_IMAGE_VERSION=$iv
        KERNEL_HEADERS_VERSION=$hv
        return 0
    fi
    log "Rejected candidate kernel suite: $ks did not resolve safely"
    return 1
}

choose_normal_kernel() {
    # Among normal Debian repositories, use the newest *viable* 7.x pair,
    # not an arbitrarily preferred security/updates suite.
    best_suite=''
    best_version=''
    for normal in trixie-security trixie-updates trixie; do
        if try_kernel_suite "$normal"; then
            if [ -z "$best_version" ] ||
                in-target dpkg --compare-versions "$KERNEL_IMAGE_VERSION" gt "$best_version"; then
                best_suite=$normal
                best_version=$KERNEL_IMAGE_VERSION
            fi
        fi
    done
    [ -n "$best_suite" ] || return 1
    try_kernel_suite "$best_suite"
}

profile_kernel() {
    update_signed_apt
    if backports_is_selected; then
        try_kernel_suite trixie-backports ||
            choose_normal_kernel ||
            fatal 'No compatible moving 7.x kernel image+headers in selected repositories'
    else
        choose_normal_kernel ||
            fatal 'No normal-repository 7.x kernel: explicitly select Backports or stop/deselect this profile'
    fi
    {
        echo "Chosen kernel suite: $KERNEL_SUITE"
        echo "linux-image-amd64: $KERNEL_IMAGE_VERSION"
        echo "linux-headers-amd64: $KERNEL_HEADERS_VERSION"
        if backports_is_selected && [ "$KERNEL_SUITE" != trixie-backports ]; then
            echo 'Stable fallback to a viable 7.x pair; rejected Backports reasons in full log'
        fi
        cat "$WORK/plan"
    } > "$WORK/kernel-review"
    review_plan 'Linux 7.x image, matching headers and complete APT simulation' "$WORK/kernel-review"
    run_target apt-get -y install "linux-image-amd64/$KERNEL_SUITE" "linux-headers-amd64/$KERNEL_SUITE"
    run_target update-initramfs -u -k all
    run_target update-grub
    paired=0
    for image in /target/boot/vmlinuz-7.*; do
        [ -f "$image" ] || continue
        abi="${image##*/vmlinuz-}"
        if [ -d "/target/usr/src/linux-headers-$abi" ]; then
            paired=1
        fi
    done
    [ "$paired" = 1 ] ||
        fatal 'No Linux 7.x boot image with exactly matching installed headers'
    run_target dpkg --audit
}

````

</details>
