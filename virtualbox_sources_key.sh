#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    printf 'Run this script as root (for example: sudo sh %s).\n' "$0" >&2
    exit 1
fi

for cmd in gpg awk install mktemp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$cmd" >&2
        exit 1
    fi
done

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' 0
trap 'exit 1' 1 2 3 15
mkdir -m 700 "$tmpdir/gnupg"
GNUPGHOME="$tmpdir/gnupg"
export GNUPGHOME

url=https://www.virtualbox.org/download/oracle_vbox_2016.asc

if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --tlsv1.2 -o "$tmpdir/key.asc" "$url"
elif command -v wget >/dev/null 2>&1; then
    wget -q --https-only -O "$tmpdir/key.asc" "$url"
else
    printf 'curl or wget is required.\n' >&2
    exit 1
fi

fingerprint=$(gpg --batch --with-colons --with-fingerprint --show-keys "$tmpdir/key.asc" 2>/dev/null |
    awk -F: '$1 == "fpr" { print $10; exit }')
expected=B9F8D658297AF3EFC18D5CDFA2F683C52980AECF

if [ "$fingerprint" != "$expected" ]; then
    printf 'VirtualBox signing-key fingerprint mismatch; key not installed.\n' >&2
    exit 1
fi

gpg --batch --yes --dearmor --output "$tmpdir/key.gpg" "$tmpdir/key.asc"
install -m 0644 "$tmpdir/key.gpg" /usr/share/keyrings/oracle-virtualbox-2016.gpg
printf 'VirtualBox signing key installed.\n'
