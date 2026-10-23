"""No Gradle, Flutter, signing, network or production access is used here."""
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import run_hosted_release_build as hosted


class HostedReleaseMemoryTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        self.addCleanup(self.folder.cleanup)

    def probe(self, available=None):
        return {"effectiveCapacityBytes": 16 * hosted.GIB,
                "effectiveAvailableBytes": available or 12 * hosted.GIB}

    def fixture(self, unified=True):
        proc = self.root / "proc"
        (proc / "self").mkdir(parents=True)
        (proc / "meminfo").write_text("MemTotal: 16777216 kB\nMemAvailable: 12582912 kB\n")
        mount = self.root / "cgroup"
        (mount / "parent/child").mkdir(parents=True)
        (proc / "self/cgroup").write_text("0::/parent/child\n" if unified else "3:memory:/parent/child\n")
        fs = "cgroup2 cgroup rw" if unified else "cgroup cgroup rw,memory"
        (proc / "self/mountinfo").write_text(f"1 0 0:1 / {mount.as_posix()} rw - {fs}\n")
        return proc, mount

    def test_finite_parent_limit_and_usage_bound_available_memory(self):
        proc, mount = self.fixture()
        (mount / "memory.max").write_text("max")
        parent = mount / "parent"
        (parent / "memory.max").write_text(str(8 * hosted.GIB))
        (parent / "memory.current").write_text(str(2 * hosted.GIB))
        child = parent / "child"
        (child / "memory.max").write_text("max")
        budget = hosted.memory_budget(proc)
        self.assertEqual(budget["effectiveCapacityBytes"], 8 * hosted.GIB)
        self.assertEqual(budget["effectiveAvailableBytes"], 6 * hosted.GIB)

    def test_v1_sentinel_and_finite_child_limit(self):
        proc, mount = self.fixture(False)
        (mount / "memory.limit_in_bytes").write_text(str((1 << 63) - 4096))
        child = mount / "parent/child"
        (child / "memory.limit_in_bytes").write_text(str(10 * hosted.GIB))
        (child / "memory.usage_in_bytes").write_text(str(hosted.GIB))
        budget = hosted.memory_budget(proc)
        self.assertEqual(budget["effectiveAvailableBytes"], 9 * hosted.GIB)

    def test_missing_cgroup_usage_and_host_available_fail_closed(self):
        proc, mount = self.fixture()
        (mount / "memory.max").write_text(str(8 * hosted.GIB))
        with self.assertRaises(FileNotFoundError):
            hosted.memory_budget(proc)
        (proc / "meminfo").write_text("MemTotal: 16777216 kB\n")
        with self.assertRaises(RuntimeError):
            hosted.memory_budget(proc)

    def test_budget_rejection_does_not_launch_or_create_gradle_home(self):
        receipt = self.root / "receipt.json"
        def unexpected(*args, **kwargs):
            self.fail("An insufficient runner must not start a build")
        code = hosted.run_build(["unused"], receipt, self.root,
                                probe=lambda: self.probe(hosted.REQUIRED_BYTES - 1), execute=unexpected)
        self.assertEqual(code, 1)
        data = json.loads(receipt.read_text())
        self.assertEqual(data["status"], "INSUFFICIENT_MEMORY")
        self.assertTrue(data["disposableGradleHomeRemoved"])
        self.assertEqual(list(self.root.glob("axiomara-public-gradle-*")), [])

    def check_isolation(self, returncode=None, launch_error=False):
        existing = self.root / "existing-gradle"
        existing.mkdir()
        (existing / "gradle.properties").write_text("sentinel unchanged")
        receipt = self.root / "receipt.json"
        seen = []
        def child(command, *, env, check):
            home = Path(env["GRADLE_USER_HOME"])
            seen.append(home)
            self.assertNotEqual(home, existing)
            self.assertEqual((home / "gradle.properties").read_text(), hosted.PROPERTIES)
            self.assertFalse((home / "init.d").exists())
            self.assertEqual(os.environ["GRADLE_USER_HOME"], str(existing))
            self.assertFalse(check)
            (home / "cache").write_text("owned transient cache")
            if launch_error:
                raise OSError("synthetic launch failure with private context")
            return SimpleNamespace(returncode=returncode)
        with patch.dict(os.environ, {"GRADLE_USER_HOME": str(existing),
                        "JAVA_TOOL_OPTIONS": "", "_JAVA_OPTIONS": "", "JDK_JAVA_OPTIONS": "",
                        "GRADLE_OPTS": "", "PRIVATE_SENTINEL": "do-not-serialize"}):
            code = hosted.run_build(["synthetic build"], receipt, self.root,
                                    probe=self.probe, execute=child)
        self.assertEqual(code, 1 if launch_error else returncode)
        self.assertTrue(seen)
        self.assertFalse(seen[0].exists())
        self.assertEqual((existing / "gradle.properties").read_text(), "sentinel unchanged")
        data = json.loads(receipt.read_text())
        self.assertTrue(data["disposableGradleHomeRemoved"])
        self.assertNotIn("do-not-serialize", receipt.read_text())
        self.assertNotIn("private context", receipt.read_text())

    def test_success_removes_only_disposable_home(self):
        self.check_isolation(0)

    def test_build_failure_exit_code_and_cleanup_are_preserved(self):
        self.check_isolation(17)

    def test_launch_exception_still_cleans_home_without_private_details(self):
        self.check_isolation(launch_error=True)

    def test_global_java_overrides_are_rejected_before_launch(self):
        with patch.dict(os.environ, {"JAVA_TOOL_OPTIONS": "-Xmx12g"}):
            code = hosted.run_build(["unused"], self.root / "receipt.json", self.root,
                                    probe=self.probe, execute=lambda *a, **k: self.fail("Must not launch"))
        self.assertEqual(code, 1)
        self.assertEqual(list(self.root.glob("axiomara-public-gradle-*")), [])

    def test_existing_receipt_refuses_before_launch_and_is_preserved(self):
        receipt = self.root / "receipt.json"
        receipt.write_text("original receipt")
        with self.assertRaises(FileExistsError):
            hosted.run_build(["unused"], receipt, self.root, probe=self.probe,
                             execute=lambda *a, **k: self.fail("Must not launch"))
        self.assertEqual(receipt.read_text(), "original receipt")

    def test_cleanup_failure_cannot_report_success(self):
        home = self.root / "simulated-owned-home"
        class CleanupFailure:
            def __enter__(self):
                home.mkdir()
                return str(home)
            def __exit__(self, *args):
                raise OSError("synthetic cleanup failure")
        receipt = self.root / "receipt.json"
        with patch.object(hosted.tempfile, "TemporaryDirectory", return_value=CleanupFailure()):
            with patch.dict(os.environ, {"JAVA_TOOL_OPTIONS": "", "_JAVA_OPTIONS": "",
                            "JDK_JAVA_OPTIONS": "", "GRADLE_OPTS": ""}):
                code = hosted.run_build(["unused"], receipt, self.root, probe=self.probe,
                                        execute=lambda *a, **k: SimpleNamespace(returncode=0))
        self.assertEqual(code, 1)
        data = json.loads(receipt.read_text())
        self.assertEqual(data["status"], "WRAPPER_FAILED")
        self.assertFalse(data["disposableGradleHomeRemoved"])


if __name__ == "__main__":
    unittest.main()
