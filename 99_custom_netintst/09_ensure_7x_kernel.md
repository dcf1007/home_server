# 09 — Build the Linux 7.x kernel installer profile

**Build goal:** write a selected-only script that discovers the newest **eligible Linux 7.x** image/header pair from the approved repositories, asks for package-review consent and installs it into `/target`. Do not hardcode a point release or silently add Backports.

For normal Debian instructions use [03 — Linux 7.x](../03_kernel_7x/README.md). For source-file conventions read [00](00_profile_construction.md).

## Step 1 — Register the module

Use the selectable name `ensure-7x-kernel` in `simple-cdd.conf` and label it in `profiles/ensure-7x-kernel.description`.

Its media manifest, `profiles/ensure-7x-kernel.extra`, contains:

~~~text
installer/profile-kernel.sh
~~~

The common dispatcher has this mapping:

~~~sh
ensure-7x-kernel) module=kernel; handler=profile_kernel ;;
~~~

This means the **actual function** must be named `profile_kernel` in `installer/profile-kernel.sh`. The `.postinst` verifier checks the marker `ensure-7x-kernel`; it must not reinstall a kernel.

## Step 2 — Build a version/ABI validator

APT's moving metapackages may point to 6.x, 7.x or a later branch. Create a helper to retrieve the **actual version** from a suite (`suite_version` is already in `profile-common.sh`), inspect that version's `Depends` field, and accept only a real 7.x kernel dependency. The current source checks that both metapackages depend on 7.x and relies on joint APT resolution, then verifies an exact matching installed pair later; it does **not** explicitly compare the two dependency ABI strings before installation.

The tracked implementation's core test is:

~~~sh
case "$1" in
    linux-image-amd64) grep -E '^Depends: .*linux-image-7\.[0-9]' "$WORK/output" >/dev/null;;
    linux-headers-amd64) grep -E '^Depends: .*linux-headers-7\.[0-9]' "$WORK/output" >/dev/null;;
    *) return 1;;
esac
~~~

This runs inside the helper `is_7x_metapackage` after target `apt-cache show` has populated `$WORK/output`. **Do not use the name `linux-image-amd64` alone as proof** that the selected dependency is 7.x.

A complete build simulates installing both metapackages together and validates that at least one installed 7.x image has an exact matching header directory afterwards.

## Step 3 — Implement suite selection without changing APT policy

Create `try_kernel_suite` to:

1. Read the image and header metapackage versions from a named suite.
2. Reject missing versions or non-7.x dependency results.
3. Simulate installing **both** metapackages from that exact suite.
4. Reject any plan removing the existing kernel, headers or GRUB.
5. Record the chosen suite, version pair and complete simulation only when viable.

The important APT call is:

~~~sh
capture in-target apt-get -s install "linux-image-amd64/$ks" "linux-headers-amd64/$ks"
~~~

`ks` is the suite passed to `try_kernel_suite`. This command **only simulates** a transaction inside the target; it does not install a kernel.

Build `choose_normal_kernel` to inspect `trixie-security`, `trixie-updates` and `trixie`, choosing the **newest viable 7.x pair** according to Debian version comparison, not a hardcoded preferred normal suite.

## Step 4 — Respect the separately selected Backports choice

Inside `profile_kernel`, use the already-defined `backports_is_selected` helper:

~~~sh
if backports_is_selected; then
    try_kernel_suite trixie-backports ||
        choose_normal_kernel ||
        fatal 'No compatible moving 7.x kernel image+headers in selected repositories'
else
    choose_normal_kernel ||
        fatal 'No normal-repository 7.x kernel: explicitly select Backports or stop/deselect this profile'
fi
~~~

**Why:** the kernel profile must never enable Backports for the user. If selected Backports has no usable pair, a viable normal 7.x pair can be used. If no allowed source contains 7.x, the script stops instead of installing 6.x/8.x.

## Step 5 — Show the exact kernel transaction for consent

After candidate selection, build a review document that includes the chosen suite, image/header versions, any fallback explanation and **the entire APT simulation**.

Pass it to `review_plan`:

~~~sh
review_plan 'Linux 7.x image, matching headers and complete APT simulation' "$WORK/kernel-review"
~~~

The common helper displays the plan in the native Debian Installer GUI and requires **default-No** approval.

## Step 6 — Install and validate the target system

Only after that approval, run the exact suite selectors:

~~~sh
run_target apt-get -y install "linux-image-amd64/$KERNEL_SUITE" "linux-headers-amd64/$KERNEL_SUITE"
run_target update-initramfs -u -k all
run_target update-grub
~~~

These calls run against **the installed target**, not the installer kernel. Preserve the existing Debian kernel as boot fallback.

The implementation scans `/target/boot/vmlinuz-7.*` and requires that at least one installed image's **exact ABI** matches a directory `/target/usr/src/linux-headers-<ABI>`. It then runs `dpkg --audit`. Failure means no completion marker.

## Step 7 — Test build-time and first-boot behavior

Parse the source without executing it:

~~~sh
sh -n installer/profile-kernel.sh
~~~

Build with `./build.sh`, then test with **Backports selected/unselected**, no 7.x candidate, unsafe removals, a declined transaction, and a successful install. After reboot, confirm the **running** kernel with `uname -r` and matching headers. The installed-image test does not prove GRUB chose that image.

**Source:** [profile-kernel.sh](my-cdd/installer/profile-kernel.sh). These are implementation instructions; don't paste target `in-target` commands into a normal Debian session.
