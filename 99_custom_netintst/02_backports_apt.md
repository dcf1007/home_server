# Netinst — Backports adaptation

**Normal installed-system procedure:** [02 — Backports](../02_backports/README.md).

During installation there is no standing administrator shell and the new OS is under `/target`. The selected-only [profile-backports.sh](my-cdd/installer/profile-backports.sh) copies the signed Debian Backports source into that target, uses reviewed `in-target apt-get` operations and checks the normal priority **100**.

The custom installer must show the *complete* simulation, request explicit approval for the upgrade and each proposed removal, preserve the working Stable kernel fallback, and avoid a priority-900 global pin. It must not activate Backports if the corresponding profile is unchecked.

**Why different from the ordinary guide:** the extra Debconf approval, stdout passthrough and target-chroot handling exist solely because operations happen from Debian Installer. The post-install guide can simply run `apt-get` and ask the administrator to review the native APT transaction.

Source: [installer/profile-backports.sh](my-cdd/installer/profile-backports.sh). Historical policy and design: [history/02_backports_apt.md](history/02_backports_apt.md).
