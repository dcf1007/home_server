#!/usr/bin/env python3
"""Disable OMV 8 automatic upgrades and APT update notifications.

Adapted from the project's original installer/profile-omv.sh for use on
a normal installed OMV 8 system. Run as root. OMV configuration models
should be inspected before modifying any unexpected future schema.
"""
import json
import subprocess


def read(model):
    return json.loads(subprocess.run(
        ["omv-confdbadm", "read", model],
        check=True, capture_output=True, text=True,
    ).stdout)


def update(model, data):
    subprocess.run(
        ["omv-confdbadm", "update", model, json.dumps(data)],
        check=True, capture_output=True, text=True,
    )


settings = read("conf.system.apt.updates")
if not isinstance(settings, dict) or not isinstance(settings.get("unattendedupgrade"), bool):
    raise RuntimeError("Unexpected OMV 8 unattended update schema")
settings["unattendedupgrade"] = False
update("conf.system.apt.updates", settings)

notifications = read("conf.system.notification.notification")
if not isinstance(notifications, list):
    raise RuntimeError("Unexpected OMV 8 notification schema")
apt_entries = [
    n for n in notifications
    if isinstance(n, dict) and n.get("id") == "apt"
]
if len(apt_entries) != 1:
    raise RuntimeError("Missing or ambiguous OMV APT notification")
apt_entries[0]["enable"] = False
update("conf.system.notification.notification", apt_entries)

if read("conf.system.apt.updates").get("unattendedupgrade") is not False:
    raise RuntimeError("OMV automatic upgrades remain enabled")
remaining = read("conf.system.notification.notification")
if len([n for n in remaining if n.get("id") == "apt" and n.get("enable") is False]) != 1:
    raise RuntimeError("OMV APT notification remains enabled")
print("OMV automatic upgrades and APT notification disabled; deploy apt and apticron states.")
