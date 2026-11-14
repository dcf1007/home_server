#!/bin/sh
# Read-only package-origin and APT transaction inspection for approved packages.
# This tool does not install packages or grant approval.
set -eu
if [ "$#" -lt 1 ]; then
  printf >&2 'Usage: sh apt-simulate.sh PACKAGE[/SUITE] ...\n'
  exit 2
fi
for pkg do
  case "$pkg" in
    *[!a-zA-Z0-9.+~_:/-]*|'') printf >&2 'Unsafe package token: %s\n' "$pkg"; exit 2 ;;
  esac
  plain="${pkg%%/*}"
  printf '\n===== APT policy for %s =====\n' "$plain"
  apt-cache policy "$plain"
done
printf '\n===== APT simulated install (NOT an approval) =====\n'
apt-get -s install "$@"
