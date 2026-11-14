# Custom profile source material (not installed by this scaffold)

This directory contains **read-only validation helpers** and **proposed ZRAM configuration assets**. Nothing here is an installed package, executable installer stage, or permission to modify the selected OS installation disk.

- `firmware-candidates.txt`: provisional broad firmware inventory from [the approved guide](../../10_extended_device_support.md). Includes **both** Intel and AMD CPU microcode names.
- `apt-simulate.sh`: displays package origins and dry-run APT transactions; does not grant approval or execute installs.
- `inspect-zram-backing.sh`: read-only information for an **explicitly provided PARTUUID**. Does not attempt `swapoff`, modify GPT, or clear signatures.
- `verify-source-layout.sh`: checks expected project profile files, order and lack of automatic optional-package queueing.
- `zram-pressure.sh`, `zram-generator.conf.template`, `10-compressed-writeback.conf` and `zram-pressure.service`: **verbatim extracted code blocks** from the [original ZRAM design](../../03_zram_writeback.md#original-design--complete-source). The untouched source remains in that guide; code here is **untested** and `YOUR_PARTUUID` is a placeholder. Do not deploy or run without verifying Linux 7.x, generator syntax, sysfs interfaces, systemd ordering and the separately approved destructive partition conversion.

The intended executable install-time profile runner, interactive approval UI, signed-repository checks, startup suppression, diagnostic persistence and ZRAM partition manipulation **are not yet implemented**. They must not be implied by these files.
