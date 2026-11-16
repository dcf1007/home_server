# 04 — Add extra firmware and CPU microcode (optional)

**What this does:** installs additional firmware for network, storage, graphics and other devices, along with the approved **Intel and AMD microcode** packages. This is intentionally broader than simply supporting hardware that is currently attached.

Debian already detects and installs some required firmware during normal installation. **This chapter is optional.** It applies to Debian 13 amd64 and requires the `non-free-firmware` component in your Debian APT sources.

## Step 1 — Refresh APT and read the package inventory

~~~sh
sudo apt update
~~~

Open the [full firmware inventory](firmware-candidates.txt). It is organized below into small groups so you can review what is being installed.

APT itself asks for any package-specific license acceptance, including the complete license prompts for `firmware-ipw2x00` and `firmware-ivtv`. You do **not** need the custom installer's Debconf workarounds.

## Step 2 — Install the CPU microcode packages

~~~sh
sudo apt install intel-microcode amd64-microcode
~~~

The project deliberately attempts **both** packages. The CPU will only load the microcode appropriate to its manufacturer. Read APT's summary before confirming.

## Step 3 — Install general Linux firmware

~~~sh
sudo apt install firmware-linux firmware-linux-nonfree firmware-misc-nonfree firmware-intel-misc
~~~

Some packages are metapackages that depend on other firmware packages; this is normal.

## Step 4 — Install network and storage firmware

~~~sh
sudo apt install firmware-realtek firmware-bnx2 firmware-bnx2x firmware-cavium
~~~

~~~sh
sudo apt install firmware-marvell-prestera firmware-myricom firmware-netronome
~~~

~~~sh
sudo apt install firmware-netxen firmware-qlogic
~~~

## Step 5 — Install wireless firmware

~~~sh
sudo apt install firmware-atheros firmware-brcm80211 firmware-iwlwifi
~~~

~~~sh
sudo apt install firmware-ipw2x00 firmware-libertas firmware-mediatek
~~~

~~~sh
sudo apt install firmware-ti-connectivity firmware-ath9k-htc firmware-carl9170 firmware-zd1211
~~~

**Read the full license** if APT asks about `firmware-ipw2x00`. Declining it may prevent that package from installing.

## Step 6 — Install graphics and media firmware

~~~sh
sudo apt install firmware-amd-graphics firmware-intel-graphics firmware-nvidia-graphics
~~~

~~~sh
sudo apt install firmware-ast firmware-qcom-soc firmware-samsung firmware-siano firmware-ivtv
~~~

Read the full license if `firmware-ivtv` asks for permission.

## Step 7 — Install sound, Bluetooth and peripheral firmware

~~~sh
sudo apt install firmware-cirrus firmware-intel-sound firmware-sof-signed bluez-firmware
~~~

### If APT reports a missing or conflicting package

Stop that group and read the error. Do not blindly force the installation. You can check an individual name:

~~~sh
apt policy firmware-realtek
~~~

Substitute the **actual problematic package name**. Decide whether to retry just that package, use a compatible Backports version (if [Backports](../02_backports/README.md) was explicitly enabled), or **deliberately omit** that one package. Record every omission and its reason; do not silently skip requested firmware.

With Backports enabled, APT still normally prefers Stable. To choose a compatible Backports package deliberately, the command looks like:

~~~sh
sudo apt install firmware-realtek/trixie-backports
~~~

This is an **example**, not a requirement to replace the Stable version. Review dependencies and conflicts. Don't raise the global Backports priority.

## Step 8 — Finish and verify

~~~sh
sudo update-initramfs -u -k all
~~~

~~~sh
sudo dpkg --audit
~~~

Reboot when convenient, then inspect kernel messages for any remaining firmware loading errors:

~~~sh
sudo journalctl -k -b
~~~

**Done when:** your approved packages are installed (or any omissions were explicitly reviewed), APT reports no unfinished packages and the devices you need work. Package installation alone cannot guarantee every device is supported.

**Reference:** [Debian firmware information](https://wiki.debian.org/Firmware).
