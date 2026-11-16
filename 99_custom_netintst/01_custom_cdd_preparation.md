# Netinst — Build and profile preparation

**Ordinary server setup:** [01–08 installed-system howtos](../README.md). This page covers **only** Simple-CDD/udev/installer build concerns.

The untouched [my-cdd source project](my-cdd/) uses **Simple-CDD 0.6.9** and Debian 13 amd64. There are seven optional profiles in this order:

1. Backports
2. Ensure 7.x kernel
3. Extended device support
4. ZRAM writeback
5. Debian tweaks
6. OpenMediaVault 8
7. Docker

All start unchecked. A separate early Debconf summary validates the selection and requires default-No confirmation. Later the [ordered dispatcher](my-cdd/installer/run-selected.sh) performs only selected actions with additional package and destructive confirmations. ZRAM requires explicit selection of Ensure 7.x; Debian tweaks, OMV and Docker remain independent.

## Build host and inputs

~~~sh
sudo apt-get update
sudo apt-get install git simple-cdd reprepro
git clone https://github.com/dcf1007/home_server.git
cd home_server/99_custom_netintst/my-cdd
./build.sh
~~~

The build uses a guarded **two-stage** `build-simple-cdd --mirror-only` then `--build-only` flow, retaining upstream Simple-CDD `default.*` lists. The build-only `installer-media` profile includes `zstd` in the ordinary ISO package pool and `parted-udeb`/`util-linux-udeb` in the installer package pool. None is an eighth optional user profile.

Check [profile_defaults.conf](my-cdd/profile_defaults.conf) for editable GUI suggestions. Do not put passwords, disk identifiers or selected profile flags in it. The build script checks shell syntax, generated input, staged assets, `zstd` and the two udebs, and preserves build logs. The ISO path is `images/debian-13-amd64-CD-1.iso` under `my-cdd/`.

**Not proven:** GTK/text Debconf frontend integration, full netinst progression, ZRAM conversion or first boot. The installer must be tested with disposable VM disks. [Validation checklist](08_validation_and_pending.md).

For earlier implementation decisions and build failures, see [historical preparation](history/01_custom_cdd_preparation.md).
