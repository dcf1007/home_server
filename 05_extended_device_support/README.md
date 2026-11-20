# 05 — Add extra firmware and CPU microcode (optional)

**What this does:** installs additional firmware for network, storage, graphics and other devices, along with the approved **Intel and AMD microcode** packages. This is intentionally broader than simply supporting hardware that is currently attached.

Debian already detects and installs some required firmware during normal installation. **This chapter is optional.** It applies to Debian 13 amd64 and requires the `non-free-firmware` component in your Debian APT sources.

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/omv.svg" width="100%" alt="OpenMediaVault-specific note">
</td>
<td valign="top">

**When OMV is installed:** OMV's own kernel Backports preferences also match `firmware-*` by default, so even ordinary APT commands may select Backports firmware. Its default preference does not match the names `intel-microcode` or `amd64-microcode`. Review the actual candidate and origin for each requested package; the existing inventory and individual omission decisions remain unchanged. See [Chapter 07 — OMV configuration ownership and checks](../07_openmediavault/README.md#omv-8-configuration-ownership-and-post-install-checks).

</td>
</tr>
</table>

## Step 1 — Refresh APT and read the package inventory

This updates APT’s available package information before evaluating firmware. It does **not** install firmware or change drivers; stop if the configured Debian sources cannot be refreshed.

~~~sh
sudo apt update
~~~

Open the [full firmware inventory](firmware-candidates.txt). It is organized below into small groups so you can review what is being installed.

APT itself asks for any package-specific license acceptance, including the complete license prompts for `firmware-ipw2x00` and `firmware-ivtv`. You do **not** need the custom installer's Debconf workarounds.

## Step 2 — Install the CPU microcode packages

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

This requests both Intel and AMD **CPU microcode** packages, as specified by the project. Microcode is low-level CPU firmware; APT shows the complete proposed changes and may report compatibility issues. Read the summary before confirming, and do not silently omit either package.

</td>
</tr>
</table>

~~~sh
sudo apt install intel-microcode amd64-microcode
~~~

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

The project deliberately attempts **both** packages. The CPU will only load the microcode appropriate to its manufacturer. Read APT's summary before confirming.

</td>
</tr>
</table>

## Step 3 — Install general Linux firmware

This requests the broad Linux and Intel miscellaneous firmware packages. The `firmware-linux` packages include metapackages that can pull in additional binaries; read APT’s dependency list and approve only the intended changes.

~~~sh
sudo apt install firmware-linux firmware-linux-nonfree firmware-misc-nonfree firmware-intel-misc
~~~

Some packages are metapackages that depend on other firmware packages; this is normal.

## Step 4 — Install network and storage firmware

This requests firmware covering Realtek, Broadcom and Cavium network/storage devices. These are device-support files, not network configuration changes; review any proposed removals before approving.

~~~sh
sudo apt install firmware-realtek firmware-bnx2 firmware-bnx2x firmware-cavium
~~~

This requests firmware for Marvell, Myricom and Netronome network/storage hardware. You may not have those devices today; the goal is the project’s approved **proactive support**. Check the APT proposal.

~~~sh
sudo apt install firmware-marvell-prestera firmware-myricom firmware-netronome
~~~

This adds NetXen and QLogic device firmware. As with the preceding groups, check APT’s proposed package list and report any unavailable package instead of proceeding blindly.

~~~sh
sudo apt install firmware-netxen firmware-qlogic
~~~

## Step 5 — Install wireless firmware

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

This requests Atheros, Broadcom wireless and Intel Wi-Fi firmware. If APT reports a dependency conflict or missing package, **stop this group** and decide how to handle that package.

</td>
</tr>
</table>

~~~sh
sudo apt install firmware-atheros firmware-brcm80211 firmware-iwlwifi
~~~

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

This requests older Intel wireless, Libertas and MediaTek firmware. `firmware-ipw2x00` may display a **license agreement**; read it and explicitly accept or decline before continuing.

</td>
</tr>
</table>

