# 09 — Temporary Netplan diagnostic profile

## Netplan diagnostic profile — 2026-11-20

**Nearest user prompt:** “add a profile that installs netplan in my-cdd just to check. then in the first boot i will run the install.sh and see if it fails.”

The optional, unchecked `netplan-test` profile installs `--no-install-recommends netplan.io` through the existing APT review and approval at stage 11, before native `55netcfg-copy-config`. Netplan's mandatory `netplan-generator` dependency is the variable under test. This profile adds no network-backend override, DNS or routing edits, OMV/Docker package selection, vendor patch, or first-boot hook. Native stage 14 verifies its completion marker; the existing stage 15 guard checks all selected markers. No ISO or runtime test is claimed.

Build from the diagnostic branch. Select `netplan-test` while leaving OMV and Docker unchecked. Keep other profile selections, VM network settings and DHCP/static choices identical to the successful control. Do not force `netcfg/target_network_config` or apply Netplan manually, since native Debian Installer network handoff is the behavior under test.

After boot, before running the official OMV script, collect:

```sh
dpkg-query -W netplan.io netplan-generator
sudo ls -l /etc/netplan/
sudo cat /etc/netplan/*.yaml
cat /etc/network/interfaces
ip route
getent hosts packages.openmediavault.io
```

Then run the [official OMV shell installer](https://github.com/openmediavault/openmediavault/blob/master/install.sh) unmodified; record its exit status, output and OMV package version. Recurrence of the `dnsservers` assertion supports the hypothesis that native Netplan handoff triggers the OMV import bug. If it succeeds, compare network configuration and OMV versions; success alone does not disprove the importer defect.

## Exact sources

<details>
<summary><strong>Complete file: installer/netplan-test.sh</strong> (7 lines, current Git blob <code>7ff1f906a722ac50f8d0702ea9a437c3fa4be4ec</code>)</summary>

````sh
#!/bin/sh
# Diagnostic only: reproduce the presence of OMV's Netplan dependency before
# Debian Installer's native 55netcfg-copy-config hook. Do not force a backend.
profile_netplan_test() {
    review_install 'Netplan diagnostic: netplan.io and dependencies' --no-install-recommends netplan.io
    log 'Netplan diagnostic package installed; native network configuration transfer remains unchanged'
}
````

</details>

<details>
<summary><strong>Complete file: profiles/netplan-test.description</strong> (1 lines, current Git blob <code>a9911d41f05bbe282c49f02f3aee9fc273e2ec42</code>)</summary>

````text
Netplan (diagnostic test; install netplan.io before native network configuration transfer)
````

</details>

<details>
<summary><strong>Complete file: profiles/netplan-test.extra</strong> (2 lines, current Git blob <code>f99eb1ff7f98baf40a25ff6bb9ff35ce33ae5fd3</code>)</summary>

````text
# netplan-test: diagnostic installer source asset only.
installer/netplan-test.sh
````

</details>

<details>
<summary><strong>Complete file: profiles/netplan-test.postinst</strong> (11 lines, current Git blob <code>88b44500aec794f81f8b5df2fe1c4c68ccb5a1be</code>)</summary>

````sh
#!/bin/sh
# Simple-CDD finish-install verification only.
# The selected profile was performed beforehand by the native Debian
# Installer stage-11 runner, where its Debconf approvals were visible.
# Never execute the profile twice or claim success from mere selection.
set -eu
marker="/var/log/installer/my-cdd-completed/netplan-test"
if [ ! -f "$marker" ]; then
    printf >&2 'my-cdd: %s was selected but not successfully applied; refusing completion.\n' 'netplan-test'
    exit 1
fi
````

</details>

Set `profiles/netplan-test.postinst` executable (0755), like the other native verifiers. Do not execute installer handlers on the build host.
