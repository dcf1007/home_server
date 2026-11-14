#!/usr/bin/env python3
"""Read-only firmware/microcode APT planning for the approved my-cdd policy.

This is a development/integration component, NOT an installer transaction
executor. It never installs, downgrades, changes repositories or grants consent.
It fails closed on unknown package origins, missing candidates and simulation
errors; the installer must arrange separate per-package omission approvals and
one final joint transaction approval.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

PACKAGE_RE = re.compile(r"^[a-z0-9][a-z0-9+.-]*$")
VERSION_RE = re.compile(r"^\s*(?:\*\*\*\s+)?(\S+)\s+(-?\d+)\s*$")
SOURCE_RE = re.compile(r"\b(trixie-backports|trixie-security|trixie-updates|trixie)/(?:main|contrib|non-free|non-free-firmware)\b")
REQUIRED_MICROCODE = frozenset(("intel-microcode", "amd64-microcode"))


@dataclass(frozen=True)
class AvailableVersion:
    version: str
    suites: frozenset[str]


class PlanningError(Exception):
    """A condition that requires user review, not automatic recovery."""


def inventory(path: Path) -> list[str]:
    if not path.is_file():
        raise PlanningError(f"Inventory does not exist: {path}")
    names: list[str] = []
    seen: set[str] = set()
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        if not PACKAGE_RE.fullmatch(line):
            raise PlanningError(f"{path}:{lineno}: invalid binary package name {line!r}")
        if line in seen:
            raise PlanningError(f"{path}:{lineno}: duplicate package name {line!r}")
        names.append(line)
        seen.add(line)
    if not REQUIRED_MICROCODE.issubset(seen):
        raise PlanningError("Inventory must request BOTH intel-microcode and amd64-microcode")
    return names


def package_versions(policy: str) -> list[AvailableVersion]:
    """Extract version-to-enabled-release mapping from apt-cache policy text.

    Installed-only status entries do NOT count as repository candidates.
    Release origins are recognized only from the approved trixie suite names.
    """
    versions: list[AvailableVersion] = []
    in_table = False
    current: str | None = None
    suites: set[str] = set()

    def flush() -> None:
        nonlocal current, suites
        if current is not None:
            versions.append(AvailableVersion(current, frozenset(suites)))
        current = None
        suites = set()

    for line in policy.splitlines():
        if "Version table:" in line:
            in_table = True
            continue
        if not in_table:
            continue
        match = VERSION_RE.match(line)
        if match:
            flush()
            current = match.group(1)
            continue
        if current is not None:
            match = SOURCE_RE.search(line)
            if match:
                suites.add(match.group(1))
    flush()
    return versions


def run(argv: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(argv, text=True, capture_output=True, check=False)


def plan(names: list[str], with_backports: bool, runner=run) -> tuple[list[tuple[str, str, str]], list[str]]:
    """Return (name, APT selector, explanation) and hard blockers.

    This performs NO fallback for dependency conflicts: one combined APT
    simulation must diagnose them before an explicitly reviewed new plan.
    """
    selected: list[tuple[str, str, str]] = []
    blockers: list[str] = []
    for name in names:
        proc = runner(["apt-cache", "policy", name])
        if proc.returncode:
            blockers.append(f"{name}: apt-cache policy failed ({proc.returncode}); {proc.stderr.strip()}")
            continue
        versions = package_versions(proc.stdout)
        bpo = [v for v in versions if "trixie-backports" in v.suites]
        stable = [
            v for v in versions
            if v.suites.intersection(("trixie", "trixie-updates", "trixie-security"))
        ]
        if with_backports and bpo:
            selected.append((name, f"{name}/trixie-backports", "Backports-first; version must be verified by simulation"))
        elif stable:
            # Don't request an exact version here: ordinary APT release
            # priorities determine the preferred stable candidate.
            # The final installed version and origin MUST be reviewed.
            reason = ("Stable fallback: no published, enabled Backports candidate"
                      if with_backports else "Normal Debian repositories; Backports not selected")
            selected.append((name, name, reason))
        else:
            why = ("no eligible Backports or Stable/Updates/Security candidate"
                   if with_backports else "no eligible Stable/Updates/Security candidate")
            blockers.append(f"{name}: {why}; requires individual omission approval or manual resolution")
    return selected, blockers


def main(argv: list[str] | None = None, runner=run) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--inventory",
        type=Path,
        default=Path(__file__).resolve().with_name("firmware-candidates.txt"),
        help="full approved broad firmware inventory including both microcodes",
    )
    parser.add_argument(
        "--with-backports",
        action="store_true",
        help="ONLY when the user explicitly selected/completed Backports",
    )
    options = parser.parse_args(argv)
    try:
        names = inventory(options.inventory)
        selected, blockers = plan(names, options.with_backports, runner=runner)
    except (PlanningError, OSError) as exc:
        print(f"STOP: {exc}", file=sys.stderr)
        return 2

    print(f"Requested packages: {len(names)} (includes both microcode packages)")
    print(f"Backports profile selected: {options.with_backports}")
    print("Proposed APT selectors and preliminary explanations (NOT APPROVED):")
    for name, selector, why in selected:
        print(f"  {name:28s} {selector:43s} {why}")

    if blockers:
        print("STOP: no packages were automatically omitted. Every blocker requires review:", file=sys.stderr)
        for message in blockers:
            print(f"  {message}", file=sys.stderr)
        return 2

    selectors = [selector for _name, selector, _why in selected]
    print("JOINT SIMULATION: apt-get -s install " + " ".join(selectors))
    proc = runner(["apt-get", "-s", "install", *selectors])
    # Do not discard apt's complete output; use it in the eventual full logs
    # and explicit final transaction review, including suggested removals.
    if proc.stdout:
        print(proc.stdout, end="" if proc.stdout.endswith("\n") else "\n")
    if proc.stderr:
        print(proc.stderr, end="" if proc.stderr.endswith("\n") else "\n", file=sys.stderr)
    if proc.returncode:
        print("STOP: combined simulation failed. No automatic Stable substitution, omission, or install.",
              file=sys.stderr)
        return 2

    print("SIMULATION ONLY. Do NOT install until the actual selected versions/origins,")
    print("Stable fallbacks, removals and full transaction have been explicitly reviewed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
