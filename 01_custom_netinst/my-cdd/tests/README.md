# Offline tests

Run from `my-cdd/`:

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
sh installer/test-ordered-selection.sh
sh scripts/verify-source-layout.sh
```

The firmware planner tests use injected fake APT results; they do **not**
contact a repository, alter the package database, install packages or
create/edit a disk partition. A passing test says nothing about the real
Debian Trixie package transaction, selected Linux 7.x kernel, installer
GTK integration or first boot.

No automatic approvals are produced by tests. Source configuration remains
nonfunctional until the installer and transaction execution gates are met.
