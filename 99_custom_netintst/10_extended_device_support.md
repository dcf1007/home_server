# Netinst — Extended firmware and CPU microcode procedure

**Purpose:** offer **both Intel and AMD microcode** plus the approved broad firmware inventory during installation, including hardware not currently connected.

This profile is **optional**. On an already installed server, follow [04 — Firmware and microcode](../04_extended_device_support/README.md) and use normal interactive APT. In Debian Installer the target package prompts need extra care.

## Step 1 — Choose extended device support

Select **Extended device support** in the early seven-profile screen and confirm the summary. This does not automatically enable Backports, Linux 7.x or any other profile.

The installer uses the full [firmware-candidates.txt](my-cdd/scripts/firmware-candidates.txt) manifest. It does **not** silently filter the list by CPU vendor or currently detected PCI/USB devices.

## Step 2 — Refresh sources and inspect every requested package

The selected profile updates the target's signed APT indexes, then examines each candidate against enabled Debian repositories.

- If you **also selected Backports**, it first tries a compatible Backports version of each named package.
- If no safe Backports version exists, it tries the newest suitable normal Debian candidate and records the **exact fallback reason**.
- If Backports was **not** selected, it uses only normal Debian sources.
- It checks the cumulative package transaction for dependency conflicts and removal of essential boot or administration components.

It does not use a global high-priority Backports pin.

## Step 3 — Decide about unavailable or conflicting packages

If a requested package is missing or incompatible, the installer **shows that exact package name and reason** in a separate **default-No** omission question.

Choose **No** to stop rather than delete the package silently. Choose **Yes** only if you explicitly agree to omit that one item. Each omission is recorded individually.

The installer continues through the inventory; it must have a nonempty approved set before proceeding.

## Step 4 — Review the complete combined transaction

After considering all packages and separately approved omissions, the profile simulates **the entire proposed firmware+microcode installation together**.

The GUI should show:

1. Exact package selectors (including chosen repository suites);
2. Each reason for using normal Debian instead of Backports;
3. Every separately approved omission;
4. The **complete APT simulation**, including dependencies and removals.

It rejects proposed removals of core boot/administration packages. The **default-No** approval here governs the **whole transaction**, not merely one firmware package.

## Step 5 — Read and decide both package-native licenses

Some firmware cannot be installed without accepting its original license. For each selected license-bearing package — **`firmware-ipw2x00`** and **`firmware-ivtv`** — the profile:

1. Downloads the **exact APT-selected binary package version** to a temporary target directory **without installing it**.
2. Verifies the downloaded package's name and version and extracts its original Debconf license template.
3. Displays the **full vendor-provided license** in the existing Debian Installer GUI, with an explicit acceptance question; it does not shorten the legal text.
4. If you accept, records the accepted answer in the **installed target's own Debconf database**, where the package preinstallation script will read it.
5. If you decline, asks **separately** whether omitting that package is acceptable. A refusal to omit stops the profile.

This unusual bridging is necessary because **Debian Installer and the installed target have separate Debconf environments**. Ordinary Debian APT would show the package's native prompt directly.

If a license is declined and its omission approved, the installer recalculates the **whole package simulation**. It fails if the declined package still enters as a dependency, then requests approval of the revised plan.

## Step 6 — Install and check package consistency

Only after the plan and license questions are resolved does the installer run target `apt-get` with approved package selectors, using native Debian Installer progress reporting. It then runs `dpkg --audit` to check for incomplete package configuration.

No firmware or microcode package from the optional inventory should be installed merely because its media file exists. Completion means the explicitly approved set was installed, with all omissions recorded.

## Step 7 — Check the new system after boot

On first boot inspect the installed firmware/microcode packages and the kernel log for missing firmware errors. A successful transaction does **not** prove every possible future device works.

**Testing still required:** the full original Debconf license dialogs, target-database consent handoff, fallback and omission flows, and first-boot device behavior.

Implementation: [profile-firmware.sh](my-cdd/installer/profile-firmware.sh). The installer-specific workaround is not needed in the ordinary [04 guide](../04_extended_device_support/README.md).
