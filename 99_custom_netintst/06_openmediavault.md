# Netinst — OpenMediaVault 8 adaptation

**Simpler post-install route:** [07 — OMV 8](../07_openmediavault/README.md).

The installer uses selected-only [profile-omv.sh](my-cdd/installer/profile-omv.sh) instead of executing an unreviewed vendor installation script in the target. It checks DNS, retrieves the OMV signing key and official `synchrony` source, simulates the package transaction, installs OMV 8 and verifies its version.

After OMV installs, its selected profile preserves the chosen Debian administrator's sudo/`_ssh` access and denies root SSH. The approved scheduled-update policy uses OMV's actual `conf.system.apt.updates` and APT notification models, deploying only the `apt` and `apticron` Salt states, plus Debian's periodic APT settings.

**Installer-only issues:** target DNS can be affected by OMV, native service-start suppression, apt/dialog output routing and Salt execution inside `in-target`. The ordinary post-install guide uses OMV's officially documented Debian installer script and a separate policy step.

OMV-Extras, `openmediavault-compose` and Docker integration remain excluded. Source: [profile-omv.sh](my-cdd/installer/profile-omv.sh). History: [06 OMV planning](history/06_openmediavault.md).
