# 10 — Selectable **Extended device support** profile

**Status:** documented and **independently selectable**, initially unchecked; no installer script, dependency transaction or device-specific driver test has yet been completed. **Recorded:** 2026-11-14. **Provenance:** the hardware-related settings moved without losing the approved package inventory from [04 — Debian tweaks](04_debian_tweaks.md), as requested in the current installation-planning conversation.

## Scope and profile independence

This profile provides additional **CPU microcode and firmware**. It does **not** install Linux 7.x, activate Backports, configure ZRAM, or apply the operating-system changes in Debian tweaks. Those remain separately selectable.

Debian Installer's normal hardware detection and baseline firmware availability remain unchanged when this optional profile is **unchecked**. This profile owns **additional proactive firmware coverage** and an attempt to install **both Intel and AMD CPU microcode packages**, independent of the CPU actually detected. Never select another profile silently.

No hardware serial numbers, fixed device paths, or undocumented device-specific assumptions are embedded in the installer. Package names and installation transactions must be checked against the actual running hardware, selected repository policy, and other selected profiles.

## Approved hardware-related settings moved from Debian tweaks

- **Attempt to install both** `intel-microcode` **and** `amd64-microcode` from Debian's `non-free-firmware` component on amd64, **regardless of detected CPU vendor**. Simulate both in the same package transaction with the full firmware inventory; do not pre-filter or auto-omit the package for the other CPU vendor. Each package must succeed or have an **individually, explicitly approved omission** under the procedure below.
- Preserve Debian Installer's automatic firmware lookup and install **broad additional firmware coverage**, including wired networking, storage/HBA controllers, Wi-Fi, Bluetooth, graphics, audio and miscellaneous common hardware families. The user specifically selected broad coverage, **not just detected hardware**. The following is a **provisional package-name inventory**, checked against published Debian 13 (Trixie) package listings, **not yet an approved or simulated install transaction**.

### Provisional broad firmware candidate list

Package names below exist in Debian 13 package listings for firmware. Exact version/candidate, dependency conflicts, available architecture, repository selection with **Debian-default Backports priority 100, only if its profile is selected**, overlaps/metapackages and license/interactive debconf effects still require validation. **Unavailable/conflicting firmware or CPU-microcode packages may be omitted only after the installer lists each package, explains its specific reason, and receives explicit user approval for that omission.** Never silently omit coverage or force an unvalidated installation.

| Coverage | Candidate Debian binary packages |
|---|---|
| Common kernel + miscellaneous | `firmware-linux`, `firmware-linux-nonfree`, `firmware-misc-nonfree`, `firmware-intel-misc` |
| Ethernet/NICs and storage/HBAs | `firmware-realtek`, `firmware-bnx2`, `firmware-bnx2x`, `firmware-cavium`, `firmware-marvell-prestera`, `firmware-myricom`, `firmware-netronome`, `firmware-netxen`, `firmware-qlogic` |
| Wireless / Wi-Fi | `firmware-atheros`, `firmware-brcm80211`, `firmware-iwlwifi`, `firmware-ipw2x00`, `firmware-libertas`, `firmware-mediatek`, `firmware-ti-connectivity`, `firmware-ath9k-htc`, `firmware-carl9170`, `firmware-zd1211` |
| Graphics / GPU / media | `firmware-amd-graphics`, `firmware-intel-graphics`, `firmware-nvidia-graphics`, `firmware-ast`, `firmware-qcom-soc`, `firmware-samsung`, `firmware-siano`, `firmware-ivtv` |
| Audio / Bluetooth / peripheral | `firmware-cirrus`, `firmware-intel-sound`, `firmware-sof-signed`, `bluez-firmware` |

**Notes:** `firmware-linux`/`firmware-linux-nonfree` are metapackages and may already pull `firmware-misc-nonfree`; avoid duplicated intent. `firmware-qcom-media` is a dummy transitional package and intentionally not a useful additional firmware candidate. The list may be trimmed **only after** exact package availability/compatibility verification and **explicit approval of every proposed omission**; absence of matching detected hardware alone is not permission to omit proactive firmware coverage. **Both** `intel-microcode` and `amd64-microcode` are intended to be installed even when only one vendor is present. This does **not** mean both sets of microcode will be applied by the CPU; only applicable microcode is loaded by the boot/kernel mechanism. Combined installation and any package or initramfs hooks must be validated rather than assumed compatible.

**Mandatory pre-implementation evidence:** refresh signed APT metadata, run `apt-cache policy` and `apt-get -s install` for the exact final package set under the **actual selected APT policy** (Backports priority **100**, if explicitly selected) and other selected profiles (especially OMV), inspect removals and dependency changes, verify that no extra proprietary drivers or DKMS modules are implicitly installed, record every excluded firmware **or microcode** package with its specific reason and the user's explicit approval, and present the final effective package list for confirmation. Auto-detection continues even if this extra-package step is unready.

