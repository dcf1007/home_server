#!/bin/sh
# Diagnostic only: reproduce the presence of OMV's Netplan dependency before
# Debian Installer's native 55netcfg-copy-config hook. Do not force a backend.
profile_netplan_test() {
    review_install 'Netplan diagnostic: netplan.io and dependencies' --no-install-recommends netplan.io
    log 'Netplan diagnostic package installed; native network configuration transfer remains unchanged'
}
