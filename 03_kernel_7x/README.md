# 03 — Eligible Linux 7.x kernel and matching headers (optional)

The project's [ZRAM writeback configuration](../05_zram_writeback/README.md) specifically requires an eligible **7.x** kernel and matching headers. Do not hardcode a point release or assume the current APT metapackages always point to 7.x.

## Inspect the candidates

~~~sh
sudo apt-get update
apt-cache policy linux-image-amd64 linux-headers-amd64
apt-cache show linux-image-amd64 | grep -E '^(Version|Depends):'
apt-cache show linux-headers-amd64 | grep -E '^(Version|Depends):'
~~~

Confirm the selected **pair** resolves to `linux-image-7.*` and `linux-headers-7.*` for the same ABI. Check actual versions, repository origin, dependencies and possible removals. Do **not** silently install 6.x or 8.x as a substitute.

If the normal Debian candidates both resolve to 7.x:

~~~sh
sudo apt-get -s install linux-image-amd64 linux-headers-amd64
# After checking the plan and keeping your working fallback:
sudo apt-get install linux-image-amd64 linux-headers-amd64
~~~

If [Backports](../02_backports/README.md) was **already enabled**, first inspect whether its moving metapackages resolve to a compatible 7.x pair:

~~~sh
sudo apt-get -s install linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports
# ONLY IF both really resolve to matching 7.x packages:
sudo apt-get install linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports
~~~

If neither source has an eligible pair, stop and decide whether another signed repository is acceptable. Do not enable Backports automatically or remove the Stable fallback.

## Finish and verify

~~~sh
sudo update-initramfs -u -k all
sudo update-grub
sudo dpkg --audit
ls /boot/vmlinuz-7.* /usr/src/linux-headers-7.* 2>/dev/null
~~~

After reboot:

~~~sh
uname -r
test -d "/usr/src/linux-headers-$(uname -r)" && echo 'Matching headers present'
~~~

The running kernel should be **7.x**; the exact headers ABI must match it. ZRAM compressed writeback still requires separate **kernel sysfs feature validation**, not just the version number.

References: [Debian Backports](https://backports.debian.org/Instructions/) · [Debian kernel metapackage](https://packages.debian.org/trixie-backports/linux-image-amd64).
