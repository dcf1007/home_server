# 10 — Selectable **Extended device support** profile

**Status:** documented and **independently selectable**, initially unchecked; no installer script, dependency transaction or device-specific driver test has yet been completed. **Recorded:** 2026-11-14. **Provenance:** the hardware-related settings moved without losing the approved package inventory from [04 — Debian tweaks](04_debian_tweaks.md), as requested in the current installation-planning conversation.

## Scope and profile independence

This profile provides additional **CPU microcode and firmware**. It does **not** install Linux 7.x, activate Backports, configure ZRAM, or apply the operating-system changes in Debian tweaks. Those remain separately selectable.

Debian Installer's normal hardware detection and baseline firmware availability remain unchanged when this optional profile is **unchecked**. This profile owns **additional proactive firmware coverage** and vendor-specific CPU microcode installation only. Never select another profile silently.

No hardware serial numbers, fixed device paths, or undocumented device-specific assumptions are embedded in the installer. Package names and installation transactions must be checked against the actual running hardware, selected repository policy, and other selected profiles.

## Approved hardware-related settings moved from Debian tweaks

- Automatically detect CPU vendor and install `intel-microcode` or `amd64-microcode` from the Debian firmware component.
- Preserve Debian Installer's automatic firmware lookup and install **broad additional firmware coverage**, including wired networking, storage/HBA controllers, Wi-Fi, Bluetooth, graphics, audio and miscellaneous common hardware families. The user specifically selected broad coverage, **not just detected hardware**. The following is a **provisional package-name inventory**, checked against published Debian 13 (Trixie) package listings, **not yet an approved or simulated install transaction**.

### Provisional broad firmware candidate list

Package names below exist in Debian 13 package listings for firmware. Exact version/candidate, dependency conflicts, available architecture, repository selection with **Debian-default Backports priority 100, only if its profile is selected**, overlaps/metapackages and license/interactive debconf effects still require validation. **Unavailable/conflicting firmware packages may be omitted only after the installer lists each package, explains its specific reason, and receives explicit user approval for that omission.** Never silently omit coverage or force an unvalidated installation.

| Coverage | Candidate Debian binary packages |
|---|---|
| Common kernel + miscellaneous | `firmware-linux`, `firmware-linux-nonfree`, `firmware-misc-nonfree`, `firmware-intel-misc` |
| Ethernet/NICs and storage/HBAs | `firmware-realtek`, `firmware-bnx2`, `firmware-bnx2x`, `firmware-cavium`, `firmware-marvell-prestera`, `firmware-myricom`, `firmware-netronome`, `firmware-netxen`, `firmware-qlogic` |
| Wireless / Wi-Fi | `firmware-atheros`, `firmware-brcm80211`, `firmware-iwlwifi`, `firmware-ipw2x00`, `firmware-libertas`, `firmware-mediatek`, `firmware-ti-connectivity`, `firmware-ath9k-htc`, `firmware-carl9170`, `firmware-zd1211` |
| Graphics / GPU / media | `firmware-amd-graphics`, `firmware-intel-graphics`, `firmware-nvidia-graphics`, `firmware-ast`, `firmware-qcom-soc`, `firmware-samsung`, `firmware-siano`, `firmware-ivtv` |
| Audio / Bluetooth / peripheral | `firmware-cirrus`, `firmware-intel-sound`, `firmware-sof-signed`, `bluez-firmware` |

**Notes:** `firmware-linux`/`firmware-linux-nonfree` are metapackages and may already pull `firmware-misc-nonfree`; avoid duplicated intent. `firmware-qcom-media` is a dummy transitional package and intentionally not a useful additional firmware candidate. The list may be trimmed **only after** exact package availability/compatibility verification and **explicit approval of every proposed omission**; absence of matching detected hardware alone is not permission to omit proactive firmware coverage. CPU microcode (`intel-microcode` or `amd64-microcode`) remains chosen according to detected CPU family, not both indiscriminately.

**Mandatory pre-implementation evidence:** refresh signed APT metadata, run `apt-cache policy` and `apt-get -s install` for the exact final package set under the **actual selected APT policy** (Backports priority **100**, if explicitly selected) and other selected profiles (especially OMV), inspect removals and dependency changes, verify that no extra proprietary drivers or DKMS modules are implicitly installed, record every excluded package with its specific reason and the user's explicit approval, and present the final effective package list for confirmation. Auto-detection continues even if this extra-package step is unready.

