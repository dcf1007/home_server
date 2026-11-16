# 03 — Install an eligible Linux 7.x kernel (optional)

**What this does:** installs a Linux **7.x kernel and matching headers** while keeping your working Debian kernel as a boot fallback. This project's [ZRAM writeback setup](../05_zram_writeback/README.md) depends on this step.

Do not assume that a particular 7.x version will remain available. Check the versions offered by your configured Debian repositories at the time of installation.

## Step 1 — See which kernels Debian offers

~~~sh
sudo apt update
~~~

~~~sh
apt policy linux-image-amd64 linux-headers-amd64
~~~

Look at the available versions and where they come from. Both the kernel image and its headers must belong to the **7.x branch**.

For more information about their dependencies:

~~~sh
apt show linux-image-amd64
~~~

~~~sh
apt show linux-headers-amd64
~~~

If you have Backports enabled, also inspect the package pages for **Trixie Backports** or the additional available versions listed by `apt policy`. The moving image and header packages must resolve to the **same 7.x kernel ABI**. Version numbers will change over time.

If your enabled sources do not offer a compatible 7.x pair, **stop**. You can choose to enable [Backports](../02_backports/README.md); do not silently use a different kernel branch.

## Step 2 — Install the matching image and headers

**Option A — 7.x is already the normal Debian candidate.**

~~~sh
sudo apt install linux-image-amd64 linux-headers-amd64
~~~

**Option B — You enabled Backports and its image and headers resolve to 7.x.**

~~~sh
sudo apt install linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports
~~~

Use **only one** option after checking the offered versions. APT will show the planned changes before installing. If it proposes removing your working Debian kernel or bootloader, say **No** and investigate.

## Step 3 — Update the boot files

~~~sh
sudo update-initramfs -u -k all
~~~

~~~sh
sudo update-grub
~~~

Keep the original Stable kernel available in GRUB until you have successfully booted the new one.

## Step 4 — Reboot and confirm the result

~~~sh
sudo reboot
~~~

Once Debian starts, check the running kernel:

~~~sh
uname -r
~~~

It must begin with `7.`. Now inspect the installed headers:

~~~sh
ls /usr/src
~~~

Find a `linux-headers-...` directory that **exactly matches** the kernel reported by `uname -r`. If there is no matching directory, the kernel/header installation is incomplete.

~~~sh
sudo dpkg --audit
~~~

**Done when:** Linux 7.x is actually running, matching headers are installed, and the original Stable kernel remains a selectable fallback.

**Important:** A 7.x version alone does not prove that ZRAM compressed writeback is supported. Check the actual ZRAM features in [05](../05_zram_writeback/README.md).

**References:** [Debian Backports](https://backports.debian.org/Instructions/) · [Available Trixie Backports kernel](https://packages.debian.org/trixie-backports/linux-image-amd64).
