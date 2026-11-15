# 09 — Selectable **Ensure 7.x kernel branch** profile

**Status:** source routine now selects and simulates candidate moving Linux 7.x kernel/header metapackages, checks exact installed header ABI, and records user approval. **Not executed or verified in Debian Installer.** **Recorded:** 2026-11-14. **Provenance:** installation-planning decisions, including the explicit requirement for the newest eligible Linux kernel on the **7.x branch**, **Backports-first kernel selection when Backports is selected**, a separately selected Backports profile if normal Debian repositories cannot supply 7.x, and no version locks. This page supersedes earlier references that made Debian tweaks or ZRAM install the kernel directly.

## Scope and selection

- The **Ensure 7.x kernel branch** profile is an independently selectable, **unchecked-by-default** installer option.
- **ZRAM requires this profile.** If ZRAM is selected while Ensure 7.x is not selected, prompt the user to **select Ensure 7.x explicitly or deselect ZRAM**. Do not check the box automatically.
- This profile does **not** require Debian tweaks, Docker, or OMV.
- **Debian tweaks likewise does not require this profile.** It applies its non-GUI settings with Debian's standard installed kernel if Ensure 7.x remains unchecked. This kernel profile installs 7.x only when explicitly selected.
- **Menu order:** Backports → **Ensure 7.x** → Extended device support → ZRAM → Debian tweaks → OMV → Docker, skipping unchecked profiles. The Extended device support profile is independent of this kernel profile. This is an installer selection/execution requirement, distinct from documentation filename numbering.
- **Backports is another separately selectable profile**, also unchecked by default. **When Backports is already selected, this kernel profile checks usable Backports 7.x packages first, then normal Debian 7.x candidates if necessary.** When Backports is unselected, it checks normal repositories first and offers explicit Backports selection only if no suitable 7.x candidate exists. Never enable another profile silently.
- Install the newest **eligible and compatible Linux 7.x within the preferred available source** (Backports first **when selected**, otherwise normal Debian repositories) and matching headers *in the installed target system* **before first reboot**; keep Debian's stable kernel selectable as an initial fallback, without custom retention policy or version holds.
- Do not substitute Linux 6.x or 8.x or silently lock to a numbered 7.x point release. Prefer the **moving** `linux-image-amd64` and `linux-headers-amd64` metapackages **when they actually resolve to Linux 7.x**. If the metadata no longer provides a moving 7.x route, stop for a new explicitly approved policy rather than hardcode a stale kernel.

## Decision workflow

1. **Refresh signed metadata** and inspect the actual origin, dependency kernel branch and eligible package versions for `linux-image-amd64` and `linux-headers-amd64` in all **enabled** sources. An APT default candidate may be from Stable even though a selectable Backports version is available at priority 100; use `apt-cache policy` and inspect matching image/header dependencies.
2. **If Backports is explicitly selected and already completed:** **check `trixie-backports` first** for compatible moving kernel metapackages resolving to Linux **7.x** with matching headers. When viable, simulate and request these packages **explicitly as `linux-image-amd64/trixie-backports` and `linux-headers-amd64/trixie-backports`**, selecting necessary kernel-related backported dependencies but preferring ordinary Stable dependencies otherwise. Keep global APT priority **100**, and never run a blanket `-t trixie-backports` to install unrelated backported packages.
3. **Fallback after Backports-first inspection:** if a usable Backports 7.x image/headers pair is missing or cannot be resolved safely, inspect eligible **normal Debian Stable/Updates/Security 7.x** candidates before failing. Present the fallback version/source and the actual reason, and obtain approval for the complete simulated transaction. Do not silently downgrade to an older kernel branch or automatically abandon the explicitly selected 7.x profile.
4. **If Backports is not selected:** inspect normal Debian repositories first for an eligible Linux **7.x** metapackage and matching headers, then simulate and approve that transaction. If none exists, ask to **explicitly select [02 — Backports](02_backports_apt.md)** or stop/deselect Ensure 7.x (and resolve any ZRAM dependency). Never enable Backports silently.
5. **If Backports must be newly selected:** run the Backports profile's repository activation, **default-priority 100** APT upgrade, reviewed cleanup and validation first, then return to **step 2**. The Ensure 7.x profile must **not** duplicate or bypass the Backports workflow.
6. **Before installing:** simulate the exact selected image/header packages and dependencies; show origins, versions, significant upgrades, removals and any stable fallback choice; require explicit approval. Reject unsafe or unresolved transactions. Keep the initially installed Stable kernel available as a first-boot fallback.
7. **Verify** that the newest eligible Linux **7.x** in the **selected preferred viable source** and its matching headers were installed, GRUB defaults to the 7.x kernel, the Stable fallback remains initially selectable, and no exact-version pin or hold was introduced. The running installer kernel can differ; check again on first boot.
8. **After package-upgrade transactions**, apply the separately reviewed **autoremove/purge cleanup** in [02 — Backports](02_backports_apt.md), never silently removing the initial Stable fallback or other critical packages.

