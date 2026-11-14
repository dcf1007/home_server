# 02 — Activate trixie-backports and set APT priority

**Status:** **provisional approved preference; implementation blocked by compatibility checks**. **Recorded:** 2026-11-14. **Provenance:** explicit user decision to prefer backports globally, with priority **900**, ordinary stable and security **500**, and manual upgrades.

## 1. Activate the Debian repositories

Use official HTTPS endpoints and Debian's signed archive keyring. Binary packages only; all four components enabled:

- `trixie`, `trixie-updates` and `trixie-backports` at `https://deb.debian.org/debian`.
- `trixie-security` at `https://security.debian.org/debian-security`.
- Components: `main contrib non-free non-free-firmware`.
- No Debian `deb-src` entries initially; no proxy.
- No third-party repositories given implicit trust. The separate Docker and OMV sources need their own supported keyring configuration.

**Illustrative** deb822 source definition for the main Debian repository (reconcile with installer-generated source files rather than blindly duplicating them):

```text
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

## 2. Global preference requested by the user

Normally Debian Backports is at priority **100** and ordinary releases at **500**. The requested override promotes **all** packages from `trixie-backports` to **900**, with `trixie`, `trixie-updates` and `trixie-security` remaining at **500** (assuming no other target-release or priority overrides).

**Provisional** `/etc/apt/preferences.d/90-local-backports.pref`:

```text
Explanation: custom server provisional global backports preference; compatibility gate required
Package: *
Pin: release n=trixie-backports
Pin-Priority: 900
```

**Do not apply this pin until validation passes.** APT release-metadata matching and effective priority must be checked on the real mirror; `APT::Default-Release` or other pins can change the result. A single backports pin does not explicitly set all other origins to 500; that value is their ordinary default without competing configuration.

## 3. Required, explicitly reviewed upgrade after enabling backports

**New user requirement:** whenever `trixie-backports` is **newly enabled as part of the customized installation**, the process must **complete all available installed-package upgrades under the approved APT policy before continuing**. Updating package lists alone does not satisfy this requirement.

1. Run `apt-get update`; verify signed repository metadata and effective pinning/candidates.
2. Simulate `apt-get -s full-upgrade` and show the complete transaction to the user, including any dependency installs, proposed removals and version changes. Confirm upgrade scope, dependencies and security effects. With the provisional global backports priority 900, a large number of package replacements may be proposed.
3. **Ask for explicit approval** before performing the real upgrade. Preserve the prior no-unattended-upgrade policy (this is a one-time, interactive installation action).
4. Apply the reviewed transaction and confirm that package configuration succeeds, there are no broken/partially configured packages, and nothing eligible for upgrade is left under the chosen policy. If full completion is impossible, **stop for manual intervention**; do not silently proceed, disable backports, skip upgrades, force package removals or modify the pin.
5. Revalidate OMV, networking/SSH and Docker package compatibility after the upgrade and prior to their profile installations.

**Important:** `apt full-upgrade` may remove existing packages to resolve dependencies. That is more invasive than `apt upgrade`. Any proposed removals/conflicts require a distinct user-confirmed resolution policy before performing the upgrade. See [ZRAM kernel prerequisite](03_zram_writeback.md).

## 4. Package installation and manual updates

The selected Debian tweaks profile installs `linux-image-amd64` and `linux-headers-amd64` from backports before the first reboot. A Debian stable kernel should remain available as a fallback at first boot; **no customized kernel retention** is authorized.

All updates, including security updates, **must require manual approval**. The Debian tweaks profile must set/verify:

```text
APT::Periodic::Unattended-Upgrade "0";
```

This setting disables APT periodic unattended package installation, **not necessarily package-index refreshes**. OMV's separate cron-apt scheduler is disabled when OMV is selected, as documented in [06_openmediavault.md](06_openmediavault.md).

**Security caveat:** A pin of 900 for backports and 500 for security means the newer backport can win over the stable security version. APT also ordinarily avoids downgrades unless a candidate priority exceeds 1000. Merely pinning the security repository is not a guarantee of timely security coverage for packages sourced from backports.

## 5. Mandatory validation before enabling priority 900

```sh
apt-cache policy
apt-cache policy linux-image-amd64 linux-headers-amd64 openmediavault
apt-config dump | grep -E 'Default-Release|Unattended|Periodic'
apt-get -s upgrade
apt-get -s dist-upgrade
```

- Review candidate versions for core libraries, systemd, APT, Python, networking, SSH, OMV and dependencies.
- Simulate both base and all selected-profile installations. If OMV and priority 900 conflict, **stop and ask**; do not silently lower the pin, force a dependency, or skip OMV.
- Verify third-party package pinning and origin independently; do not grant globally higher priority to all third-party sources.
- Verify all upgrade and reboot actions remain manual.
- Document the exact resulting `apt-cache policy` and transaction simulation outputs.

## Warning

The [official Debian Backports instructions](https://backports.debian.org/Instructions/) recommend **selective** use and say backported packages are not collectively tested for co-installability. [OMV 8 package guidance](https://docs.openmediavault.org/en/stable/various/apt.html) warns that backports can make OMV incompatible. Priority 900 is the user's explicit preference, **not an endorsed safe default**. The installation must fail its validation gate rather than silently use unapproved alternatives.

References: [APT pinning manual](https://manpages.debian.org/trixie/apt/apt_preferences.5.en.html) · [Debian Backports](https://backports.debian.org/Instructions/) · [APT periodic upgrades](https://manpages.debian.org/trixie/unattended-upgrades/unattended-upgrades.8.en.html)
