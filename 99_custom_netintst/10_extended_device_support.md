# Netinst — Extended firmware adaptation

**Normal procedure:** [04 — Extended support](../04_extended_device_support/README.md).

The custom installer retains the original broad [firmware candidate inventory](my-cdd/scripts/firmware-candidates.txt), including **both** CPU microcode packages. If Backports was selected, the [firmware profile](my-cdd/installer/profile-firmware.sh) inspects compatible per-package Backports selectors first, with reviewed normal Debian fallbacks; global Backports priority stays 100.

Unlike regular Debian, the installer cannot rely on the installed target's native Debconf frontend for packages whose license prompt needs explicit consent. The source therefore extracts the *exact APT-selected binary package's own* `firmware-ipw2x00`/`firmware-ivtv` license question and presents it in the existing installer GUI. A declined license or unavailable/conflicting package requires **separate approval of that named omission** and a new combined transaction simulation.

Do not replace this with a blanket license acceptance, silently skip packages or add the firmware to an unconditional profile queue. The ordinary post-install howto simply runs interactive `apt-get install`, which can display the native package licenses directly.

History: [10 firmware planning](history/10_extended_device_support.md).
