# home_server — Debian 13 NAS and home server

A step-by-step guide for a **fresh Debian 13 (Trixie) server**, with an optional custom installer for reproducing the same result.

Each numbered chapter can be followed independently on an already installed Debian server using ordinary system tools. Select only the features you want; none silently enables another.

| Chapter | Function |
| --- | --- |
| [01 — Base Debian](01_base_debian/README.md) | Minimal headless Debian 13, accounts and disks |
| [02 — Backports](02_backports/README.md) | Signed Backports at Debian priority 100, reviewed upgrades |
| [03 — Kernel 7.x](03_kernel_7x/README.md) | An eligible moving 7.x kernel and matching headers |
| [04 — Extended device support](04_extended_device_support/README.md) | Broad firmware inventory and both CPU microcode packages |
| [05 — ZSTD ZRAM writeback](05_zram_writeback/README.md) | Compressed swap backed by an approved raw partition |
| [06 — Debian tweaks](06_debian_tweaks/README.md) | Boot, ext4, SSH and manual-update policy |
| [07 — OpenMediaVault 8](07_openmediavault/README.md) | NAS management without OMV-Extras or Compose |
| [08 — Docker](08_docker/README.md) | Official Docker Engine and Compose, independent of OMV |
| [99 — Custom netinst](99_custom_netintst/README.md) | Simple-CDD build, udeb limitations, installer integration |

## How to follow the guides

Each chapter is written for a person working at a terminal, **one command at a time**. Text shown as a configuration file belongs **inside that file**, not in the terminal. When a command contains a name such as `YOUR_PARTITION` or `YOUR_USERNAME`, replace it with the value from your own machine before running it. Do not use sample disk names verbatim.

The instructions use the `nano` text editor, which you can install with `sudo apt install nano` if it is not already available. To save in nano, press **Ctrl+O**, Enter and **Ctrl+X**. When APT shows proposed package changes, read them before confirming.

**Do not run every optional chapter just because it is numbered.** Choose the features you actually want.

## Usage

On a normally installed server, obtain these guides with:

~~~sh
sudo apt-get install git
git clone https://github.com/dcf1007/home_server.git
cd home_server
~~~

1. Install Debian 13 amd64, then review [01](01_base_debian/README.md). The reference 256 GB system SSD and 32 GB RAM are examples, not fixed values.
2. Apply whichever optional chapters you choose. When combining them, the numbered order is recommended. The specific ZRAM writeback design requires a supported **Linux 7.x** kernel first, so complete [03](03_kernel_7x/README.md) before [05](05_zram_writeback/README.md).
3. Confirm package changes and disk targets yourself. Don't run destructive commands on guessed devices.
4. Use [99](99_custom_netintst/README.md) only when you need the same features implemented **inside Debian Installer**. Its additional complexity is for udeb/boot-media compatibility, not for an ordinary installed server.

**Validation:** These documents specify procedures and source decisions; they do not claim a completed end-to-end server deployment. The custom ISO's installer and first-boot tests remain open. See [validation](99_custom_netintst/08_validation_and_pending.md) and [provenance](GUIDE_PROVENANCE.md).

The original `01_custom_netinst` guide and build tree was moved to the requested `99_custom_netintst` path on 2026-11-16.
