# 04 — Install an eligible Linux 7.x kernel (optional)

**What this does:** installs a Linux **7.x kernel and matching headers** while keeping your working Debian kernel as a boot fallback. This project's [ZRAM writeback setup](../06_zram_writeback/README.md) depends on this step.

Do not assume that a particular 7.x version will remain available. Check the versions offered by your configured Debian repositories at the time of installation.

<table>
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv-warning.svg" width="72" height="72" alt="Warning: OMV configuration"><br><span aria-hidden="true">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span></td>
<td valign="top">

**When OMV is installed:** OMV may independently enable the kernel Backports repository and apply targeted image/header preferences. This can affect moving metapackage candidates and future kernel upgrades irrespective of the earlier manual Backports choice. Verify the actual package origins and matching ABI; OMV's preferences do not enforce this project's Linux 7.x requirement. See [Chapter 07 — OMV configuration ownership and checks](../07_openmediavault/README.md#omv-8-configuration-ownership-and-post-install-checks). No kernel-retention or repository-policy change is implied by this note.

</td>
</tr>
</table>

## Step 1 — See which kernels Debian offers

This refreshes package metadata before making any kernel decision. It does not upgrade or install packages; stop if repository updates fail.

~~~sh
sudo apt update
~~~

This shows the versions, origins and default candidates for both kernel metapackages. Check whether an eligible **7.x image and matching headers** are actually available, rather than assuming that a package called `linux-image-amd64` means 7.x.

~~~sh
apt policy linux-image-amd64 linux-headers-amd64
~~~

Look at the available versions and where they come from. Both the kernel image and its headers must belong to the **7.x branch**.

For more information about their dependencies:

This displays the image metapackage’s description and dependency information. Read its `Depends` field to see which real kernel image it would install; the selected image must be from the **7.x** branch.

~~~sh
apt show linux-image-amd64
~~~

This displays the headers metapackage’s dependencies. Compare its kernel version/ABI with the image from the previous command; if they differ, do not proceed.

~~~sh
apt show linux-headers-amd64
~~~

If you have Backports enabled, also inspect the package pages for **Trixie Backports** or the additional available versions listed by `apt policy`. The moving image and header packages must resolve to the **same 7.x kernel ABI**. Version numbers will change over time.

If your enabled sources do not offer a compatible 7.x pair, **stop**. You can choose to enable [Backports](../03_backports/README.md); do not silently use a different kernel branch.

## Step 2 — Install the matching image and headers

**Option A — 7.x is already the normal Debian candidate.**

This requests the ordinary Debian image and header metapackages. Use it **only if the checked default versions both resolve to matching 7.x packages**. APT presents the actual changes before you agree; decline any removal of your working fallback.

~~~sh
sudo apt install linux-image-amd64 linux-headers-amd64
~~~

**Option B — You enabled Backports and its image and headers resolve to 7.x.**

This explicitly selects Backports versions of the moving image and header packages. Use it **only when Backports was enabled and both versions were verified to be compatible 7.x**. APT’s proposal must still be reviewed before approval.

~~~sh
sudo apt install linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports
~~~

Use **only one** option after checking the offered versions. APT will show the planned changes before installing. If it proposes removing your working Debian kernel or bootloader, say **No** and investigate.

## Step 3 — Update the boot files

This regenerates initramfs images for **all installed kernels**, so the boot environment includes the drivers and configuration needed at startup. Check the output for failures and stop if any kernel image fails to update.

~~~sh
sudo update-initramfs -u -k all
~~~

This regenerates GRUB’s boot menu entries. Confirm its messages detect the new 7.x kernel **and the older fallback**; this does not choose a kernel automatically for this session.

~~~sh
sudo update-grub
~~~

Keep the original Stable kernel available in GRUB until you have successfully booted the new one.

## Step 4 — Reboot and confirm the result

This restarts the server so it can boot a newly installed kernel. Save your work and make sure you have local or remote recovery access first; a reboot interrupts running services.

~~~sh
sudo reboot
~~~

Once Debian starts, check the running kernel:

This prints the kernel **actually running after reboot**, not merely one installed on disk. Confirm its version starts with `7.`; if it is still 6.x, inspect GRUB selection before continuing.

~~~sh
uname -r
~~~

It must begin with `7.`. Now inspect the installed headers:

This lists the installed kernel source/header directories. Find `linux-headers-<exact version from uname -r>`; a similarly numbered but different ABI is not sufficient.

~~~sh
ls /usr/src
~~~

Find a `linux-headers-...` directory that **exactly matches** the kernel reported by `uname -r`. If there is no matching directory, the kernel/header installation is incomplete.

This looks for unfinished package installations/configurations. Normally it prints nothing; repair anything it reports before proceeding to ZRAM.

~~~sh
sudo dpkg --audit
~~~

**Done when:** Linux 7.x is actually running, matching headers are installed, and the original Stable kernel remains a selectable fallback.

**Important:** A 7.x version alone does not prove that ZRAM compressed writeback is supported. Check the actual ZRAM features in [06](../06_zram_writeback/README.md).

**References:** [Debian Backports](https://backports.debian.org/Instructions/) · [Available Trixie Backports kernel](https://packages.debian.org/trixie-backports/linux-image-amd64).
