"""Focused verifier tests; not signed-artifact or device evidence."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from android_candidate_build import (elf_alignment, manifest_identity, signing_environment,
                                     SIGNING_BOOTSTRAP, PACKAGE, UPLOAD_SHA1, SETTINGS,
                                     POLICY_FIXED, COHORT_KEY, FLAGS, strict_json,
                                     assemble_candidate_defines, validate_candidate_defines,
                                     validate_internal_policy, validate_ci_evidence, build)


def policy_template():
    return {**POLICY_FIXED, COHORT_KEY: ""}


def assembled():
    return assemble_candidate_defines({name: "synthetic-setting" for name in SETTINGS},
                                     json.dumps(policy_template()), "a" * 64)


def policy_hash(defines):
    return hashlib.sha256(defines["CHRONOSPARK_REMOTE_CONFIG_JSON"].encode()).hexdigest()


class InternalPolicyTests(unittest.TestCase):
    def test_billing_profile_requires_explicit_selection_and_matching_private_cohort(self):
        defines = assemble_candidate_defines({name: "synthetic-setting" for name in SETTINGS},
            json.dumps(policy_template()), "a" * 64, billing_test=True)
        receipt = validate_candidate_defines(defines, policy_hash(defines), billing_test=True)
        self.assertTrue(receipt["billingRequiresVerifiedTestPurchase"])
        self.assertNotIn("a" * 64, json.dumps(receipt))
        self.assertEqual(defines["CHRONOSPARK_PAYWALL_DISABLED"], "false")
        with self.assertRaises(ValueError):
            validate_candidate_defines(defines, policy_hash(defines))
        defines["CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS"] = "b" * 64
        with self.assertRaises(ValueError):
            validate_candidate_defines(defines, policy_hash(defines), billing_test=True)

    def test_candidate_contains_enabled_local_policy_and_only_private_cohort_receipt(self):
        defines = assembled()
        receipt = validate_candidate_defines(defines, policy_hash(defines))
        self.assertEqual(receipt["cohortCount"], 1)
        self.assertEqual(receipt["enabledLocalCapabilities"],
                         ["smartPlannerV2", "siConsoleV2", "governedMemory", "safetyCritic"])
        self.assertNotIn("a" * 64, json.dumps(receipt))
        self.assertEqual(defines["CHRONOSPARK_BACKEND_MODE"], "cloud")
        self.assertEqual(defines["CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS"], "false")

    def test_missing_cohort_and_unreviewed_policy_fail_closed(self):
        for cohort in ("", "a" * 64 + ",", "a" * 64 + "," + "a" * 64, "raw-user-id",
                       hashlib.sha256(b"v2.signed_out").hexdigest(),
                       hashlib.sha256(b"v2.unsafe").hexdigest()):
            with self.subTest(cohort_length=len(cohort)), self.assertRaises(ValueError):
                assemble_candidate_defines({name: "fixture" for name in SETTINGS},
                                          json.dumps(policy_template()), cohort)
        defines = assembled()
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            validate_candidate_defines(defines, "b" * 64)

    def test_stage_types_and_capabilities_cannot_drift(self):
        mutations = [(key, None) for key in POLICY_FIXED] + [
            ("assistant_release_stage", stage) for stage in ("off", "general", "canary", "opted_in_beta")
        ] + [("assistant_release_canary_basis_points", False),
             ("assistant_release_canary_basis_points", 1),
             ("assistant_shadow_evaluation_enabled", True)] + [
             (key, not value) for key, value in POLICY_FIXED.items() if type(value) is bool]
        for key, value in mutations:
            policy = {**POLICY_FIXED, COHORT_KEY: "a" * 64, key: value}
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                validate_internal_policy(policy)
        for policy in ([], {}, {**POLICY_FIXED, COHORT_KEY: "a" * 64, "unreviewed": True}):
            with self.assertRaises(ValueError):
                validate_internal_policy(policy)

    def test_malformed_duplicate_and_unknown_json_are_rejected_without_echo(self):
        for raw in ('{"private":1,"private":2}', '[NaN]', '{raw-identity', 'null'):
            with self.assertRaises(ValueError) as error:
                assemble_candidate_defines({}, raw, "a" * 64)
            self.assertNotIn("raw-identity", str(error.exception))

    def test_final_assembled_file_rejects_extra_flags_and_containment_changes(self):
        previous_candidate = assembled()
        del previous_candidate["CHRONOSPARK_REMOTE_CONFIG_JSON"]
        with self.assertRaisesRegex(ValueError, "missing or unknown"):
            validate_candidate_defines(previous_candidate, "a" * 64)
        for key in FLAGS:
            defines = assembled()
            defines[key] = "changed"
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_candidate_defines(defines, policy_hash(defines))
        defines = assembled()
        defines["CHRONOSPARK_ENABLE_EXTERNAL_AI"] = "true"
        with self.assertRaises(ValueError):
            validate_candidate_defines(defines, policy_hash(defines))

    def test_exact_successful_ci_and_source_are_required(self):
        evidence = {"id": 42, "head_sha": "a" * 40, "repository": {"full_name": "owner/repo"},
                    "path": ".github/workflows/ci.yml", "event": "workflow_dispatch",
                    "status": "completed", "conclusion": "success"}
        self.assertEqual(validate_ci_evidence(evidence, "a" * 40, "42", "owner/repo")["conclusion"], "success")
        for key, value in (("id", 43), ("head_sha", "b" * 40), ("status", "in_progress"),
                           ("conclusion", "failure"), ("path", ".github/workflows/other.yml"),
                           ("event", "push"), ("repository", {"full_name": "other/repo"})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_ci_evidence({**evidence, key: value}, "a" * 40, "42", "owner/repo")
        for sha, run in (("", "42"), ("main", "42"), ("a" * 40, ""), ("a" * 40, "../1")):
            with self.assertRaises(ValueError):
                validate_ci_evidence(evidence, sha, run, "owner/repo")

    def test_same_final_defines_reach_dart_preflight_before_signing(self):
        import android_candidate_build as candidate
        source_sha = "a" * 40
        tooling_sha = "b" * 40
        ci = {"id": 42, "head_sha": source_sha,
              "repository": {"full_name": "ghostheart5/fantastic-guacamole"},
              "path": ".github/workflows/ci.yml", "event": "workflow_dispatch",
              "status": "completed", "conclusion": "success"}
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "app"
            (root / "android/app").mkdir(parents=True)
            (root / "tool").mkdir()
            (root / "lib/config").mkdir(parents=True)
            (root / "android/app/google-services.json").write_text("{}")
            (root / "pubspec.yaml").write_text("version: 4.1.0+2026083007\n")
            (root / candidate.POLICY_PATH).write_text(json.dumps(policy_template()))
            features = ("externalAiEnabled", "subscriptionsEnabled", "creditSpendingEnabled",
                        "cloudSyncEnabled", "cloudRestoreEnabled", "analyticsEnabled", "crashReportingEnabled")
            (root / "lib/config/launch_containment.dart").write_text(
                "\n".join(f"static const bool {feature} = false;" for feature in features))
            env = {"GITHUB_ACTIONS": "true", "GITHUB_SHA": tooling_sha, "CANDIDATE_SHA": source_sha,
                   "CANDIDATE_CI_RUN": "42", "GITHUB_REPOSITORY": "ghostheart5/fantastic-guacamole",
                   "CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS": "a" * 64, "RUNNER_TEMP": folder,
                   "CANDIDATE_POLICY_SHA256": policy_hash(assembled()),
                   "ANDROID_GOOGLE_SERVICES_JSON_BASE64": "e30=",
                   **{name: "synthetic-setting" for name in SETTINGS},
                   **{name: "synthetic-signing-value" for name in
                      ("ANDROID_KEYSTORE_BASE64", "ANDROID_STORE_PASSWORD", "ANDROID_KEY_PASSWORD", "ANDROID_KEY_ALIAS")}}
            observed = []
            def fake_command(args, cwd, capture=False, env=None):
                if args[:2] == ["gh", "api"]:
                    return json.dumps(ci)
                if args == ["git", "rev-parse", "HEAD"]:
                    return source_sha if cwd == root.resolve() else tooling_sha
                if args[0] == "dart":
                    path = Path(next(value[10:] for value in args if value.startswith("--defines=")))
                    observed.append(strict_json(path.read_text()))
                    self.assertFalse((root / "android/app/upload-keystore.jks").exists())
                    self.assertFalse((root / "android/key.properties").exists())
                    raise RuntimeError("preflight reached; no build")
                self.assertNotEqual(args[:3], ["flutter", "build", "appbundle"])
                return ""
            with patch.dict(os.environ, env, clear=True), patch.object(candidate, "command", side_effect=fake_command):
                with self.assertRaisesRegex(RuntimeError, "preflight reached"):
                    build(root, Path(folder) / "bundletool.jar")
            self.assertEqual(observed, [assembled()])
            self.assertFalse((Path(folder) / "chronospark-candidate-defines.json").exists())


def elf(load_alignment=16384, offset=0, address=0):
    data = bytearray(120)
    data[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<Q", data, 32, 64)
    struct.pack_into("<HH", data, 54, 56, 1)
    struct.pack_into("<IIQQQQQQ", data, 64, 1, 5, offset, address, 0, 0, 0, load_alignment)
    return data


def manifest(package=PACKAGE, code="2026083003", target="36", debug="false", test_only="false", billing=False):
    permission = '<uses-permission android:name="com.android.vending.BILLING"/>' if billing else ''
    return (f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
            f'package="{package}" android:versionName="4.1.0" android:versionCode="{code}">'
            f'<uses-sdk android:targetSdkVersion="{target}"/>'
            f'{permission}<application android:debuggable="{debug}" android:testOnly="{test_only}"/></manifest>')


class CandidateVerifierTests(unittest.TestCase):
    def test_signing_bootstrap_contains_only_fixed_nonsecret_values(self):
        self.assertEqual(SIGNING_BOOTSTRAP.splitlines()[1:], [
            "storePassword=environment-injected", "keyPassword=environment-injected",
            "keyAlias=environment-injected", "storeFile=app/upload-keystore.jks"])

    def test_signing_hook_is_scoped_and_cleaned_after_failure(self):
        tooling = Path(__file__).resolve().parent
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(RuntimeError, "controlled failure"):
                with signing_environment(tooling, folder) as env:
                    home = Path(env["GRADLE_USER_HOME"])
                    self.assertEqual((home / "init.d/candidate-signing.init.gradle").read_bytes(),
                                     (tooling / "candidate-signing.init.gradle").read_bytes())
                    self.assertIn("org.gradle.configuration-cache=false",
                                  (home / "gradle.properties").read_text())
                    self.assertIn("-Dorg.gradle.daemon=false", env["GRADLE_OPTS"])
                    raise RuntimeError("controlled failure")
            self.assertFalse(home.exists())

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
                        {"target": "35"}, {"debug": "true"}, {"test_only": "true"}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                manifest_identity(manifest(**options), ("4.1.0", "2026083003"))

    def test_internal_billing_manifest_requires_compiled_permission(self):
        self.assertEqual(manifest_identity(manifest(billing=True), ("4.1.0", "2026083003"), billing_test=True), 36)
        with self.assertRaisesRegex(ValueError, "Compiled billing permission"):
            manifest_identity(manifest(), ("4.1.0", "2026083003"), billing_test=True)

    def test_ordinary_candidate_rejects_unexpected_billing_permission(self):
        with self.assertRaisesRegex(ValueError, "Compiled billing permission"):
            manifest_identity(manifest(billing=True), ("4.1.0", "2026083003"))

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