**Upstream package references:** [Debian 13 Intel microcode](https://packages.debian.org/trixie/intel-microcode), [Debian 13 AMD microcode](https://packages.debian.org/trixie/amd64-microcode), [Debian CPU microcode guidance](https://wiki.debian.org/Microcode), [Debian 13 firmware-nonfree source package](https://packages.debian.org/source/trixie/firmware-nonfree), [Debian 13 firmware package search](https://packages.debian.org/search?keywords=firmware&searchon=names&suite=trixie), [Debian firmware installer behavior](https://wiki.debian.org/Firmware/), [Intel SOF package](https://packages.debian.org/trixie/firmware-sof-signed).

## Approved exception handling: unavailable or conflicting firmware **and microcode** packages

**Decision recorded 2026-11-14:** This profile requests **both** microcode packages plus all compatible packages from its broad firmware inventory, including packages for hardware not currently detected. If **any requested firmware or microcode package** is unavailable or cannot be installed without a conflict, use this interactive procedure **before changing the requested package set**:

1. For **every affected firmware or microcode package**, display its exact package name and the reason it cannot be installed (e.g., absent signed APT candidate for this architecture, unresolvable dependencies, package conflict, disallowed removal). Show the actual source/candidate and relevant dependency/impact information when known. **Do not guess at reasons or hide other exclusions.**
2. Present an explicit choice for **each**: **approve omission of this named firmware/microcode package** or **decline and stop the Extended device support profile**. A blanket acknowledgment, silence, a default-checked option or confirmation of an unrelated APT transaction is **not** approval of an omission.
3. If the user explicitly approves the omissions, build and **re-simulate the revised package transaction**. Continue only with **all remaining compatible firmware and microcode packages**; show the final exact installation set and obtain the normal transaction approval. Do not omit the other vendor's microcode merely because its CPU is absent. If new unresolvable/conflicting packages appear, return for **new explicit omission decisions**; never omit them automatically.
4. **Record each approved omission** in the installation evidence: exact package name, reason and dependency/conflict details, explicit approval decision, final retained package set and outcome. Include these records in the approved **complete/unredacted installer diagnostics**, copied to `/target/var/log/installer/` and the installer USB where safely writable; always display diagnostics and offer manual export.
5. If an omission was **not approved**, or the remaining transaction cannot be completed safely, **stop with diagnostics**. If an actual package install fails after a simulated transaction, first diagnose the failed package and APT/dpkg state; request individual omission approval only if the remaining package state can be made consistent through a separately reviewed, explicitly authorized transaction. Never silently mark a failed or half-configured package as omitted. An omission approval does not override separate safety gates for bootability, disk access, network/SSH access, signed repositories, system integrity or package removals. All package-removal operations retain their own explicit review and approval requirements.

**Microcode-specific review:** Both microcode packages are independently eligible for an explicitly approved omission. For each microcode omission, warn whether the package corresponds to the **detected CPU vendor** and that missing applicable updates may affect security or stability. Vendor detection is only for explanation and post-install verification, **not a criterion for skipping either package**. The user's approval must identify the exact package being omitted.

**Feasibility:** Debian 13 publishes both packages for amd64. Debian documentation typically instructs users to install the one matching their CPU; **simultaneous installation here is the user's custom policy**, not a claim that all Debian release/package combinations have been tested. Always validate both candidates and simulate the combined transaction.

## Validation and acceptance

The exact broad firmware package set is **provisional**, and the source guide's package-name inventory is not evidence that the complete transaction succeeds. Before executing:

1. Request **both** `intel-microcode` and `amd64-microcode`, independently of CPU vendor. Use CPU detection only to explain the implications of any proposed omission, and to verify whether applicable microcode was loaded after boot. Confirm both packages' candidates and origins, simulate the combined APT transaction and check that package hooks and generated boot artifacts remain functional.
2. Simulate **both microcode packages plus the full requested additional firmware set** with `apt-get -s install`, inspect dependencies, removals, potential DKMS/proprietary driver changes and source/signature validity. List **every unavailable/conflicting firmware or microcode package with a specific reason**, ask for **explicit approval of each omission**, and stop if approval is withheld. Re-simulate the remaining set, display the final package list, and obtain separate approval of the actual transaction.
3. If Backports was selected, respect its **default effective priority 100**. Do not enable Backports or change APT pinning from this profile.
4. **Install both microcode packages and all remaining compatible firmware and microcode** after the reviewed omissions and final transaction approval. Record omitted names, reasons and approvals in the complete installer logs; never silently narrow coverage. Stop on unresolved compatibility or dependency failures, and preserve diagnostics.

Example post-installation checks (not proof of a working installer profile):

```sh
dpkg-query -W intel-microcode amd64-microcode 2>/dev/null || true
apt-cache policy firmware-linux firmware-realtek firmware-iwlwifi
dpkg --audit
```

**Boundaries:** [04 — Debian tweaks](04_debian_tweaks.md) handles deliberate operating-system overrides; [09 — Ensure 7.x](09_ensure_7x_kernel.md) handles kernel image and headers; [03 — ZRAM](03_zram_writeback.md) handles compressed swap. This hardware profile has no generic OS-tuning duties.

**No implementation claim:** This documentation split changes the *planned selectable profiles*. The corresponding Simple-CDD profile definitions, package lists, post-install scripts and installer review screens have not been generated or tested.