~~~sh
sudo apt install firmware-ipw2x00 firmware-libertas firmware-mediatek
~~~

This requests TI, Atheros USB, carl9170 and ZyDAS wireless firmware. Review what APT offers; these packages are for additional wireless chipsets, not Wi-Fi network setup.

~~~sh
sudo apt install firmware-ti-connectivity firmware-ath9k-htc firmware-carl9170 firmware-zd1211
~~~

**Read the full license** if APT asks about `firmware-ipw2x00`. Declining it may prevent that package from installing.

## Step 6 — Install graphics and media firmware

This requests AMD, Intel and NVIDIA graphics firmware. It provides firmware blobs for supported hardware; it does **not** install full proprietary GPU drivers unless APT explicitly proposes such packages—review the plan.

~~~sh
sudo apt install firmware-amd-graphics firmware-intel-graphics firmware-nvidia-graphics
~~~

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

This requests ASPEED, Qualcomm, Samsung, Siano and IVTV graphics/media firmware. `firmware-ivtv` may prompt for an additional vendor license; read and decide explicitly.

</td>
</tr>
</table>

~~~sh
sudo apt install firmware-ast firmware-qcom-soc firmware-samsung firmware-siano firmware-ivtv
~~~

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

Read the full license if `firmware-ivtv` asks for permission.

</td>
</tr>
</table>

## Step 7 — Install sound, Bluetooth and peripheral firmware

This requests firmware for audio controllers, Intel sound, SOF DSP and Bluetooth devices. Check whether the transaction is compatible with the packages already installed.

~~~sh
sudo apt install firmware-cirrus firmware-intel-sound firmware-sof-signed bluez-firmware
~~~

### If APT reports a missing or conflicting package

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

Stop that group and read the error. Do not blindly force the installation. You can check an individual name:

</td>
</tr>
</table>

This **inspects one package** and its available versions without installing it. Replace `firmware-realtek` with the specific package causing the error, then check whether it is missing, pinned or available in another enabled repository.

~~~sh
apt policy firmware-realtek
~~~

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

Substitute the **actual problematic package name**. Decide whether to retry just that package, use a compatible Backports version (if [Backports](../03_backports/README.md) was explicitly enabled), or **deliberately omit** that one package. Record every omission and its reason; do not silently skip requested firmware.

</td>
</tr>
</table>

With Backports enabled, APT still normally prefers Stable. To choose a compatible Backports package deliberately, the command looks like:

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

This is an **example only** of requesting one package specifically from Trixie Backports. Use the *real* problematic package name only if Backports was intentionally enabled and the candidate is compatible; review APT’s changes before approving.

</td>
</tr>
</table>

~~~sh
sudo apt install firmware-realtek/trixie-backports
~~~

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

This is an **example**, not a requirement to replace the Stable version. Review dependencies and conflicts. Don't raise the global Backports priority.

</td>
</tr>
</table>

## Step 8 — Finish and verify

<table width="100%">
<tr>
<td valign="top" width="100" align="center" nowrap=""><img src="../assets/warning.svg" width="100%" alt="Important note">
</td>
<td valign="top">

This regenerates early-boot images so the installed firmware can be available to the kernel during startup. Read any warnings; if the operation fails, resolve it before rebooting.

</td>
</tr>
</table>

~~~sh
sudo update-initramfs -u -k all
~~~

This checks for incomplete Debian package installations/configurations. **No output means no issues found**; listed packages require attention before proceeding.

~~~sh
sudo dpkg --audit
~~~

Reboot when convenient, then inspect kernel messages for any remaining firmware loading errors:

This shows kernel messages from the **current boot**. Read for firmware-loading and microcode-related warnings or errors; the command may print many unrelated messages and does not alter anything.

~~~sh
sudo journalctl -k -b
~~~

**Done when:** your approved packages are installed (or any omissions were explicitly reviewed), APT reports no unfinished packages and the devices you need work. Package installation alone cannot guarantee every device is supported.

**Reference:** [Debian firmware information](https://wiki.debian.org/Firmware).
