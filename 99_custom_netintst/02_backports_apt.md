# Netinst — What the selected Backports profile actually does

**Goal:** add signed Trixie Backports to the new Debian system, review eligible upgrades and optional cleanup, while preserving normal APT priority **100**.

For a system that already boots Debian, use the simpler [02 — Backports how-to](../02_backports/README.md). The following steps happen **inside Debian Installer** when you selected Backports.

## Step 1 — Add the source to the installed target

The installer copies its staged [`debian-backports.sources`](my-cdd/scripts/debian-backports.sources) into the target's `/etc/apt/sources.list.d/`. It contains:

- `Suites: trixie-backports`, with Debian components including `non-free-firmware`;
- Debian's archive signing key, not an unsigned third-party source.

It rejects the project's old priority-override file if one unexpectedly exists. The selected profile must never silently raise Backports to priority 900.

## Step 2 — Refresh package indexes and verify priorities

It runs target `apt-get update` through Debian Installer's progress frontend and checks target `apt-cache policy`. The **Backports lines must have effective priority 100**. Any unexpected priority is an error, not something the installer silently fixes.

**What you should check:** the proposed Backports versions appear as available alternatives; ordinary Stable/Security packages are not globally replaced.

## Step 3 — Review the upgrade before APT changes packages

The target runs an **APT dry-run full/dist-upgrade**. Debian Installer shows the **complete proposed package actions** and asks for a separate default-No approval.

Check the package names, versions, repository origins, dependencies and **all removals**. If it proposes removing a kernel, GRUB, SSH, sudo, systemd or another critical package, the profile rejects it. An approved upgrade is executed through target `apt-get`, followed by a package-configuration audit and a second simulation to confirm that eligible work did not remain.

## Step 4 — Consider safe cleanup individually

The installer next simulates `autoremove --purge`. If APT proposes removals, it shows the full plan, then asks **separately for every package** whether that exact removal is approved. A refusal stops this cleanup instead of deleting an unapproved package.

It also checks for packages left only with residual configuration (`dpkg` status `rc`). If present, it displays those exact names and requests review before purging their leftover configuration.

Finally it checks package consistency and repeats the cleanup simulation; outstanding unapproved changes are an error.

## Step 5 — What is left after the profile

Only when these stages complete does it record the Backports profile as successful. The newly installed system should have the signed source configured at priority **100**, without a blanket pin. Your decision to select this does **not** automatically select the Linux 7.x or firmware profiles.

**Why the installer needs special handling:** Debian Installer runs outside `/target`; it must route package operations into the target and show approvals through its own Debconf interface. An ordinary installed system can use interactive APT directly.

**Validation:** the end-to-end GTK/text approval, target APT transaction and exact priorities must be checked in a VM; see [08 — Validation](08_validation_and_pending.md).
