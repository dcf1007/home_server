# 02 — Optional Backports profile: Debian-default APT priority, upgrade and cleanup

**Status:** independently selectable installer profile, **unchecked by default**. **Recorded:** 2026-11-14. **Provenance:** user-selected revision returning Backports to the **Debian default priority** rather than globally preferring all backported packages, plus explicitly reviewed full upgrades, removals and post-upgrade autoremove/purge.

## Role in the installation

This optional profile:

1. Adds and verifies the signed Debian `trixie-backports` repository **only after explicit user selection**.
2. Preserves Debian's **built-in backports priority of 100** versus ordinary stable/security packages at the usual **500**, assuming no other target-release or local pin overrides. **Do not create a custom priority-900 pin**.
3. Refreshes APT metadata and performs the user's **explicitly reviewed upgrades of all eligible installed packages** under this default priority. This does **not** mean installing every package offered by Backports.
4. After successful upgrading, performs **reviewed autoremove and purge cleanup** with explicit approval for every proposed removal.
5. Revalidates package/database state before any selected dependent profile proceeds.

The **[09 — Ensure 7.x kernel branch](09_ensure_7x_kernel.md)** profile asks the user to select Backports **only when ordinary repositories do not provide a suitable Linux 7.x kernel**. It then selectively installs the kernel image and headers from Backports. **ZRAM depends on Ensure 7.x, not directly on Backports.** No profile is selected silently.

## 1. Repository configuration

Debian 13 repositories use official signed HTTPS Debian mirrors with binary package sources and components `main contrib non-free non-free-firmware`.

Default sources:

- `trixie` and `trixie-updates` at `https://deb.debian.org/debian`;
- `trixie-security` at `https://security.debian.org/debian-security`.

When and only when **Backports is explicitly selected**, add a `trixie-backports` source, for example `/etc/apt/sources.list.d/debian-backports.sources`:

