# 10 — Selectable **Extended device support** profile

**Status:** independently selectable in Simple-CDD, initially unchecked, with a source routine for Backports-first selection, Stable fallbacks, individual omissions and a final combined package review. The original 37-package inventory is unchanged. **No actual transaction, installer dialog or driver compatibility has been validated.** **Recorded:** 2026-11-14. **Provenance:** the hardware-related settings moved without losing the approved package inventory from [04 — Debian tweaks](04_debian_tweaks.md), as requested in the current installation-planning conversation.

## Scope and profile independence

This profile provides additional **CPU microcode and firmware**. It does **not** install Linux 7.x, activate Backports, configure ZRAM, or apply the operating-system changes in Debian tweaks. Those remain separately selectable. **If Backports was explicitly selected and completed earlier**, this profile prefers eligible `trixie-backports` package versions for its requested firmware and both microcode packages, using selective per-package requests rather than a global APT preference.

Debian Installer's normal hardware detection and baseline firmware availability remain unchanged when this optional profile is **unchecked**. This profile owns **additional proactive firmware coverage** and an attempt to install **both Intel and AMD CPU microcode packages**, independent of the CPU actually detected. Never select another profile silently.

No hardware serial numbers, fixed device paths, or undocumented device-specific assumptions are embedded in the installer. Package names and installation transactions must be checked against the actual running hardware, selected repository policy, and other selected profiles.

## Approved hardware-related settings moved from Debian tweaks

- **Attempt to install both** `intel-microcode` **and** `amd64-microcode` from Debian's `non-free-firmware` component on amd64, **regardless of detected CPU vendor**. Simulate both in the same package transaction with the full firmware inventory; do not pre-filter or auto-omit the package for the other CPU vendor. Each package must succeed or have an **individually, explicitly approved omission** under the procedure below.
- Preserve Debian Installer's automatic firmware lookup and install **broad additional firmware coverage**, including wired networking, storage/HBA controllers, Wi-Fi, Bluetooth, graphics, audio and miscellaneous common hardware families. The user specifically selected broad coverage, **not just detected hardware**. The following is a **provisional package-name inventory**, checked against published Debian 13 (Trixie) package listings, **not yet an approved or simulated install transaction**.

### Provisional broad firmware candidate list

Package names below exist in Debian 13 package listings for firmware. Exact version/candidate, dependency conflicts, available architecture, **Backports-first selection if its profile was explicitly selected (while the global Backports priority remains 100)**, overlaps/metapackages and license/interactive debconf effects still require validation. **Unavailable/conflicting firmware or CPU-microcode packages may be omitted only after the installer lists each package, explains its specific reason, and receives explicit user approval for that omission.** Never silently omit coverage or force an unvalidated installation.

| Coverage | Candidate Debian binary packages |
|---|---|
| Common kernel + miscellaneous | `firmware-linux`, `firmware-linux-nonfree`, `firmware-misc-nonfree`, `firmware-intel-misc` |
| Ethernet/NICs and storage/HBAs | `firmware-realtek`, `firmware-bnx2`, `firmware-bnx2x`, `firmware-cavium`, `firmware-marvell-prestera`, `firmware-myricom`, `firmware-netronome`, `firmware-netxen`, `firmware-qlogic` |
| Wireless / Wi-Fi | `firmware-atheros`, `firmware-brcm80211`, `firmware-iwlwifi`, `firmware-ipw2x00`, `firmware-libertas`, `firmware-mediatek`, `firmware-ti-connectivity`, `firmware-ath9k-htc`, `firmware-carl9170`, `firmware-zd1211` |
| Graphics / GPU / media | `firmware-amd-graphics`, `firmware-intel-graphics`, `firmware-nvidia-graphics`, `firmware-ast`, `firmware-qcom-soc`, `firmware-samsung`, `firmware-siano`, `firmware-ivtv` |
| Audio / Bluetooth / peripheral | `firmware-cirrus`, `firmware-intel-sound`, `firmware-sof-signed`, `bluez-firmware` |

**Notes:** `firmware-linux`/`firmware-linux-nonfree` are metapackages and may already pull `firmware-misc-nonfree`; avoid duplicated intent. `firmware-qcom-media` is a dummy transitional package and intentionally not a useful additional firmware candidate. The list may be trimmed **only after** exact package availability/compatibility verification and **explicit approval of every proposed omission**; absence of matching detected hardware alone is not permission to omit proactive firmware coverage. **Both** `intel-microcode` and `amd64-microcode` are intended to be installed even when only one vendor is present. This does **not** mean both sets of microcode will be applied by the CPU; only applicable microcode is loaded by the boot/kernel mechanism. Combined installation and any package or initramfs hooks must be validated rather than assumed compatible.

**Mandatory pre-implementation evidence:** refresh signed APT metadata; inspect `apt-cache policy` and exact candidate origins **for every requested firmware/microcode package**; simulate the complete selected-version transaction with `apt-get -s install` under the actual APT policy (default Backports priority **100**, if selected), explicitly requesting Backports versions where available; and review dependencies with all other selected profiles (especially OMV). Inspect removals and dependency changes, verify that no extra proprietary drivers or DKMS modules are implicitly installed, record stable fallbacks and individually approved omissions with actual reasons, and present the final package names, versions and origins for confirmation. Auto-detection continues even if this extra-package step is unready.

