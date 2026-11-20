# home_server — Debian 13 NAS and home server

This repository is a **step-by-step guide for a Debian 13 (Trixie) NAS/home server**. Every numbered chapter describes how to apply its feature **yourself on a normally installed Debian system**. Only the final custom-netinst chapter explains how to build the equivalent Debian Installer automation.

The recommended order is:

| Chapter | Why it belongs here |
| --- | --- |
| [01 — Base Debian](01_base_debian/README.md) | Install headless Debian, create a sudo administrator and enable local root recovery |
| [02 — Debian tweaks](02_debian_tweaks/README.md) | Configure boot messages, filesystem-aware root mounts, native SSH and one-time update policy first |
| [03 — Backports](03_backports/README.md) | Add signed optional newer Debian packages |
| [04 — Linux 7.x](04_kernel_7x/README.md) | Install an eligible Linux 7.x image and matching headers |
| [05 — Extended device support](05_extended_device_support/README.md) | Install broad firmware and Intel/AMD microcode |
| [06 — ZSTD ZRAM writeback](06_zram_writeback/README.md) | Configure compressed swap using a separately approved partition |
| [07 — OpenMediaVault 8](07_openmediavault/README.md) | Add NAS management without OMV-Extras or Compose |
| [08 — Docker](08_docker/README.md) | Install official Docker Engine and Compose independently |
| [09 — Optional local Wayland session](09_labwc/README.md) | Manual labwc + terminal/browser configuration (not included in custom ISO) |
| [99 — Custom netinst construction](99_custom_netintst/README.md) | Build the corresponding optional installer profiles and ISO |

## How to follow a guide

Start with [01](01_base_debian/README.md). Then apply only the optional chapters you want. **02 is recommended immediately after 01**, because it establishes fundamental boot and SSH settings before other installations.

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

The numbered order describes **dependencies and a safe working sequence**, not a requirement to install every feature. In particular, the intended ZRAM writeback configuration requires a compatible Linux 7.x kernel, so [04](04_kernel_7x/README.md) must be completed before [06](06_zram_writeback/README.md).

</td>
</tr>
</table>

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

Each command is preceded by an explanation of its purpose, what it changes or reports, and what you should check. Follow commands **one at a time**. Instructions to **open a configuration file in a text editor** are deliberately editor-neutral: read what the file currently contains, make only the described change, save it and preserve any other settings. When a command contains placeholders such as `YOUR_PARTITION` or `YOUR_USERNAME`, identify the correct value on your own system before executing it.

</td>
</tr>
</table>

If you want a local copy of these guides, first install Git. This installs the repository client, not any NAS service:

~~~sh
sudo apt install git
~~~

Then download the repository (without running its installer code):

~~~sh
git clone https://github.com/dcf1007/home_server.git
~~~

Change into the downloaded directory so relative file paths resolve:

~~~sh
cd home_server
~~~

## The custom installer is a separate construction project

The [99_custom_netintst](99_custom_netintst/README.md) documentation teaches you **how to write and connect** the Simple-CDD installer components, including complete source files, package inventories, udeb-only workarounds and verification. These are **not commands to run on an already installed server**.

**Synchronization rule:** whenever a feature changes in an ordinary Debian chapter, review the corresponding custom-netinst construction chapter **and installer implementation** in the same change. If the installer must behave differently because Debian Installer lacks ordinary system tools or services, document the reason explicitly. Also update the embedded complete source listings, expected Git blob hashes, links and [provenance](GUIDE_PROVENANCE.md).

The custom ISO's end-to-end and first-boot checks remain **incomplete**. The latest VM successfully reached an OMV APT simulation but the project's unrequested package-removal blacklist stopped it on `systemd-timesyncd`. The current review branch removes that blacklist and other unrequested installer restrictions, retaining full transaction review, user consent and selected-ZRAM partition confirmation. See [validation](99_custom_netintst/validation_and_pending.md).
