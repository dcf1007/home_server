#!/bin/sh
# Run via partman/early_command before native partitioning.
# Rename only the three existing native hooks in the installer ramdisk.
set -eu
cd /usr/lib/finish-install.d
# Check all original scripts before changing any filename.
for hook in 14simple-cdd 15cdrom-detect 20final-message; do
    if [ ! -f "$hook" ]; then
        printf >&2 'my-cdd: missing native finish-install hook: %s\n' "$hook"
        exit 1
    fi
done
mv 14simple-cdd 62simple-cdd
mv 15cdrom-detect 64cdrom-detect
mv 20final-message 65final-message
