# 02 — Debian Trixie Backports (optional)

Applies to an installed Debian 13 system with network access. **Skip this entirely** if you do not need Backports.

## Add the signed source

~~~sh
sudo tee /etc/apt/sources.list.d/debian-backports.sources >/dev/null <<'EOF'
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
sudo apt-get update
apt-cache policy
~~~

The standard Backports Release metadata yields APT priority **100**. Ordinary Stable/Security packages usually have priority **500**. Do not add a global priority-900 pin or silently set `APT::Default-Release` to Backports.

## Review the regular upgrade and cleanup

~~~sh
sudo apt-get -s full-upgrade
~~~

Check the complete plan, including new dependencies and removals. If approved, run `sudo apt-get full-upgrade`, which normally asks for confirmation.

~~~sh
sudo apt-get -s autoremove --purge
~~~

Only after individually assessing all proposed removals should you run `sudo apt-get autoremove --purge`. Retain a working Stable kernel/GRUB fallback until a new kernel has been boot-tested. Inspect any `dpkg -l` residual `rc` entries before purging them.

## Selective Backports installs

Backports priority 100 does not automatically replace Stable packages. When necessary, inspect and request the *specific* package:

~~~sh
apt-cache policy linux-image-amd64 linux-headers-amd64
sudo apt-get -s install linux-image-amd64/trixie-backports
~~~

The complete 7.x image+header transaction is in [03](../03_kernel_7x/README.md); firmware follows [04](../04_extended_device_support/README.md). Prefer `package/trixie-backports` instead of blanket `-t trixie-backports` selection.

Verify with `sudo dpkg --audit`, `apt-cache policy`, `apt-mark showhold` and a fresh dry-run `full-upgrade`.

Reference: [Debian Backports instructions](https://backports.debian.org/Instructions/).
