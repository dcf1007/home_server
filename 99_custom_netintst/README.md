# 99 — Custom Debian 13 netinst with Simple-CDD

**Advanced, optional route:** build a custom **Debian 13 (Trixie) amd64** netinst ISO that offers the same independently selectable features as the ordinary installed-system guides.

For a freshly installed server, **do not start here**. Follow [01 — Base Debian](../01_base_debian/README.md) and the optional [02–08 guides](../README.md). Those use full Debian utilities and ordinary interactive package installation. This section exists specifically to address **Debian Installer limitations**: udebs, Simple-CDD profile selection, cdebconf, preseed/late_command, target chroots and ISO package staging.

The directory name `99_custom_netintst` follows the exact requested rename from `01_custom_netinst`.

## Build the custom ISO

~~~sh
git clone https://github.com/dcf1007/home_server.git
cd home_server/99_custom_netintst/my-cdd
./build.sh
~~~

To update an existing checkout, run `git pull --ff-only` from the repository before building. Use a compatible Debian build host with `git`, `simple-cdd` and `reprepro` installed; see [build preparation](01_custom_cdd_preparation.md) and [my-cdd README](my-cdd/README.md). The intended output is `my-cdd/images/debian-13-amd64-CD-1.iso`.

**Source state:** the seven optional profiles and their execution order are unchanged. None is selected automatically. The latest ZRAM implementation uses native `parted-udeb`, `util-linux-udeb`, BusyBox and installer `/proc`/`/sys` data, not full installed-system block tools. **Build and end-to-end installer validation remain necessary; a successful ISO build does not prove functionality.**

## How each ordinary Debian step is adapted

| Post-install chapter | Debian Installer integration |
| --- | --- |
| [01 — Base Debian](../01_base_debian/README.md) | [Native installer screens, editable defaults](05_base_installation.md) |
| [02 — Backports](../02_backports/README.md) | [Selected-only signed source, APT review](02_backports_apt.md) |
| [03 — Linux 7.x](../03_kernel_7x/README.md) | [Suite selection and installed-target kernel verification](09_ensure_7x_kernel.md) |
| [04 — Extended support](../04_extended_device_support/README.md) | [Package omission and firmware-license Debconf bridge](10_extended_device_support.md) |
| [05 — ZRAM writeback](../05_zram_writeback/README.md) | [Native udeb partition discovery and approval](03_zram_writeback.md) |
| [06 — Debian tweaks](../06_debian_tweaks/README.md) | [Selected-only edits of /target](04_debian_tweaks.md) |
| [07 — OpenMediaVault](../07_openmediavault/README.md) | [Signed OMV install and Salt from installer](06_openmediavault.md) |
| [08 — Docker](../08_docker/README.md) | [Signed Docker installation via in-target](07_docker.md) |

The source modules live under [my-cdd/installer/](my-cdd/installer/), package selections under [my-cdd/profiles/](my-cdd/profiles/) and source assets under [my-cdd/scripts/](my-cdd/scripts/). Keep the ordinary installed-system workflow and the minimal installer implementation distinct.

For build/integration checks, see [validation gates](08_validation_and_pending.md). Complete historical planning documents (including the original full ZRAM design) are preserved in [history/](history/).