**Upstream package references:** [Debian 13 firmware-nonfree source package](https://packages.debian.org/source/trixie/firmware-nonfree), [Debian 13 firmware package search](https://packages.debian.org/search?keywords=firmware&searchon=names&suite=trixie), [Debian firmware installer behavior](https://wiki.debian.org/Firmware/), [Intel SOF package](https://packages.debian.org/trixie/firmware-sof-signed).

## Approved exception handling: unavailable or conflicting firmware packages

**Decision recorded 2026-11-14:** This profile should install all compatible packages from its approved broad firmware inventory, including packages for hardware not currently detected. If a firmware package is **unavailable or cannot be installed without a conflict**, use this interactive procedure **before changing the requested package set**:

1. For **every affected firmware package**, display its exact package name and the reason it cannot be installed (e.g., absent signed APT candidate for this architecture, unresolvable dependencies, package conflict, disallowed removal). Show the actual source/candidate and relevant dependency/impact information when known. **Do not guess at reasons or hide other exclusions.**
2. Present an explicit choice for **each**: **approve omission of this named firmware package** or **decline and stop the Extended device support profile**. A blanket acknowledgment, silence, a default-checked option or confirmation of an unrelated APT transaction is **not** approval of an omission.
3. If the user explicitly approves the omissions, build and **re-simulate the revised package transaction**. Continue only with all remaining compatible firmware packages and the independently selected CPU-vendor microcode; show the final exact installation set and obtain the normal transaction approval. If new unresolvable/conflicting packages appear, return for **new explicit omission decisions**; never omit them automatically.
4. **Record each approved omission** in the installation evidence: exact package name, reason and dependency/conflict details, explicit approval decision, final retained package set and outcome. Include these records in the approved **complete/unredacted installer diagnostics**, copied to `/target/var/log/installer/` and the installer USB where safely writable; always display diagnostics and offer manual export.
5. If an omission was **not approved**, or the remaining transaction cannot be completed safely, **stop with diagnostics**. An omission approval does not override separate safety gates for bootability, disk access, network/SSH access, signed repositories, system integrity or package removals. All package-removal operations retain their own explicit review and approval requirements.

**Scope of the new omission exception:** The user explicitly specified **firmware packages**. The handling of a missing or conflicting **CPU-vendor microcode** package is a distinct potential policy choice; this document does not silently extend the firmware exception to it.

## Validation and acceptance

The exact broad firmware package set is **provisional**, and the source guide's package-name inventory is not evidence that the complete transaction succeeds. Before executing:

1. Detect CPU manufacturer reliably and select **only the appropriate** `intel-microcode` or `amd64-microcode` package. Verify availability, package origin and microcode installation; never install both indiscriminately.
2. Simulate the full requested additional firmware set with `apt-get -s install`, inspect dependencies, removals, potential DKMS/proprietary driver changes and source/signature validity. List **every unavailable/conflicting firmware package with a specific reason**, ask for **explicit approval of each omission**, and stop if approval is withheld. Re-simulate the remaining set, display the final package list, and obtain separate approval of the actual transaction.
3. If Backports was selected, respect its **default effective priority 100**. Do not enable Backports or change APT pinning from this profile.
4. **Install all remaining compatible firmware** after the reviewed omissions and final transaction approval. Record omitted names, reasons and approvals in the complete installer logs; never silently narrow coverage. Stop on unresolved compatibility or dependency failures, and preserve diagnostics.

Example post-installation checks (not proof of a working installer profile):

```sh
dpkg-query -W intel-microcode amd64-microcode 2>/dev/null || true
apt-cache policy firmware-linux firmware-realtek firmware-iwlwifi
dpkg --audit
```

**Boundaries:** [04 — Debian tweaks](04_debian_tweaks.md) handles deliberate operating-system overrides; [09 — Ensure 7.x](09_ensure_7x_kernel.md) handles kernel image and headers; [03 — ZRAM](03_zram_writeback.md) handles compressed swap. This hardware profile has no generic OS-tuning duties.

**No implementation claim:** This documentation split changes the *planned selectable profiles*. The corresponding Simple-CDD profile definitions, package lists, post-install scripts and installer review screens have not been generated or tested.
