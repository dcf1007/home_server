# 06 — Selectable **OpenMediaVault 8** profile

**Status:** OMV 8 vendor-repository install and cron-apt/SSH safeguarding routine is written in source. **No built ISO or successful OMV install/first-boot test claimed.** **Recorded:** 2026-11-14. **Provenance:** user request for independently selectable OMV 8 installer component and explicit approval to disable all OMV scheduled cron-apt checks.

## Scope

If selected, install **OpenMediaVault 8** into the minimal Debian 13 system **during the customized installation, before first reboot**, after package and repository compatibility checks. Do not automatically configure optional OMV features, plugins, Docker integration or additional services beyond requirements explicitly stated here. The user will configure OMV after the first boot.

This is a separate selectable profile. The **Debian tweaks** profile and the optional Docker and ZRAM profiles must remain distinct. **Do not install OMV-Extras, `openmediavault-compose`, or any Docker integration during Debian Installer.** OMV's normal services are not masked or disabled for first boot; optional plugins may be installed later from the OMV web interface at the user's discretion.

## Critical compatibility gate: selectively installed Backports packages

**If the Backports profile was explicitly selected**, Debian's default APT priority remains **100**, normally preferring stable/security packages at **500**. The independently selected [Ensure 7.x kernel branch](09_ensure_7x_kernel.md) profile may explicitly install kernel-related backported packages when necessary. Any selected backported packages or dependencies must still be checked for OMV compatibility, but **never impose global backports priority 900**. If Backports is unselected, do not activate it on OMV's behalf.

Before installing OMV:

1. Inspect effective `apt-cache policy` and simulate the OMV package transaction.
2. Inspect all proposed package changes, downgrades, package removals, and critical dependencies (especially networking, SSH, Python, systemd, web server and OMV plugins).
3. Resolve unsupported combinations by asking the user; do not silently select Backports or the kernel profile, alter repository priority, force dependencies, skip OMV or mark profile success.
4. Verify repository signatures and supported OMV 8 release. **Do not blindly execute remote network scripts** during unattended installation. Use the official documented repository/key/package procedure, validated for the exact release.

## Approved OMV 8 update policy: scheduled updates off

Leave OpenMediaVault's services at normal package-defined startup settings. Independently, the selected OMV profile disables automated updates and scheduled update notifications; manual updates remain available.

**Current source basis (2026-11-15):** OMV 8.6.2 uses the configuration model `conf.system.apt.updates` (`unattendedupgrade`) and the `apt` notification record (`enable`). It deploys the `apt` and `apticron` Salt states. The earlier `OMV_CRON_APT_ENABLED`/`cronapt` implementation is obsolete for that source version, even though some public OMV documentation still mentions cron-apt.

The selected OMV profile now sets both model values to false with `omv-confdbadm`, preserving other settings and unrelated notifications. It redeploys `apt` and `apticron` through `omv-salt`, checks that daily/weekly apticron jobs are absent, and sets both Debian periodic APT package-list refreshes and unattended upgrades to `0`. It does not manually edit OMV-generated cron files or mask/disable OMV services.

**Validation gap:** The updated OMV configuration and service behavior have not yet been exercised in a Debian 13 installer or at first boot. OMV's network and systemd-resolved requirements remain critical.

## Preserve access settings within the explicitly selected OMV profile

The unselected Debian base is not forced to install SSH or sudo. The OMV profile separately reviews installing `openssh-server` and `sudo` among its prerequisites, then adds the installer-confirmed administrator to `_ssh` and `sudo`, so its approved access policy does not depend on a global default package override.

OMV's documented Debian installation can change network configuration and enable root SSH, and the Debian-created user may be blocked from SSH unless in the `_ssh` group.

- Maintain wired DHCP connectivity (router IP reservation).
- Ensure the installer-confirmed administrator account remains a sudo-capable SSH user; add appropriate `_ssh` membership if required by OMV.
- Ensure **root SSH login remains disabled** despite OMV defaults. Local root password remains set for emergency recovery; local root account and SSH access are separate controls.
- Check SSH password-auth behavior for the installer-confirmed administrator account, which was initially approved.
- Stop on failure to preserve any agreed access behavior, with logs/diagnostics.

## First boot / acceptance

- OMV package and web interface installed; further OMV setup is left to the user after first boot.
- OMV apticron notifications, scheduled APT refreshes, and unattended security upgrades disabled; manual updates remain available.
- the installer-confirmed administrator account SSH and sudo work; root SSH refused.
- Networking works; inspect routes, DNS, interfaces and OMV configuration.
- No silent partial install; failure policy is stop/diagnose/obtain approval.

## References

- [Official OMV 8 installation on Debian](https://docs.openmediavault.org/en/stable/installation/on_debian.html)
- [OMV 8 package and backports warning](https://docs.openmediavault.org/en/stable/various/apt.html)
- [OMV configuration management](https://docs.openmediavault.org/en/stable/various/advset.html)
- [OMV SSH behavior](https://docs.openmediavault.org/en/stable/administration/services/ssh.html)

**Unverified:** OMV 8 configuration-database writes, `apt`/`apticron` deployment, DNS continuity, and absence of scheduled update jobs after first boot.
