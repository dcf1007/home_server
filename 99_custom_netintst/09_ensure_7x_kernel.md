# Netinst — Install and verify Linux 7.x during installation

**Goal:** install the newest **eligible, compatible Linux 7.x** kernel image and exact matching headers, without removing the bootable initial Debian kernel.

The normal post-install procedure is [03 — Linux 7.x](../03_kernel_7x/README.md). The installer performs these steps only if **Ensure 7.x kernel** was selected.

## Step 1 — Refresh the target's signed repositories

The profile updates APT in the newly installed Debian system under `/target`. The candidates come only from the sources currently enabled. **Backports is considered only if its separate profile was selected.** The kernel stage never activates Backports itself.

## Step 2 — Inspect candidate versions and dependencies

The installer reads available versions of `linux-image-amd64` and `linux-headers-amd64`. It checks that their real dependencies resolve to **`linux-image-7.*`** and **`linux-headers-7.*`**, with a compatible pair.

- With Backports explicitly selected, it tries **Trixie Backports first**.
- If that pair is missing or unsafe, it checks **trixie-security**, **trixie-updates** and **trixie**, choosing the newest viable normal 7.x pair.
- Without Backports selected, it considers only the normal Debian suites.

If none supplies a viable 7.x image+headers pair, the stage stops. It **does not silently install 6.x, 8.x, or a kernel from a newly enabled repository**.

## Step 3 — Simulate the exact install and ask permission

The installer dry-runs APT using **both** moving metapackages from the chosen suite. A candidate that proposes removing the existing kernel, headers or GRUB is rejected.

A confirmation screen then shows the chosen suite, both candidate versions and the **complete APT simulation**. Read the proposed changes and approve only when they match a safe 7.x pair. The default is No.

## Step 4 — Install, rebuild and verify

With approval, target APT installs the image and matching headers. It then regenerates initramfs images and GRUB's boot menu.

Before recording success, the profile verifies that `/target/boot` contains a `vmlinuz-7.*` image with an **exact ABI-matching** directory under `/target/usr/src/linux-headers-*`. It also checks for incomplete packages.

## Step 5 — Confirm after the first reboot

The installer cannot prove which kernel GRUB will actually boot. After first boot, run `uname -r` on the real system and confirm the version starts with `7.`; inspect `/usr/src` for matching headers. Retain the Stable fallback until boot-tested.

**Important:** a 7.x version alone does not prove the ZRAM writeback sysfs features; [the ZRAM installer page](03_zram_writeback.md) explains the additional runtime checks.

**Installer-only adaptation:** early installation needs native GUI approvals and target `in-target` APT execution. These are not required by the ordinary post-install guide.
