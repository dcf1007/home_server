# 09 — Selectable **Ensure 7.x kernel branch** profile

**Status:** planned installer profile, not implemented or tested. **Recorded:** 2026-11-14. **Provenance:** installation-planning decisions, including the explicit requirement for the newest available Linux kernel on the **7.x branch**, a separately selected Backports profile if stable cannot supply it, and no version locks. This page supersedes earlier references that made Debian tweaks or ZRAM install the kernel directly.

## Scope and selection

- The **Ensure 7.x kernel branch** profile is an independently selectable, **unchecked-by-default** installer option.
- **ZRAM requires this profile.** If ZRAM is selected while Ensure 7.x is not selected, prompt the user to **select Ensure 7.x explicitly or deselect ZRAM**. Do not check the box automatically.
- This profile does **not** require Debian tweaks, Docker, or OMV.
- **Debian tweaks likewise does not require this profile.** It applies its non-GUI settings with Debian's standard installed kernel if Ensure 7.x remains unchecked. This kernel profile installs 7.x only when explicitly selected.
- **Menu order:** Backports → **Ensure 7.x** → Debian tweaks → Extended device support → ZRAM → OMV → Docker, skipping unchecked profiles. The Extended device support profile is independent of this kernel profile. This is an installer selection/execution requirement, distinct from documentation filename numbering.
- **Backports is another separately selectable profile**, also unchecked by default. This kernel profile requests it only when a suitable 7.x kernel is not available from ordinary Debian 13 repositories, never silently.
- Install the newest **eligible and compatible Linux 7.x** image and matching headers *in the installed target system* **before first reboot**; keep Debian's stable kernel selectable as an initial fallback, without custom retention policy or version holds.
- Do not substitute Linux 6.x or 8.x or silently lock to a numbered 7.x point release. Prefer the **moving** `linux-image-amd64` and `linux-headers-amd64` metapackages **when they actually resolve to Linux 7.x**. If the metadata no longer provides a moving 7.x route, stop for a new explicitly approved policy rather than hardcode a stale kernel.

## Decision workflow

1. **Refresh signed metadata** for the standard Debian repositories: `trixie`, `trixie-updates`, `trixie-security`. Inspect `apt-cache policy linux-image-amd64 linux-headers-amd64` and the actual dependency versions of the metapackages, not merely the displayed candidate string.
2. **If the newest suitable kernel in the normal repositories is on branch 7.x**, install those metapackages and their necessary dependencies from the standard sources. Verify matching headers, bootloader default and no unwanted removals.
3. **If no suitable 7.x candidate is available from normal Debian repositories**, interrupt the kernel profile and ask the user to **explicitly select [02 — Backports](02_backports_apt.md)** or **deselect/stop Ensure 7.x** (which also requires resolving any selected ZRAM dependency). Never select Backports without confirmation.
4. Once the user has selected Backports, **let that profile** enable `trixie-backports` at Debian's **default effective APT priority 100**, execute its separately reviewed upgrades and cleanup, and report success. This kernel profile **must not duplicate or silently bypass the Backports workflow**.
5. Requery candidates. When eligible backported kernel metapackages resolve to Linux 7.x, install **only the explicitly requested kernel metapackages and kernel-related required dependencies from backports**, preferring stable sources for other packages. Simulate the exact transaction and present any removals or material dependency upgrades for approval before applying. If required kernel packages cannot be resolved safely, stop.
6. Verify that the **newest available eligible 7.x kernel** and its matching headers were installed, `/boot` and GRUB have the expected entries, stable fallback kernel remains initially selectable, kernel packages are not held or pinned to exact versions, and the next normal boot targets Linux 7.x. The *running installer* may still use a different kernel; validate kernel-version facts again after first boot.
7. After any package-upgrade transaction required by this profile, apply the approved **reviewed autoremove/purge cleanup** described in [02 — Backports](02_backports_apt.md). Confirm that the cleanup does **not remove the initial fallback kernel, bootloader, current target kernel, headers, or critical dependencies**. If it would, stop and ask; never bypass required cleanup silently.

## Example inspection and selective backports installation

These are **illustrative commands, not a tested install script**. Execute only after explicit profile selection and package-candidate validation.

```sh
apt-get update
apt-cache policy linux-image-amd64 linux-headers-amd64
apt-cache show linux-image-amd64 | grep -E '^(Package|Version|Depends):'
apt-cache show linux-headers-amd64 | grep -E '^(Package|Version|Depends):'

# ONLY IF the Backports profile has been explicitly selected and completed:
apt-cache policy linux-image-amd64 linux-headers-amd64
apt-get -s install linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports
# Execute the explicitly reviewed transaction if it resolves to compatible 7.x:
apt-get install linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports
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
