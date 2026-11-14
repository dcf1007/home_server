# 02 — Optional Backports profile: Debian-default APT priority, upgrade and cleanup

**Status:** independently selectable installer profile, **unchecked by default**. **Recorded:** 2026-11-14. **Provenance:** user-selected revision returning Backports to the **Debian default priority** rather than globally preferring all backported packages, plus explicitly reviewed full upgrades, removals and post-upgrade autoremove/purge.

## Role in the installation

This optional profile:

1. Adds and verifies the signed Debian `trixie-backports` repository **only after explicit user selection**.
2. Preserves Debian's **built-in backports priority of 100** versus ordinary stable/security packages at the usual **500**, assuming no other target-release or local pin overrides. **Do not create a custom priority-900 pin**.
3. Refreshes APT metadata and performs the user's **explicitly reviewed upgrades of all eligible installed packages** under this default priority. This does **not** mean installing every package offered by Backports.
4. After successful upgrading, performs **reviewed autoremove and purge cleanup** with explicit approval for every proposed removal.
5. Revalidates package/database state before any selected dependent profile proceeds.

The **[09 — Ensure 7.x kernel branch](09_ensure_7x_kernel.md)** profile prefers a compatible Linux 7.x **Backports** kernel and matching headers **when Backports is explicitly selected**. Otherwise it searches normal Debian repositories first, offering explicit Backports selection only if needed. The separate [10 — Extended device support](10_extended_device_support.md) profile likewise **prefers eligible Backports versions of its firmware and both microcode packages when Backports is already selected**, falling back to suitable normal-repository packages after review; an unresolvable package requires individually approved omission. **ZRAM depends on Ensure 7.x, not directly on Backports.** No profile is selected silently.

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

**Mirror/download failures:** rely on Debian Installer's normal network, mirror and package-retrieval prompts where they apply; do **not** create additional custom mirror dialogs or a mirror-persistence decision. For an error during this optional Backports profile, reuse an existing supported installer recovery facility if available; otherwise stop with diagnostics and explicit manual resolution. Preserve signed HTTPS repository metadata, `Signed-By` and Backports priority **100**; after source/candidate changes, re-simulate and obtain approvals. Never silently skip an unfinished selected Backports profile or its reviewed upgrade/cleanup.

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

This global APT policy **does not automatically select newer Backports versions** over Stable. **Selected downstream profiles deliberately request particular versions**: if Backports is selected, Ensure 7.x prefers eligible `linux-image-amd64/trixie-backports` and `linux-headers-amd64/trixie-backports`; Extended device support similarly prefers `<firmware-or-microcode-package>/trixie-backports` where available and compatible. Use per-package suite selection, **not blanket `-t trixie-backports` or a global priority override**; normal Stable dependencies remain preferred unless specific Backports dependencies are necessary and explicitly reviewed. If no usable Backports candidate exists, review a normal-repository version before considering individual omission of firmware/microcode. For Extended device support, **show each Stable fallback by name, version, source and reason in the final APT transaction review**; the user's **one explicit approval of that transaction covers all disclosed Stable fallbacks**, but **every actual omission still requires separate individual approval**. If Backports is unselected, leave both profiles on their established normal-repository-first paths.

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

These actions belong to the Backports profile's **upgrade and cleanup** workflow. Selective Backports-first package installations by [Ensure 7.x](09_ensure_7x_kernel.md) and [Extended device support](10_extended_device_support.md) are **separate reviewed transactions after this profile**, not permission to alter its ordinary `full-upgrade` policy. Apply the same review/cleanup safeguards if those later transactions introduce dependency changes or upgrades.

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
