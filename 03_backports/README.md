# 03 — Enable Debian Backports (optional)

**What this does:** makes newer Debian packages available without replacing the normal Stable package policy. It is useful for the optional [Linux 7.x kernel](../04_kernel_7x/README.md) and newer firmware.

**Before starting:** Debian 13 is installed, you have Internet access, and you can use `sudo`. Skip this chapter if you do not need Backports.

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="72" height="72" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

**When OMV is installed:** OMV's APT deployment enables kernel Backports by default in the inspected OMV 8 source, writes its own source and preferences, and pins `linux-base`, `linux-image-*`, `linux-headers-*` and `firmware-*` to priority 500 by default. This is not a global priority-900 pin; the ordinary Debian priority of 100 does not describe all packages on such a system. OMV also warns against arbitrary Backports software. Compare `apt policy` and the actual entries under `/etc/apt/sources.list.d/` and `/etc/apt/preferences.d/` before adding a duplicate source or approving a transaction. See [Chapter 07 — OMV configuration ownership and checks](../07_openmediavault/README.md#omv-8-configuration-ownership-and-post-install-checks).

</td>
</tr>
</table>

## Step 1 — Add the Backports source

This file tells Debian where Backports packages come from and which Debian signing key to trust. Editing it alone installs nothing.

Open `/etc/apt/sources.list.d/debian-backports.sources` in a text editor with administrator privileges; review the existing content, make the described change and save the file.

Paste these lines **into the file**, not into the terminal:

~~~text
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
~~~

Save the file after reviewing the content.

## Step 2 — Refresh packages and check the source

This refreshes repository information after adding the Backports file. Check for a successful `trixie-backports` download and **no signature errors**. It does not install any package.

~~~sh
sudo apt update
~~~

APT should recognize `trixie-backports` without signature errors. If it does not, stop and correct the source file.

This displays APT’s repository and priority table. Find the `trixie-backports` entry and verify its normal **priority 100**, compared with the usual **500** for Stable packages.

~~~sh
apt policy
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="72" height="72" alt="Important note"></td>
<td valign="top" width="100%">

Look for `trixie-backports`. Its usual package priority is **100**; normal Stable packages normally have priority **500**. Do not add a custom priority-900 preference.

</td>
</tr>
</table>

## Step 3 — Review normal package upgrades

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="72" height="72" alt="Important note"></td>
<td valign="top" width="100%">

This starts a regular full-upgrade using the currently configured APT priorities. It can install new dependencies **and remove packages**; inspect the summary and answer **No** if it would remove a needed kernel, SSH or other essential service.

</td>
</tr>
</table>

~~~sh
sudo apt full-upgrade
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="72" height="72" alt="Important note"></td>
<td valign="top" width="100%">

APT will show what it plans to install, upgrade or remove. **Read that summary before answering Yes.** If it proposes losing a working kernel, SSH or other essential software, answer **No** and investigate.

</td>
</tr>
</table>

This command is a normal upgrade under Debian's existing priority rules. It does **not** install every package from Backports.

## Step 4 — Review optional cleanup

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="72" height="72" alt="Important note"></td>
<td valign="top" width="100%">

This asks APT which automatically installed packages are no longer required and proposes removing them, including leftover configuration (`--purge`). Review the **complete list** before accepting; cancelling is safe and cleanup is optional.

</td>
</tr>
</table>

~~~sh
sudo apt autoremove --purge
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="72" height="72" alt="Important note"></td>
<td valign="top" width="100%">

Read the entire removal list before approving anything. In particular, keep the old bootable Stable kernel until the new one has been tested. If uncertain, answer **No**; cleanup is optional.

</td>
</tr>
</table>

## Step 5 — Install a particular Backports package only when needed

For example, to see which kernel versions are available:

This shows the available kernel metapackage versions and their repository origins. The purpose is to see whether you need a *specific* Backports kernel, not to install anything.

~~~sh
apt policy linux-image-amd64
~~~

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/warning.svg" width="72" height="72" alt="Important note"></td>
<td valign="top" width="100%">

If you deliberately want a particular package from Backports, select that package for the transaction rather than changing the priority of *all* packages. For the complete Linux 7.x image-and-headers procedure, follow [04](../04_kernel_7x/README.md).

</td>
</tr>
</table>

Check package health when finished:

This checks whether Debian has partially installed or otherwise unconfigured packages. **No output normally means no problems**; if it lists packages, resolve them before starting another optional guide.

~~~sh
sudo dpkg --audit
~~~

**Done when (ordinary Debian):** Backports appears in APT at priority 100, normal APT updates work and there are no unresolved package problems.

<table width="100%">
<tr>
<td valign="top" align="center" width="72" nowrap><img src="../assets/omv.svg" width="72" height="72" alt="OpenMediaVault-specific note"></td>
<td valign="top" width="100%">

On OMV, inspect its package-specific priorities separately as explained above.

</td>
</tr>
</table>

**Reference:** [Official Debian Backports instructions](https://backports.debian.org/Instructions/).
