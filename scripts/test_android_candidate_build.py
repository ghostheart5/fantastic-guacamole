"""Focused verifier tests; not signed-artifact or device evidence."""
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
import zipfile

from android_candidate_build import elf_alignment, manifest_identity, properties_escape, PACKAGE, UPLOAD_SHA1


def elf(load_alignment=16384, offset=0, address=0):
    data = bytearray(120)
    data[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<Q", data, 32, 64)
    struct.pack_into("<HH", data, 54, 56, 1)
    struct.pack_into("<IIQQQQQQ", data, 64, 1, 5, offset, address, 0, 0, 0, load_alignment)
    return data


def manifest(package=PACKAGE, code="2026083003", target="36", debug="false"):
    return (f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
            f'package="{package}" android:versionName="4.1.0" android:versionCode="{code}">'
            f'<uses-sdk android:targetSdkVersion="{target}"/>'
            f'<application android:debuggable="{debug}"/></manifest>')


class CandidateVerifierTests(unittest.TestCase):
    def test_properties_escaping(self):
        self.assertEqual(properties_escape(" a:b=c\\d#!é"), r"\ a\:b\=c\\d\#\!\u00e9")

    def test_16k_elf(self):
        self.assertEqual(elf_alignment(elf()), 16384)

    def test_4k_elf_rejected(self):
        with self.assertRaises(ValueError):
            elf_alignment(elf(4096))

    def test_offset_mismatch_rejected(self):
        with self.assertRaises(ValueError):
            elf_alignment(elf(offset=1))

    def test_non_power_of_two_rejected(self):
        with self.assertRaises(ValueError):
            elf_alignment(elf(20000))

    def test_non_elf_rejected(self):
        with self.assertRaises(ValueError):
            elf_alignment(b"not an ELF")

    def test_manifest(self):
        self.assertEqual(manifest_identity(manifest(), ("4.1.0", "2026083003")), 36)

    def test_bad_manifest_identity_rejected(self):
        for options in ({"package": "other.app"}, {"code": "1"},
                        {"target": "35"}, {"debug": "true"}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                manifest_identity(manifest(**options), ("4.1.0", "2026083003"))

    def test_java_verifier_rejects_unsigned_payload_without_creating_a_key(self):
        self.assertIsNotNone(shutil.which("java"), "Java required; do not skip signature rejection")
        source = Path(__file__).with_name("VerifyCandidateSignature.java")
        with tempfile.TemporaryDirectory(prefix="chronospark-signature-negative-") as folder:
            archive = Path(folder) / "unsigned.jar"
            with zipfile.ZipFile(archive, "w") as jar:
                jar.writestr("base/payload.txt", "negative verification fixture")
            result = subprocess.run(["java", str(source), str(archive), UPLOAD_SHA1],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unsigned or multiply-signed payload", result.stderr)


if __name__ == "__main__":
    unittest.main()
