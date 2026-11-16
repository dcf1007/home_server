# Installer media assets

These files are **inputs to selected Simple-CDD profiles**, staged on the custom ISO through the respective `profiles/*.extra` manifests. None is applied merely because it exists on the ISO.

- `firmware-candidates.txt`: both CPU microcode packages and the broad firmware list; a separately usable copy exists in [the ordinary firmware guide](../../../05_extended_device_support/firmware-candidates.txt).
- `debian-backports.sources`: optional signed Debian Backports source, priority 100 without a global pin.
- `zram-generator.conf.template`, `zram-pressure.sh`, `zram-pressure.service`, `override.conf`, `90-zram.conf`: ZRAM generator, setup, sysctl and monitor assets, copied into the [standalone ZRAM guide](../../../06_zram_writeback/files) for ordinary Debian use.

The installer loads these from the ISO and provisions `/target` only when the corresponding profile was explicitly selected. The source `YOUR_PARTUUID` placeholder is replaced by the actual verified GPT partition UUID.

The full original ZRAM design remains in [history](../../history/03_zram_writeback.md#original-design--complete-source). Runtime behavior has not been validated on the target 7.x kernel.
