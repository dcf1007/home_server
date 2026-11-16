# 04 — Extended device firmware and CPU microcode (optional)

An optional proactive inventory for Debian 13 amd64. Enable the regular Debian `non-free-firmware` component first. The approved list includes **both Intel and AMD microcode**, plus the full additional firmware inventory in [firmware-candidates.txt](firmware-candidates.txt). Do not silently filter by CPU vendor or drop a package because hardware is not currently attached.

## The ordinary Debian method

On a full Debian system, **APT itself** can install the packages and show their original Debconf license prompts. There is no need to extract licenses into the Debian Installer frontend.

From this chapter directory, using **Bash**:

~~~bash
sudo apt-get update
cat firmware-candidates.txt
mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' firmware-candidates.txt)
sudo apt-get -s install "${packages[@]}"
~~~

Read the full proposed transaction before running it. Availability, package conflicts, metapackages and both microcode packages must be considered. If any package is unavailable or conflicts, document its specific reason and **explicitly decide** whether to omit that package; edit your *working copy* of the list and re-run the simulation. Do not silently skip it.

For an approved package set:

~~~bash
sudo apt-get install "${packages[@]}"
sudo update-initramfs -u -k all
sudo dpkg --audit
~~~

Do **not** add `-y` or force `DEBIAN_FRONTEND=noninteractive`: `firmware-ipw2x00` and `firmware-ivtv` may require accepting their complete vendor license. Refusing the license means revising the package set with explicit consent.

If [Backports](../02_backports/README.md) is enabled, inspect `apt-cache policy <package>` and prefer a compatible Backports candidate through a targeted `package/trixie-backports` selector. Otherwise use the eligible normal Debian candidate. Always re-simulate the *combined* selected package set; do not increase global Backports priority.

## Check the result

~~~sh
dpkg-query -W intel-microcode amd64-microcode
sudo dpkg --audit
journalctl -k -b | grep -Ei 'firmware|microcode' || true
~~~

Installation does not prove support for every device; check the relevant hardware logs and drivers after reboot.

References: [Debian Firmware](https://wiki.debian.org/Firmware) · [Debian Backports](https://backports.debian.org/Instructions/).
