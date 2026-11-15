# Inputs for the selected Simple-CDD profiles

These are source assets, **not independently executed installer steps**. They are
used only when their corresponding optional profile is explicitly selected and
its approved installation routine is implemented.

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
exist in `../installer/profile-actions.sh`, but have **not been exercised or
validated in a real installer**. The generator `.template` name is deliberate:
`YOUR_PARTUUID` is replaced with the verified partition identity and the
installed target receives `/etc/systemd/zram-generator.conf`. No unrelated test harnesses
or independent inspection wrappers are part of this directory.
