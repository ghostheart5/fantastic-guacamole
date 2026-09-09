import contextlib
import gzip
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location(
    "verify_additional_licenses", Path(__file__).with_name("verify_additional_licenses.py")
)
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class AdditionalLicenseVerificationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.notice = b"dependency (additional notices)\n\nCopyright Example\nFull permission and disclaimer.\n"
        (self.root / "notice.txt").write_bytes(self.notice)
        (self.root / "pubspec.yaml").write_text(
            "name: fixture\nflutter:\n  licenses:\n    - notice.txt\n  assets:\n    - unrelated.txt\n",
            encoding="utf-8",
        )
        self.flutter = self.root / "sdk" / "bin" / "flutter"
        self.flutter.parent.mkdir(parents=True)
        self.flutter.write_text("fixture", encoding="utf-8")
        self.revision = self.flutter.parent / "cache" / "dart-sdk" / "revision"
        self.revision.parent.mkdir(parents=True)
        self.revision.write_text(VERIFIER.EXPECTED_DART_REVISION, encoding="utf-8")

    def bundle(self, body, *, aab=True, duplicate=False):
        path = self.root / ("app.aab" if aab else "app.apk")
        entry = ("base/" if aab else "") + "assets/flutter_assets/NOTICES.Z"
        with zipfile.ZipFile(path, "w") as bundle:
            bundle.writestr(entry, gzip.compress(body))
            if duplicate:
                bundle.writestr("other/assets/flutter_assets/NOTICES.Z", gzip.compress(body))
        return path

    def verify(self, path):
        return VERIFIER.verify_artifact(path, self.root, str(self.flutter))

    def test_complete_declared_notice_passes_in_aab_and_apk(self):
        for aab in (True, False):
            with self.subTest(aab=aab):
                result = self.verify(self.bundle(b"Other license\n" + self.notice, aab=aab))
                self.assertTrue(result["success"])
                self.assertTrue(result["sdk"]["matches"])
                self.assertEqual(1, len(result["notices"]))

    def test_keywords_and_partial_disclaimer_do_not_satisfy_full_notice(self):
        result = self.verify(self.bundle(self.notice.replace(b"Full permission and disclaimer.\n", b"")))
        self.assertFalse(result["success"])
        self.assertFalse(result["notices"][0]["completeTextPresent"])

    def test_every_declared_notice_is_required(self):
        (self.root / "second.txt").write_text("second\n\nFull second license\n", encoding="utf-8")
        manifest = self.root / "pubspec.yaml"
        manifest.write_text(manifest.read_text().replace("    - notice.txt", "    - notice.txt\n    - second.txt"), encoding="utf-8")
        result = self.verify(self.bundle(self.notice))
        self.assertFalse(result["success"])
        self.assertEqual([True, False], [check["completeTextPresent"] for check in result["notices"]])

    def test_sdk_mismatch_fails_even_when_every_notice_is_present(self):
        self.revision.write_text("0" * 40, encoding="utf-8")
        result = self.verify(self.bundle(self.notice))
        self.assertFalse(result["success"])
        self.assertFalse(result["sdk"]["matches"])

    def test_missing_sdk_revision_fails(self):
        self.revision.unlink()
        with self.assertRaisesRegex(VERIFIER.VerificationError, "dart_sdk_revision_missing"):
            self.verify(self.bundle(self.notice))

    def test_duplicate_notice_archives_fail(self):
        with self.assertRaisesRegex(VERIFIER.VerificationError, "missing_or_ambiguous"):
            self.verify(self.bundle(self.notice, duplicate=True))

    def test_notice_in_an_unloadable_module_location_cannot_pass(self):
        artifact = self.root / "app.aab"
        with zipfile.ZipFile(artifact, "w") as bundle:
            bundle.writestr("other/assets/flutter_assets/NOTICES.Z", gzip.compress(self.notice))
        with self.assertRaisesRegex(VERIFIER.VerificationError, "missing_or_ambiguous"):
            self.verify(artifact)

    def test_corrupt_compressed_notices_fail_with_sanitized_json(self):
        artifact = self.root / "app.aab"
        with zipfile.ZipFile(artifact, "w") as bundle:
            bundle.writestr("base/assets/flutter_assets/NOTICES.Z", b"private invalid compression")
        with contextlib.redirect_stdout(io.StringIO()) as output:
            code = VERIFIER.main(["--artifact", str(artifact), "--repo-root", str(self.root),
                                  "--flutter-executable", str(self.flutter)])
        self.assertEqual(1, code)
        self.assertNotIn("private", output.getvalue())
        self.assertEqual("artifact_or_input_unreadable", json.loads(output.getvalue())["errorCode"])

    def test_missing_declared_file_and_unsupported_declaration_fail(self):
        (self.root / "notice.txt").unlink()
        with self.assertRaisesRegex(VERIFIER.VerificationError, "declared_license_missing"):
            self.verify(self.bundle(self.notice))
        (self.root / "pubspec.yaml").write_text("flutter:\n  licenses: [notice.txt]\n", encoding="utf-8")
        with self.assertRaisesRegex(VERIFIER.VerificationError, "unsupported_license_declaration"):
            self.verify(self.bundle(self.notice))

    def test_parent_traversal_cannot_supply_a_notice(self):
        (self.root / "pubspec.yaml").write_text("flutter:\n  licenses:\n    - ../notice.txt\n", encoding="utf-8")
        with self.assertRaisesRegex(VERIFIER.VerificationError, "unsafe_or_duplicate"):
            self.verify(self.bundle(self.notice))

    def test_cli_writes_json_and_nonzero_for_missing_notice(self):
        artifact = self.bundle(b"primary license only")
        report = self.root / "report.json"
        with contextlib.redirect_stdout(io.StringIO()) as output:
            code = VERIFIER.main(["--artifact", str(artifact), "--repo-root", str(self.root),
                                  "--flutter-executable", str(self.flutter), "--report", str(report)])
        self.assertEqual(1, code)
        self.assertEqual(json.loads(output.getvalue()), json.loads(report.read_text(encoding="utf-8")))
        self.assertFalse(json.loads(output.getvalue())["success"])

    def test_cli_does_not_emit_invalid_revision_contents_or_tracebacks(self):
        self.revision.write_text("private malformed diagnostic", encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()) as output:
            code = VERIFIER.main(["--artifact", str(self.bundle(self.notice)), "--repo-root", str(self.root),
                                  "--flutter-executable", str(self.flutter)])
        self.assertEqual(1, code)
        self.assertNotIn("private", output.getvalue())
        self.assertEqual("dart_sdk_revision_invalid", json.loads(output.getvalue())["errorCode"])


if __name__ == "__main__":
    unittest.main()
