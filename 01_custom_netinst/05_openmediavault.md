# 05 — Selectable **OpenMediaVault 8** profile

**Status:** planned conditional install, no built ISO or successful OMV test claimed. **Recorded:** 2026-11-14. **Provenance:** user request for independently selectable OMV 8 installer component and explicit approval to disable all OMV scheduled cron-apt checks.

## Scope

If selected, install **OpenMediaVault 8** into the minimal Debian 13 system **during the customized installation, before first reboot**, after package and repository compatibility checks. Do not automatically configure NAS data disks, shared folders, SnapRAID, mergerfs, plugins, Docker integration, users or services beyond requirements explicitly stated here. The user will configure OMV after the first boot.

This is a separate selectable profile. The **Debian tweaks** profile and the optional Docker and ZRAM profiles must remain distinct.

## Critical compatibility gate: backports pin 900

The requested global preference for `trixie-backports` at **900** and stable/security at **500** can select newer dependencies that OMV does not support. OMV explicitly warns against inadvertently drawing core dependencies from Backports.

Before installing OMV:

1. Inspect effective `apt-cache policy` and simulate the OMV package transaction.
2. Inspect all proposed package changes, downgrades, package removals, and critical dependencies (especially networking, SSH, Python, systemd, web server and OMV plugins).
3. Resolve unsupported combinations by asking the user; do not silently alter the chosen global backports pin, force dependencies, skip OMV or mark profile success.
4. Verify repository signatures and supported OMV 8 release. **Do not blindly execute remote network scripts** during unattended installation. Use the official documented repository/key/package procedure, validated for the exact release.

## One explicitly approved OMV configuration change: no scheduled updates

The **OMV profile shall disable OMV's entire scheduled cron-apt workflow**, not just unattended installation of security patches. This removes scheduled OMV update checks/notifications too; manual refreshes and manual installations remain available.

Proposed command sequence, to confirm against the actually installed OMV 8 release:

```sh
omv-env set -- OMV_CRON_APT_ENABLED false
omv-salt deploy run cronapt
```

Before reporting success, inspect generated cron-apt configuration and ensure the job is genuinely disabled. Do not directly edit OMV-generated files if its supported environment-setting mechanism works. Independently verify Debian's automatic installation is disabled via [Debian tweaks](04_debian_tweaks.md), or a global installation guard if tweaks is not selected; OMV cron-apt is not equivalent to Debian unattended-upgrades.

## Preserve already approved access settings

OMV's documented Debian installation can change network configuration and enable root SSH, and the Debian-created user may be blocked from SSH unless in the `_ssh` group.

- Maintain wired DHCP connectivity (router IP reservation).
- Ensure `david` remains a sudo-capable SSH user; add appropriate `_ssh` membership if required by OMV.
- Ensure **root SSH login remains disabled** despite OMV defaults. Local root password remains set for emergency recovery; local root account and SSH access are separate controls.
- Check SSH password-auth behavior for `david`, which was initially approved.
- Stop on failure to preserve any agreed access behavior, with logs/diagnostics.

## First boot / acceptance

- OMV package and web interface installed, but **no NAS data-disk formatting/initialization**.
- OMV cron-apt scheduled checks and security auto-installs disabled.
- `david` SSH and sudo work; root SSH refused.
- Networking works; inspect routes, DNS, interfaces and OMV configuration.
- No silent partial install; failure policy is stop/diagnose/obtain approval.

## References

- [Official OMV 8 installation on Debian](https://docs.openmediavault.org/en/stable/installation/on_debian.html)
- [OMV 8 package and backports warning](https://docs.openmediavault.org/en/stable/various/apt.html)
- [OMV configuration management](https://docs.openmediavault.org/en/stable/various/advset.html)
- [OMV SSH behavior](https://docs.openmediavault.org/en/stable/administration/services/ssh.html)

**Unverified:** the exact availability and semantics of `OMV_CRON_APT_ENABLED` and the `cronapt` Salt deployment target in the final installed OMV version; both are hard gates.
