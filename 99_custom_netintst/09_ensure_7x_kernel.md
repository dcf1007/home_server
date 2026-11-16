# Netinst — Linux 7.x kernel adaptation

**Normal procedure:** [03 — Linux 7.x kernel](../03_kernel_7x/README.md).

The independently selected [profile-kernel.sh](my-cdd/installer/profile-kernel.sh) checks signed APT candidates from enabled suites. If Backports was explicitly selected, it evaluates compatible 7.x Backports image/headers first; otherwise it checks normal Debian suites first. It never silently selects another profile or installs 6.x/8.x instead.

Before applying packages, the installer shows a full transaction review through native Debconf; after installation it verifies matching `/target/boot/vmlinuz-7.*` and `/target/usr/src/linux-headers-*` entries and regenerates initramfs and GRUB. Existing Stable kernel boot access must be retained.

**Installer-specific difficulty:** detecting an eligible moving metapackage version while managing suite selectors through target `apt-get` and native GUI authorization. None of the extra Debconf bridging is needed on an installed system.

History: [09 kernel planning](history/09_ensure_7x_kernel.md).
