"""Offline unit tests for scripts/plan-firmware.py; never contact real APT."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "plan-firmware.py"
spec = importlib.util.spec_from_file_location("plan_firmware", SCRIPT)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
import sys
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def policy(name: str, candidate: str, stable_suite="trixie", include_backports=False):
    stable = (
        f"     {candidate} 500\n"
        f"        500 https://deb.debian.org/debian {stable_suite}/non-free-firmware amd64 Packages\n"
    )
    bpo = (
        "     9999~bpo13+1 100\n"
        "        100 https://deb.debian.org/debian trixie-backports/non-free-firmware amd64 Packages\n"
        if include_backports else ""
    )
    return (
        f"{name}:\n"
        f"  Installed: (none)\n"
        f"  Candidate: {candidate}\n"
        f"  Version table:\n{bpo}{stable}"
    )


def mocked_runner(policies, *, simulation_returncode=0):
    commands = []

    def runner(argv):
        commands.append(argv)
        if argv[:2] == ["apt-cache", "policy"]:
            name = argv[2]
            return subprocess.CompletedProcess(argv, 0, policies[name], "")
        if argv[:3] == ["apt-get", "-s", "install"]:
            return subprocess.CompletedProcess(
                argv, simulation_returncode,
                "Inst test-package (test) ...\n" if simulation_returncode == 0 else "",
                "Unresolvable dependencies\n" if simulation_returncode else ""
            )
        raise AssertionError(f"Unexpected command: {argv}")

    return runner, commands


class FirmwarePlannerTests(unittest.TestCase):
    def test_backports_first_and_one_combined_simulation(self):
        names = ["intel-microcode", "amd64-microcode", "firmware-realtek"]
        data = {n: policy(n, "1.0", include_backports=True) for n in names}
        runner, commands = mocked_runner(data)
        plan, blockers = mod.plan(names, True, runner)
        self.assertEqual([], blockers)
        self.assertEqual([f"{n}/trixie-backports" for n in names],
                         [selector for _, selector, _ in plan])
        with tempfile.TemporaryDirectory() as temp:
            inv = Path(temp) / "firmware.txt"
            inv.write_text("\n".join(names) + "\n", encoding="utf-8")
            self.assertEqual(0, mod.main(["--inventory", str(inv), "--with-backports"], runner))
        simulations = [cmd for cmd in commands if cmd[:3] == ["apt-get", "-s", "install"]]
        self.assertEqual(1, len(simulations))
        self.assertEqual([f"{n}/trixie-backports" for n in names], simulations[0][3:])
        self.assertFalse(any("apt-get" in cmd and "-s" not in cmd for cmd in commands))

    def test_explicit_stable_suite_when_backports_unavailable(self):
        names = ["intel-microcode", "amd64-microcode"]
        data = {
            "intel-microcode": policy("intel-microcode", "1.5", "trixie-security"),
            "amd64-microcode": policy("amd64-microcode", "1.4", "trixie-updates"),
        }
        runner, _ = mocked_runner(data)
        plan, blockers = mod.plan(names, True, runner)
        self.assertFalse(blockers)
        self.assertEqual(["intel-microcode/trixie-security", "amd64-microcode/trixie-updates"],
                         [s for _, s, _ in plan])
        self.assertTrue(all("Stable fallback" in reason for _, _, reason in plan))

    def test_normal_repositories_only_when_backports_not_selected(self):
        names = ["intel-microcode", "amd64-microcode"]
        data = {n: policy(n, "1.2", include_backports=True) for n in names}
        runner, _ = mocked_runner(data)
        plan, blockers = mod.plan(names, False, runner)
        self.assertFalse(blockers)
        self.assertEqual([f"{n}/trixie" for n in names],
                         [s for _, s, _ in plan])

    def test_unknown_origin_candidate_blocks_instead_of_guessing(self):
        data = {"intel-microcode": policy("intel-microcode", "1.0").replace(
            "Candidate: 1.0", "Candidate: 99.0")}
        runner, _ = mocked_runner(data)
        selected, blockers = mod.plan(["intel-microcode"], False, runner)
        self.assertFalse(selected)
        self.assertIn("not an eligible normal Debian version", blockers[0])

    def test_missing_repo_candidate_never_silently_omitted(self):
        data = {"amd64-microcode": (
            "amd64-microcode:\n  Installed: (none)\n  Candidate: (none)\n  Version table:\n"
        )}
        runner, _ = mocked_runner(data)
        selected, blockers = mod.plan(["amd64-microcode"], True, runner)
        self.assertFalse(selected)
        self.assertIn("requires individual omission approval", blockers[0])

    def test_dependency_failure_stops_without_installing(self):
        names = ["intel-microcode", "amd64-microcode"]
        runner, commands = mocked_runner(
            {n: policy(n, "1.0") for n in names}, simulation_returncode=100)
        with tempfile.TemporaryDirectory() as temp:
            inv = Path(temp) / "firmware.txt"
            inv.write_text("\n".join(names), encoding="utf-8")
            self.assertEqual(2, mod.main(["--inventory", str(inv)], runner))
        self.assertEqual(1, sum(cmd[:3] == ["apt-get", "-s", "install"] for cmd in commands))
        self.assertFalse(any(cmd[0] in ("dpkg", "apt") for cmd in commands))

    def test_inventory_requires_both_microcodes_and_no_duplicates(self):
        with tempfile.TemporaryDirectory() as temp:
            inv = Path(temp) / "firmware.txt"
            inv.write_text("intel-microcode\nfirmware-realtek\n")
            with self.assertRaises(mod.PlanningError):
                mod.inventory(inv)
            inv.write_text("intel-microcode\namd64-microcode\namd64-microcode\n")
            with self.assertRaises(mod.PlanningError):
                mod.inventory(inv)

    def test_policy_parses_approved_suite_origins_not_dpkg_status(self):
        text = (
            "a:\n  Installed: 1.0\n  Candidate: 1.0\n  Version table:\n"
            " *** 1.0 100\n        100 /var/lib/dpkg/status\n"
            "     0.9 500\n        500 https://deb.debian.org/debian trixie/main amd64 Packages\n"
        )
        versions = mod.package_versions(text)
        self.assertEqual(2, len(versions))
        self.assertEqual(frozenset(), versions[0].suites)
        self.assertEqual(frozenset(("trixie",)), versions[1].suites)


if __name__ == "__main__":
    unittest.main()
