"""Adversarial provenance/terminal checks; no devices, SDK installs or builds."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import warnings
import zipfile

import android_final_validation as gate


class FinalValidationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = "a" * 40
        self.build_tooling = "b" * 40
        self.repo = "ghostheart5/fantastic-guacamole"
        self.run_id = "123"
        self.run = {"id": 123, "repository": {"full_name": self.repo},
                    "head_repository": {"full_name": self.repo},
                    "head_branch": "fix/app-only-readiness-priority2-20260902",
                    "path": ".github/workflows/android-candidate-build.yml",
                    "event": "workflow_dispatch", "status": "completed", "conclusion": "success",
                    "head_sha": self.build_tooling, "run_attempt": 2}
        self.aab = b"Fixture bytes; real bundle validity belongs to the separate signed-artifact runner."
        self.aab_sha = hashlib.sha256(self.aab).hexdigest()
        self.candidate = {"sourceSha": self.source, "toolingSha": self.build_tooling,
                          "buildRunId": self.run_id, "runAttempt": "2", "package": gate.PACKAGE,
                          "versionName": "4.1.0", "versionCode": 2026083022,
                          "aabSha256": self.aab_sha, "uploadSignerSha256": "C" * 64}
        self.licenses = {"success": True, "artifactSha256": self.aab_sha}
        self.artifact = {"id": 456, "name": f"chronospark-candidate-{self.source}-123-2", "expired": False,
                         "workflow_run": {"id": 123, "head_sha": self.build_tooling}}
        self.zip_path = self.root / "candidate.zip"

    def archive(self, *, duplicate=False):
        with zipfile.ZipFile(self.zip_path, "w") as archive:
            archive.writestr("candidate.json", json.dumps(self.candidate))
            archive.writestr("additional-license-verification.json", json.dumps(self.licenses))
            archive.writestr("app-release.aab", self.aab)
            if duplicate:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    archive.writestr("candidate.json", json.dumps(self.candidate))
        self.artifact.update(size_in_bytes=self.zip_path.stat().st_size,
                             digest="sha256:" + gate.digest(self.zip_path))

    def verify(self):
        return gate.verify_candidate(self.zip_path, self.run, self.artifact,
                                     self.source, self.run_id, self.repo)

    def test_completed_candidate_uses_build_tooling_identity_not_validation_head(self):
        self.archive()
        result = self.verify()
        self.assertEqual(result["candidateToolingSha"], self.build_tooling)
        self.assertEqual(result["sourceSha"], self.source)
        self.assertEqual(result["aabSha256"], self.aab_sha)

    def test_wrong_source_run_attempt_and_tooling_are_rejected(self):
        for key, value in (("sourceSha", "d" * 40), ("buildRunId", "124"),
                           ("runAttempt", "1"), ("toolingSha", "e" * 40),
                           ("package", "wrong.package")):
            with self.subTest(key=key):
                original = self.candidate[key]
                self.candidate[key] = value
                self.archive()
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.candidate[key] = original

    def test_other_workflow_fork_unfinished_and_unsuccessful_runs_are_rejected(self):
        self.archive()
        for key, value in (("path", ".github/workflows/ci.yml"), ("event", "pull_request"),
                           ("head_branch", "unreviewed-branch"),
                           ("status", "in_progress"), ("conclusion", "failure"),
                           ("head_repository", {"full_name": "other/repo"})):
            with self.subTest(key=key):
                original = self.run[key]
                self.run[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.run[key] = original

    def test_expired_wrong_attempt_missing_digest_and_other_run_artifacts_fail(self):
        self.archive()
        for key, value in (("expired", True), ("name", self.artifact["name"][:-1] + "1"),
                           ("digest", ""), ("workflow_run", {"id": 124, "head_sha": self.build_tooling})):
            with self.subTest(key=key):
                original = self.artifact[key]
                self.artifact[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.artifact[key] = original

    def test_tampered_download_fails_before_trusting_manifest(self):
        self.archive()
        with self.zip_path.open("ab") as stream:
            stream.write(b"unexpected bytes")
        with self.assertRaisesRegex(RuntimeError, "ZIP digest mismatch"):
            self.verify()

    def test_actual_aab_hash_is_required_even_when_api_zip_digest_matches(self):
        self.aab = b"A different artifact payload"
        self.archive()
        with self.assertRaisesRegex(RuntimeError, "AAB SHA256 mismatch"):
            self.verify()

    def test_missing_or_mismatched_license_success_is_rejected(self):
        for value in ({}, {"success": False, "artifactSha256": self.aab_sha},
                      {"success": True, "artifactSha256": "f" * 64}):
            with self.subTest(value=value):
                self.licenses = value
                self.archive()
                with self.assertRaisesRegex(RuntimeError, "license"):
                    self.verify()

    def test_duplicate_artifact_entries_are_rejected(self):
        self.archive(duplicate=True)
        with self.assertRaisesRegex(RuntimeError, "Duplicate"):
            self.verify()

    def test_source_and_run_inputs_must_be_immutable_and_numeric(self):
        for source, run in (("main", self.run_id), (self.source, "123/attempts"), ("A" * 40, self.run_id)):
            with self.subTest(source=source, run=run), self.assertRaises(RuntimeError):
                gate.validate_run(self.run, source, run, self.repo)

    def terminal(self):
        return {"finalSuccess": True, "exitCode": 0, "terminalCompletion": True,
                "terminalSuccess": True, "timedOut": False, "launchFailed": False,
                "totals": {"total": 6, "passed": 6, "failed": 0, "error": 0, "skipped": 0},
                "completedTests": 6, "reportParseErrors": []}

    def test_terminal_contract_accepts_complete_execution(self):
        path = self.root / "manifest.json"
        gate.write_json(path, self.terminal())
        self.assertEqual(gate.verify_terminal(path)["passed"], 6)

    def test_terminal_zero_skips_errors_partial_completion_and_original_exit_fail(self):
        variants = []
        for key, value in (("exitCode", 1), ("timedOut", True), ("completedTests", 5),
                           ("terminalCompletion", False), ("reportParseErrors", ["bad JSON"])):
            changed = self.terminal()
            changed[key] = value
            variants.append(changed)
        for key, value in (("total", 0), ("skipped", 1), ("failed", 1), ("error", 1)):
            changed = self.terminal()
            changed["totals"][key] = value
            variants.append(changed)
        for index, receipt in enumerate(variants):
            with self.subTest(index=index):
                path = self.root / "manifest.json"
                gate.write_json(path, receipt)
                with self.assertRaises(RuntimeError):
                    gate.verify_terminal(path)

    def test_runtime_error_scan_catches_native_flutter_and_app_anr_failures(self):
        failures = ["FATAL EXCEPTION: main", "Fatal signal 11 (SIGSEGV)",
                    "E/flutter: Unhandled Exception: StateError", "MissingPluginException(No impl)",
                    "ANR in " + gate.PACKAGE, "Process " + gate.PACKAGE + " has died"]
        self.assertEqual(gate.fatal_lines("\n".join(failures)), failures)
        self.assertEqual(gate.fatal_lines("ActivityTaskManager: Displayed " + gate.PACKAGE), [])

    def test_owned_avd_preserves_image_but_requires_muted_small_software_gpu(self):
        path = self.root / "config.ini"
        path.write_text("image.sysdir.1=system-images/android-37.1/google_apis_ps16k/x86_64/\nhw.audioInput=yes\n")
        result = gate.configure_avd(path)
        self.assertEqual(result["image.sysdir.1"], "system-images/android-37.1/google_apis_ps16k/x86_64/")
        self.assertEqual(result["hw.audioInput"], "no")
        self.assertEqual(result["hw.audioOutput"], "no")
        self.assertEqual(result["hw.ramSize"], "2048")
        self.assertEqual(result["hw.cpu.ncore"], "2")
        self.assertEqual(result["hw.gpu.mode"], "swiftshader")

    def test_rendered_welcome_requires_brand_and_visible_enabled_real_action(self):
        path = self.root / "window.xml"
        template = '<hierarchy><node content-desc="CHRONOSPARK"/><node content-desc="CONTINUE TO LOGIN" enabled="{enabled}" clickable="true" bounds="{bounds}"/></hierarchy>'
        path.write_text(template.format(enabled="true", bounds="[30,500][290,560]"))
        gate.verify_rendered_onboarding(path)
        for enabled, bounds in (("false", "[30,500][290,560]"), ("true", "[30,620][290,690]")):
            path.write_text(template.format(enabled=enabled, bounds=bounds))
            with self.assertRaises(RuntimeError):
                gate.verify_rendered_onboarding(path)
        path.write_text('<hierarchy><node content-desc="Splash screen"/></hierarchy>')
        with self.assertRaises(RuntimeError):
            gate.verify_rendered_onboarding(path)


if __name__ == "__main__":
    unittest.main()
