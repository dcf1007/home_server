# 02 — Optional Backports profile: activate, pin and upgrade

**Status:** selectable **Backports installer profile**, initially **unchecked**. The global priority policy is **approved provisionally**, but execution remains blocked by compatibility checks. **Recorded:** 2026-11-14. **Provenance:** explicit user decisions to prefer backports at priority **900**, stable/security at **500**, and perform a **complete, reviewed package upgrade as a step within the Backports profile**.

## Installer profile behavior and dependencies

- **Backports is a distinct opt-in profile**, not an implicit part of Debian tweaks or ZRAM. Its checkbox is initially **unchecked**. The user must explicitly select and confirm it; no other profile may silently select it.
- When Backports is selected, its implementation runs in this order: **(1) enable and verify the repository, (2) apply and verify APT pinning, (3) simulate and review a full upgrade of all eligible installed packages, (4) perform the confirmed upgrade, (5) validate completion, and only then (6) continue to other selected profiles**.
- When Backports is **not selected**, do not enable the backports repository, impose its pin, or run this upgrade workflow. Ordinary signed Debian 13 repositories remain usable.
- If ZRAM or Debian tweaks requires an eligible **Linux 7.x** kernel not available from the standard repositories, prompt the user to **explicitly select Backports or deselect/stop the requesting profile**. Never auto-enable Backports, Debian tweaks or any other profile.
- Selected OMV and Docker profiles remain separate; their dependencies must be simulated against the exact resulting APT state **before** a full upgrade that could affect them.



## 1. Activate Debian backports if this profile is selected

Use official HTTPS endpoints and Debian's signed archive keyring. Binary packages only; all four components enabled **only when Backports is selected**:

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

**This provisional pin is applied only by the explicitly selected Backports profile, and only after validation passes.** APT release-metadata matching and effective priority must be checked on the real mirror; `APT::Default-Release` or other pins can change the result. A single backports pin does not explicitly set all other origins to 500; that value is their ordinary default without competing configuration.

## 3. Mandatory upgrade step inside this profile

**The Backports profile owns the complete upgrade step.** After the repository is enabled and priority 900 has passed validation, **upgrade all currently eligible installed packages before proceeding**. Updating package indexes alone does not satisfy this requirement.

1. Refresh signed APT metadata with `apt-get update`, inspect `apt-cache policy`, and validate package candidate origins and priorities (especially security updates and third-party applications).
2. Run `apt-get -s full-upgrade` and display the complete proposed transaction, including version changes, new dependencies, downgrades, proposed removals, held packages and any package candidates affected by the Backports pin.
3. **Require explicit user confirmation of the reviewed transaction**. A package removal or dependency conflict must not be performed automatically; present it for further review and stop on an unresolved or unsafe operation.
4. Execute the **confirmed** upgrade inside this profile. Do not silently narrow it to a selected subset, ignore pending upgrades, relax the global pin or use `--allow-unauthenticated` or equivalent overrides.
5. Check `dpkg --audit`, `apt-mark showhold`, `apt list --upgradable`, APT simulation results and service health. If anything eligible remains unupgraded or if the transaction failed, **stop** the selected profile, retain logs and request manual intervention. Do not proceed to ZRAM or other profiles.
6. Re-simulate dependencies for separately selected OMV, Docker and kernel 7.x requirements after this profile succeeds.

**Caution:** `apt full-upgrade` is capable of removing packages. Whether an explicitly reviewed removal is permissible is a separate installation-policy decision; until resolved, such removals must result in a stop and manual review.

This is a **one-time, interactive install-stage action**, not permission for unattended upgrades. No other installer profile implements a duplicate Backports full-upgrade step.

## 4. Package installation and manual updates

Debian tweaks and ZRAM each enforce their own requirement for the newest eligible Linux **7.x** kernel and matching headers (with moving `linux-image-amd64` and `linux-headers-amd64` metapackages; no fixed version lock). Backports may supply the candidate packages, but choosing Backports never implicitly selects either profile. Keep a stable kernel initially available as fallback; **no customized kernel retention** is authorized.

All upgrades, including security updates, **require manual approval**. This profile performs only the explicitly confirmed one-time upgrade described above; Debian tweaks separately applies the manual-only APT configuration, and every selected-profile combination must verify that no independent unattended installation mechanism remains enabled:

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