**Upstream package references:** [Debian 13 Intel microcode](https://packages.debian.org/trixie/intel-microcode), [Debian 13 AMD microcode](https://packages.debian.org/trixie/amd64-microcode), [Debian CPU microcode guidance](https://wiki.debian.org/Microcode), [Debian 13 firmware-nonfree source package](https://packages.debian.org/source/trixie/firmware-nonfree), [Debian 13 firmware package search](https://packages.debian.org/search?keywords=firmware&searchon=names&suite=trixie), [Debian firmware installer behavior](https://wiki.debian.org/Firmware/), [Intel SOF package](https://packages.debian.org/trixie/firmware-sof-signed).

## Approved Backports-first selection for microcode and firmware

**Decision recorded 2026-11-14:** When both **Backports** and **Extended device support** are explicitly selected, prefer usable versions of **every requested firmware package plus both `intel-microcode` and `amd64-microcode` from `trixie-backports`**. This is a **targeted exception for packages owned by this profile**, not a system-wide preference for Backports.

1. **Profile ordering:** the Backports profile enables the repository and completes its separately approved eligible-package `full-upgrade` and cleanup **first**; the Ensure 7.x kernel profile runs in its established position, then Extended device support selects its own packages. Do not enable Backports here or change kernel selection, APT preferences or the approved seven-profile menu.
2. **Discover actual candidates:** for every requested firmware/microcode package, inspect available versions and release origins with `apt-cache policy <package>`. If a compatible `trixie-backports` version is published and accessible, **prefer that version first**. Do not assume all firmware/microcode packages have a Backports version. Do not force downgrades or unsafe dependencies merely to satisfy a suite preference.
3. **Select per package:** explicitly request Backports versions with **`<package>/trixie-backports`** (or an equivalently precise reviewed version selection), and include ordinary Stable candidates where no viable Backports version exists. **Do not use a blanket `apt-get -t trixie-backports install ...`** or global priority/pin change: those could prefer additional backported dependencies unnecessarily. Explicitly request additional backported dependencies only if genuinely necessary, with their effects shown in the transaction review.
4. **Fallback order and approved confirmation granularity (Decision 115, option A):** if no usable Backports version exists or its installation is unsafe, use a compatible normal Debian Stable/Updates/Security version **without treating it as an omission**. Show **every such Stable fallback** by exact package name, selected version, source suite/origin, and the specific reason Backports was not chosen in the **single final simulated APT transaction review**. **No additional individual approval prompt is needed for each Stable fallback**; the user's explicit approval of the clearly itemized final transaction authorizes those listed fallback versions. If any fallback candidate or reason changes, re-simulate and seek fresh final approval. If neither Backports nor Stable provides a usable package, apply the separate **individual, explicitly approved omission** procedure. Package removals, downgrades and other safety-sensitive changes retain their separately required review and approval; a fallback does not override them.
5. **Review and record:** simulate the **whole mixed-source transaction** and show each package's selected version/source, **the itemized name/version/origin/reason for every Stable fallback**, any additional Backports dependencies, proposed removals and consequences for kernel/OMV/Docker. **One explicit final transaction approval covers all clearly listed Stable fallbacks**, with no per-fallback dialog. **Actual omissions still require individual approval**; package removals and material safety exceptions require their existing separate approvals. Install only the reviewed set; record origins, fallback reasons, omissions, approvals and results in the full unredacted installer diagnostics. Do not infer real installation success from a simulated transaction.

**When Backports is unchecked:** this profile uses the normal signed Debian 13 repositories only; it never silently selects or enables Backports just to obtain a firmware/microcode package. If no usable candidate remains, the approved individual omission workflow applies.

**Illustrative APT selection (not a tested installer script):**

```sh
# Only if Backports was already explicitly selected and enabled:
apt-cache policy intel-microcode amd64-microcode firmware-realtek
apt-get -s install intel-microcode/trixie-backports firmware-realtek/trixie-backports

# The real transaction must dynamically include only packages verified
# to have eligible Backports versions; the example must not be run blindly.
# Other requested packages can be selected from Stable where appropriate.
```

Debian's [official Backports instructions](https://backports.debian.org/Instructions/) distinguish targeted `package/trixie-backports` installation from `-t trixie-backports` and confirm the standard priority **100**. This feature has **not** been implemented or transaction-tested.

## Approved exception handling: unavailable or conflicting firmware **and microcode** packages

**Decision recorded 2026-11-14:** This profile requests **both** microcode packages plus all compatible packages from its broad firmware inventory, including packages for hardware not currently detected. If **any requested firmware or microcode package** is unavailable or cannot be installed without a conflict, use this interactive procedure **before changing the requested package set**:

1. **After checking the Backports-first route (if selected) and eligible normal-repository fallbacks**, for **every affected firmware or microcode package** that still cannot be installed, display its exact package name and the reason it cannot be installed (e.g., absent signed APT candidate for this architecture in either allowed suite, unresolvable dependencies, package conflict, disallowed removal). Show the actual source/candidate and relevant dependency/impact information when known. **Do not guess at reasons or hide other exclusions.**
2. Present an explicit choice for **each**: **approve omission of this named firmware/microcode package** or **decline and stop the Extended device support profile**. A blanket acknowledgment, silence, a default-checked option or confirmation of an unrelated APT transaction is **not** approval of an omission.
3. If the user explicitly approves the omissions, build and **re-simulate the revised package transaction**. Continue only with **all remaining compatible firmware and microcode packages**; show the final exact installation set and obtain the normal transaction approval. Do not omit the other vendor's microcode merely because its CPU is absent. If new unresolvable/conflicting packages appear, return for **new explicit omission decisions**; never omit them automatically.
4. **Record each approved omission** in the installation evidence: exact package name, reason and dependency/conflict details, explicit approval decision, final retained package set and outcome. Include these records in the approved **complete/unredacted installer diagnostics**, copied to `/target/var/log/installer/` and the installer USB where safely writable; always display diagnostics and offer manual export.
5. If an omission was **not approved**, or the remaining transaction cannot be completed safely, **stop with diagnostics**. If an actual package install fails after a simulated transaction, first diagnose the failed package and APT/dpkg state; request individual omission approval only if the remaining package state can be made consistent through a separately reviewed, explicitly authorized transaction. Never silently mark a failed or half-configured package as omitted. An omission approval does not override separate safety gates for bootability, disk access, network/SSH access, signed repositories, system integrity or package removals. All package-removal operations retain their own explicit review and approval requirements.

**Microcode-specific review:** Both microcode packages are independently eligible for an explicitly approved omission. For each microcode omission, warn whether the package corresponds to the **detected CPU vendor** and that missing applicable updates may affect security or stability. Vendor detection is only for explanation and post-install verification, **not a criterion for skipping either package**. The user's approval must identify the exact package being omitted.

**Feasibility:** Debian 13 publishes both packages for amd64. Debian documentation typically instructs users to install the one matching their CPU; **simultaneous installation here is the user's custom policy**, not a claim that all Debian release/package combinations have been tested. Always validate both candidates and simulate the combined transaction.

## Validation and acceptance

The exact broad firmware package set is **provisional**, and the source guide's package-name inventory is not evidence that the complete transaction succeeds. Before executing:

1. Request **both** `intel-microcode` and `amd64-microcode`, independently of CPU vendor. Use CPU detection only to explain the implications of any proposed omission, and to verify whether applicable microcode was loaded after boot. Confirm both packages' candidates and origins, simulate the combined APT transaction and check that package hooks and generated boot artifacts remain functional.
2. Simulate **both microcode packages plus the full requested additional firmware set** with `apt-get -s install`, explicitly requesting **each eligible Backports version first if Backports was selected**, or normal-repository versions otherwise. Inspect dependencies, removals, potential DKMS/proprietary driver changes and source/signature validity. Evaluate Stable alternatives when Backports packages cannot safely resolve. Show each Stable fallback's **package, exact version, origin and reason** together in the **final transaction review**, where **one explicit transaction approval covers all listed fallbacks**. List **every truly unavailable/conflicting firmware or microcode package** with its specific reason, seek **individual approval of each omission**, and stop if withheld. Re-simulate and present the final package list before installation.
3. If Backports was selected, respect its **default effective priority 100**, while selectively targeting eligible firmware and both microcode packages from `trixie-backports` first. Record their origins and any necessary backported dependencies. Do not enable Backports, apply global `-t`, change APT pinning or override the normal Backports profile's separately reviewed upgrade/cleanup.
4. **Install both microcode packages and all remaining compatible firmware and microcode** after reviewing any Stable fallbacks, individually approved omissions and the final mixed-source transaction. Record omitted names, reasons and approvals in the complete installer logs; never silently narrow coverage. Stop on unresolved compatibility or dependency failures, and preserve diagnostics.

Example post-installation checks (not proof of a working installer profile):

```sh
dpkg-query -W intel-microcode amd64-microcode 2>/dev/null || true
apt-cache policy firmware-linux firmware-realtek firmware-iwlwifi
dpkg --audit
```

**Boundaries:** [04 — Debian tweaks](04_debian_tweaks.md) handles deliberate operating-system overrides; [09 — Ensure 7.x](09_ensure_7x_kernel.md) handles kernel image and headers; [03 — ZRAM](03_zram_writeback.md) handles compressed swap. This hardware profile has no generic OS-tuning duties.

**Implementation status (2026-11-15):** the unchanged broad firmware and both-microcode package inventory is consumed by `my-cdd/installer/profile-actions.sh`, where the Backports-first, stable-fallback, individual omission and final transaction review flows are implemented as source. The optional `.packages` queue is intentionally empty and `.postinst` checks completion of the native installer-stage action. **No actual APT transaction, UI approval or hardware validation has been completed.**