```text
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

Do not automatically add `deb-src`, enable an APT proxy or broaden third-party repository trust.

## 2. **Restore and verify Debian's default Backports priority**

The upstream Backports Release metadata supplies `NotAutomatic: yes` and `ButAutomaticUpgrades: yes`, which normally result in priority **100**. Ordinary stable and security archives normally carry **500** without additional overrides.

**Superseded setting — do not install:**

```text
# Do not create /etc/apt/preferences.d/90-local-backports.pref
# Package: *
# Pin: release n=trixie-backports
# Pin-Priority: 900
```

The 900 pin belonged to an earlier design and is explicitly **revoked**. If a working system already has an overriding preferences file or `APT::Default-Release` setting, inspect it and request approval to correct it; do not assume an absent or effective priority.

Verification:

```sh
apt-get update
apt-cache policy
apt-cache policy linux-image-amd64 linux-headers-amd64
apt-config dump | grep -E 'Default-Release|Periodic|Unattended'
```

This policy **does not automatically select newer backports versions** over stable. An explicitly selected kernel 7.x profile may request `linux-image-amd64/trixie-backports` and `linux-headers-amd64/trixie-backports` when needed. Normal stable dependencies remain preferred unless a necessary backported dependency is specifically required.

## 3. Full upgrade of eligible installed packages — inside Backports

1. Refresh package indexes and verify signatures and effective APT priorities.
2. Simulate a **normal, non-targeted** `apt-get -s full-upgrade` and display the complete package action plan: upgrades, new dependencies, downgrades, held/unresolvable packages and any proposed removals.
3. **Explicitly approve the proposed transaction before execution.** Removals are **permitted only after full review and explicit approval**. Block changes that would compromise the installed system, selected profiles, network/SSH access, bootloader, the intended Linux 7.x kernel or its initial stable fallback.
4. Execute the approved normal `apt-get full-upgrade` **without `-t trixie-backports`**. The default APT priority means this upgrades eligible packages from stable, updates and security and **already-installed** backported packages as applicable, rather than installing all backports.
5. Confirm transaction success; run `dpkg --audit`, inspect `apt-mark showhold`, repeat a dry-run upgrade and check that no eligible installed package remains unupgraded under the verified policy. If a conflict or incomplete upgrade remains, **stop with diagnostics** rather than silently proceeding.

**Do not** treat the above one-time, explicitly approved install-stage transaction as authorization for unattended upgrades or future automatic reboots.

## 4. After upgrading: reviewed autoremove and purge leftovers

Perform cleanup **after** the successful upgrade, before declaring this profile complete:

1. **Simulate** `apt-get -s autoremove --purge` and enumerate every package and configuration slated for removal.
2. Explicitly display the list and **ask the user to approve** it. If it includes the new kernel, its headers, necessary boot support, an initial stable fallback kernel, or other required package, **stop and seek resolution**; do not silently remove it, force a different kernel retention policy or skip the conflict.
3. After approval, run `apt-get autoremove --purge` to remove no-longer-required automatic dependencies and purge their configuration files.
4. Inspect **residual configuration** left by already-removed packages, e.g.:

   ```sh
   dpkg -l | awk '$1 == "rc" {print $2}'
   ```

   List and review those residual packages; **only then** purge specifically approved entries with `dpkg --purge <approved-package-names>`. Never blindly purge all records or use an unreviewed shell expansion.
5. Verify `dpkg --audit`, critical installed packages, `apt-cache policy`, `apt-get -s autoremove --purge` and the intended boot entries again. If cleanup is incomplete or unsafe, stop for manual review.

**Stable kernel fallback nuance:** an earlier decision requires the original stable kernel to remain selectable **at first boot**, but no permanent custom kernel-retention policy. An immediate autoremove/purge must **not** remove that initial fallback. The final behavior when APT wants to purge the fallback is subject to explicit review, not silent permanent locking.

These actions belong to the Backports profile's **upgrade and cleanup** workflow. A selective kernel package installation done by [Ensure 7.x](09_ensure_7x_kernel.md) is a separate transaction; if it causes an upgrade, the same reviewed cleanup safeguards apply.

## 5. Package management remains manual

- `APT::Periodic::Unattended-Upgrade "0";` remains the manual-upgrades-only target. Debian tweaks installs its respective configuration, and the complete installer must validate that no other selected package has reenabled automated upgrades.
- Do **not** automatically install security, stable, backports or third-party package upgrades after the installation finishes.
- The OpenMediaVault profile separately disables OMV's scheduled `cron-apt` checks/installs; Docker remains off through first boot if selected.
- `apt-get full-upgrade` and `apt-get autoremove --purge` must never run unattended or without the required confirmation screens.

## 6. Acceptance and failure criteria

```sh
apt-cache policy
apt-cache policy linux-image-amd64 linux-headers-amd64
apt-get -s full-upgrade
apt-get -s autoremove --purge
apt-mark showhold
dpkg --audit
dpkg -l | awk '$1 == "rc" {print $2}'
```

- Backports effective priority **100**, ordinary stable/security generally **500**, with no unintended override.
- Full upgrade and cleanup were separately reviewed and completed, or installation is explicitly blocked.
- No unapproved package removals, no unmet dependencies, no erroneous kernel/bootstrap loss.
- Other profiles remain opt-in and unmodified unless explicitly selected.

## References

- [Official Debian Backports instructions](https://backports.debian.org/Instructions/)
- [Debian package manager/reference on APT priorities](https://www.debian.org/doc/manuals/debian-reference/ch02.en)
- [APT preferences manual](https://manpages.debian.org/trixie/apt/apt_preferences.5.en.html)
- [APT manual](https://manpages.debian.org/trixie/apt/apt.8.en.html)

**Validation status:** policy documented; installation transaction, early menu integration, cleanup confirmation prompts and real kernel compatibility are **not yet tested**.
