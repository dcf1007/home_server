# 06 — Optional Debian system tweaks

This chapter contains **only changes beyond Debian's normal settings**. It is independent of Backports, Linux 7.x, firmware, ZRAM, OMV and Docker. Review each change on the installed system; don't apply it automatically to every Debian installation.

## Boot messages and manual filesystem repairs

Edit `/etc/default/grub` with `sudoedit /etc/default/grub`: in the existing `GRUB_CMDLINE_LINUX_DEFAULT` value, **remove `quiet`**, preserve other boot arguments, and add **`fsck.repair=no`** if absent. Avoid enabling extra debug output.

~~~sh
sudo update-grub
cat /proc/cmdline
~~~

The `cat /proc/cmdline` result reflects the **currently booted** command line and must be checked after a reboot.

## Ext4 root mount options

Inspect the actual root filesystem and options:

~~~sh
findmnt -no SOURCE,FSTYPE,OPTIONS /
grep -v '^#' /etc/fstab
~~~

**Only if root is ext4**, edit its existing `/` entry in `/etc/fstab` with `sudoedit /etc/fstab`. Add `noatime,errors=panic` to the *existing* comma-separated mount options without removing unrelated options, and remove conflicting `atime`/`relatime` or previous `errors=...` values. Do not alter other mounts. Keep a backup before editing (`sudo cp -a /etc/fstab /etc/fstab.before-tweaks`). Reboot and verify `findmnt -no OPTIONS /`.

The intent is **manual-only repairs**: `fsck.repair=no` prevents automatic filesystem repair. This is operational policy, not a universally recommended default.

## Deny root SSH, if SSH is installed

Keep an existing non-root SSH/sudo recovery account working before tightening the policy.

~~~sh
if command -v sshd >/dev/null 2>&1 || test -x /usr/sbin/sshd; then
    sudo install -d /etc/ssh/sshd_config.d
    printf 'PermitRootLogin no\n' |
        sudo tee /etc/ssh/sshd_config.d/01-home-server-root.conf >/dev/null
    sudo /usr/sbin/sshd -t
    sudo /usr/sbin/sshd -T | grep -i '^permitrootlogin '
    sudo systemctl reload ssh
fi
~~~

Require the effective value `permitrootlogin no`; if a later `Match` or other config changes it, investigate before claiming enforcement.

## Manual-only APT updates

Check the effective schedule first; do not create redundant settings when automatic upgrades are already off:

~~~sh
apt-config dump | grep -E 'APT::Periodic|Unattended' || true
systemctl list-timers --all | grep -E 'apt-daily|unattended' || true
~~~

If unattended upgrades or periodic package-list updates are active, turn them off through a dedicated override:

~~~sh
sudo tee /etc/apt/apt.conf.d/99-home-server-manual-updates >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
~~~

This does not block deliberately executed `apt-get update` or package upgrades. Verify `apt-config dump` again. Do not impose an unattended reboot policy.

**Validation:** after reboot, check the effective GRUB arguments, ext4 root mount, `sshd -T`, APT settings and that the system still offers a working recovery login.