**Source preference is conditional, not global:** With selected Backports, prefer its eligible Linux 7.x kernel packages over Stable 7.x packages. Without selected Backports, use normal repositories until explicitly authorized otherwise. This preference is for the **Ensure 7.x** kernel transaction only; **Extended device support** separately prefers Backports firmware and microcode when Backports is selected. No global pin, implicit optional-profile selection or unattended upgrades.

## Example inspection and selective backports installation

These are **illustrative commands, not a tested install script**. Execute only after explicit profile selection and package-candidate validation.

```sh
apt update
apt-cache policy linux-image-amd64 linux-headers-amd64
apt-cache show linux-image-amd64 | grep -E '^(Package|Version|Depends):'
apt-cache show linux-headers-amd64 | grep -E '^(Package|Version|Depends):'

# ONLY IF the Backports profile has been explicitly selected and completed:
apt-cache policy linux-image-amd64 linux-headers-amd64
apt -s install linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports
# Execute the explicitly reviewed transaction if it resolves to compatible 7.x:
apt install linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports
```

The `package/trixie-backports` syntax selects that package version while favoring normal stable dependencies where possible. `-t trixie-backports` changes the target-release preference for that transaction and can broaden dependencies from backports; **do not use it silently as a substitute**. Packages absent from stable but required as dependencies may still come from backports, subject to simulation and approval.

## Verification / acceptance

```sh
apt-cache policy linux-image-amd64 linux-headers-amd64
dpkg-query -W -f='${Package} ${Version}\n' linux-image-amd64 linux-headers-amd64
dpkg --audit
apt-mark showhold
ls -l /boot/vmlinuz* /boot/initrd.img*
grep -E '^(GRUB_DEFAULT|GRUB_TIMEOUT)' /etc/default/grub
```

After boot, `uname -r` must identify a compatible Linux **7.x** kernel. If ZRAM is selected, test the compressed-writeback interfaces as specified in [03 — ZRAM](03_zram_writeback.md).

### Mandatory caution: kernel retention versus cleanup

Kernel maintenance and `autoremove --purge` can propose removing older kernels. The earlier decision is to retain the **stable kernel as an initial boot fallback**, without imposing custom permanent kernel retention. Therefore **do not purge the fallback in the installation's immediate cleanup**. If the cleanup proposes removing it, stop for explicit resolution rather than making a silent policy exception.

## Sources

- [Debian Backports instructions — default priority and selective installs](https://backports.debian.org/Instructions/)
- [Debian APT preferences and priorities](https://manpages.debian.org/trixie/apt/apt_preferences.5.en.html)
- [Debian package listing — linux-image-amd64 in trixie-backports](https://packages.debian.org/trixie-backports/linux-image-amd64)

**Not yet validated:** release-specific candidate versions at actual installation time; APT dependency resolution, apt/dpkg execution, kernel installer hooks, GRUB generation, matching headers, and all applicable cleanup operations.
