# Inputs for the selected Simple-CDD profiles

**Current packaging (2026-11-15):** Sources stay under `scripts/`, but their ownership is declared through matching native `profiles/*.extra` manifests rather than one global manifest. Source assets are present on the ISO but applied to the target only when selected.

These files are optional-profile assets, **not independent installer operations**. They are installed only when their corresponding optional profile is explicitly selected; the earlier build-host-only reprepro wrapper has been removed.

- `firmware-candidates.txt` — broad firmware list and **both** CPU microcode
  packages from [Extended device support](../../10_extended_device_support.md).
  Availability, origin, dependencies and any individually approved omissions
  must be resolved at installation time.
- `debian-backports.sources` — signed `trixie-backports` repository template,
  applicable **only if Backports was selected**; it does not impose a global pin.
- `90-zram-swappiness.conf` — `vm.swappiness=100`, **only for selected ZRAM**.
- `zram-generator.conf.template`, `zram-pressure.sh`,
  `10-compressed-writeback.conf`, and `zram-pressure.service` — source
  material extracted without modification from the
  [approved original ZRAM design](../../03_zram_writeback.md#original-design--complete-source).
  These original source assets are installed only when ZRAM is selected;
  their runtime compatibility and first-boot behavior remain untested.

The installed-target package transaction and ZRAM conversion/provisioning source
exist in `../installer/profile-zram.sh` (with shared helpers in `../installer/profile-common.sh`), but have **not been exercised or
validated in a real installer**. The generator `.template` name is deliberate:
`YOUR_PARTUUID` is replaced with the verified partition identity and the
installed target receives `/etc/systemd/zram-generator.conf`. No unrelated test harnesses
or independent inspection wrappers are part of this directory.
