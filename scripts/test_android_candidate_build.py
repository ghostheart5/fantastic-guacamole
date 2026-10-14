"""Focused verifier tests; not signed-artifact or device evidence."""
from pathlib import Path
import contextlib
import hashlib
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import android_candidate_build as candidate
from candidate_build_diagnostics import (FailureDiagnostics, MAX_INPUT_LINE_BYTES,
    MAX_OUTPUT_BYTES, MAX_OUTPUT_LINES, run_flutter_release)

from android_candidate_build import (elf_alignment, manifest_identity, signing_environment,
                                     SIGNING_BOOTSTRAP, PACKAGE, UPLOAD_SHA1, SETTINGS,
                                     POLICY_FIXED, COHORT_KEY, FLAGS, strict_json,
                                     assemble_candidate_defines, validate_candidate_defines,
                                     validate_internal_policy, validate_ci_evidence,
                                     merge_assistant_internal_cohort,
                                     validate_billing_preflight, validate_source_containment,
                                     MINIMUM_VERSION_CODE, build)


def policy_template():
    return {**POLICY_FIXED, COHORT_KEY: ""}


def assembled():
    return assemble_candidate_defines({name: "synthetic-setting" for name in SETTINGS},
                                     json.dumps(policy_template()), "a" * 64)


def policy_hash(defines):
    return hashlib.sha256(defines["CHRONOSPARK_REMOTE_CONFIG_JSON"].encode()).hexdigest()


class InternalPolicyTests(unittest.TestCase):
    def test_reviewed_public_source_stays_private_in_candidate(self):
        source = (Path(__file__).resolve().parent.parent /
                  "lib/config/launch_containment.dart").read_text(encoding="utf-8")
        validate_source_containment(source)
        defines = assembled()
        self.assertEqual(defines["CHRONOSPARK_PUBLIC_RELEASE"], "false")
        validate_candidate_defines(defines, policy_hash(defines))
        for value in ("true", True, ""):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_candidate_defines({**defines, "CHRONOSPARK_PUBLIC_RELEASE": value},
                                           policy_hash(defines))
        del defines["CHRONOSPARK_PUBLIC_RELEASE"]
        with self.assertRaises(ValueError):
            validate_candidate_defines(defines, policy_hash(assembled()))
        for before, after in (("publicBuildValue == 'true'", "true"),
                              ("publicCloudBuildRequested && externalAiEnabled", "externalAiEnabled"),
                              ("analyticsEnabled = false", "analyticsEnabled = true")):
            self.assertIn(before, source)
            with self.subTest(before=before), self.assertRaises(ValueError):
                validate_source_containment(source.replace(before, after))

    def test_old_partial_or_failed_backend_preflight_is_rejected(self):
        repair = {
            "schemaVersion": 1,
            "internalAiCohortMatched": True,
            "obsoleteDebitDenied": True,
            "canonicalCreditAuthorityIntact": True,
            "deletionCapabilityGateway": True,
            "migrationVersion": "20260909065846",
        }
        receipt = {"verified": True, "licenseTestGuard": "v1",
                   "internalBillingCohortMatched": True, "backendRepairGate": repair}
        validate_billing_preflight(receipt)
        with self.assertRaisesRegex(ValueError, "private admission QA"):
            validate_billing_preflight(receipt, credit_admission_qa=True)
        admission = {"migrationVersion": "20260924030236", "functionVersions": {
            "verify-receipt": 42, "google-play-rtdn": 43}}
        validate_billing_preflight({**receipt, "creditAdmissionQaEnabled": True,
                                    "creditAdmissionQaMatched": True,
                                    "creditAdmissionBackend": admission}, credit_admission_qa=True)
        for bad in ({"creditAdmissionQaEnabled": False, "creditAdmissionQaMatched": True},
                    {"creditAdmissionQaEnabled": True, "creditAdmissionQaMatched": False}):
            with self.subTest(bad=bad), self.assertRaisesRegex(ValueError, "private admission QA"):
                validate_billing_preflight({**receipt, "creditAdmissionBackend": admission,
                                            **bad}, credit_admission_qa=True)
        for bad in ({}, {"migrationVersion": "old", "functionVersions": admission["functionVersions"]},
                    {"migrationVersion": "20260924030236", "functionVersions": {
                        "verify-receipt": 0, "google-play-rtdn": 43}}):
            with self.subTest(bad=bad), self.assertRaisesRegex(ValueError, "backend migration"):
                validate_billing_preflight({**receipt, "creditAdmissionQaEnabled": True,
                    "creditAdmissionQaMatched": True, "creditAdmissionBackend": bad},
                    credit_admission_qa=True)
        for invalid in ({}, {"verified": True, "licenseTestGuard": "v1"},
                        {**receipt, "verified": False}, {**receipt, "backendRepairGate": []}):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                validate_billing_preflight(invalid)
        for wrong in (None, False, "true", 0):
            with self.subTest(cohort=wrong), self.assertRaises(ValueError):
                validate_billing_preflight({**receipt, "internalBillingCohortMatched": wrong})
        for key in repair:
            for wrong in (None, False, "true", 0):
                with self.subTest(key=key, wrong=wrong), self.assertRaises(ValueError):
                    validate_billing_preflight({**receipt, "backendRepairGate": {**repair, key: wrong}})

    def test_billing_profile_keeps_reviewer_out_of_purchase_cohort(self):
        assistant_cohort = merge_assistant_internal_cohort("a" * 64, "b" * 64)
        defines = assemble_candidate_defines({name: "synthetic-setting" for name in SETTINGS},
            json.dumps(policy_template()), assistant_cohort, billing_test=True,
            billing_verified_cohort="a" * 64)
        receipt = validate_candidate_defines(defines, policy_hash(defines), billing_test=True,
                                             billing_verified_cohort="a" * 64)
        self.assertTrue(receipt["billingRequiresVerifiedTestPurchase"])
        self.assertEqual(receipt["cohortCount"], 2)
        self.assertEqual(receipt["billingCohortCount"], 1)
        self.assertEqual(defines["CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS"], "a" * 64)
        self.assertNotIn("b" * 64, defines["CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS"])
        self.assertNotIn("a" * 64, json.dumps(receipt))
        self.assertNotIn("b" * 64, json.dumps(receipt))
        self.assertEqual(defines["CHRONOSPARK_PAYWALL_DISABLED"], "false")
        with self.assertRaises(ValueError):
            validate_candidate_defines(defines, policy_hash(defines))
        defines["CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS"] = "b" * 64
        with self.assertRaises(ValueError):
            validate_candidate_defines(defines, policy_hash(defines), billing_test=True,
                                       billing_verified_cohort="a" * 64)
        with self.assertRaises(ValueError):
            merge_assistant_internal_cohort("a" * 64, "a" * 64)

    def test_private_admission_qa_requires_billing_test_profile(self):
        settings = {name: "synthetic-setting" for name in SETTINGS}
        policy = json.dumps(policy_template())
        with self.assertRaisesRegex(ValueError, "private billing-test profile"):
            assemble_candidate_defines(settings, policy, "a" * 64,
                                       credit_admission_qa=True)
        defines = assemble_candidate_defines(settings, policy, "a" * 64,
            billing_test=True, billing_verified_cohort="a" * 64,
            credit_admission_qa=True)
        self.assertEqual(defines["CHRONOSPARK_PUBLIC_CREDIT_ADMISSION_QA"], "true")
        receipt = validate_candidate_defines(defines, policy_hash(defines),
            billing_test=True, billing_verified_cohort="a" * 64,
            credit_admission_qa=True)
        self.assertTrue(receipt["creditAdmissionQa"])
        with self.assertRaises(ValueError):
            validate_candidate_defines(defines, policy_hash(defines),
                billing_test=True, billing_verified_cohort="a" * 64)

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
            (root / "pubspec.yaml").write_text(f"version: 4.1.0+{MINIMUM_VERSION_CODE}\n")
            (root / candidate.POLICY_PATH).write_text(json.dumps(policy_template()))
            features = ("externalAiEnabled", "subscriptionsEnabled", "creditSpendingEnabled",
                        "cloudSyncEnabled", "cloudRestoreEnabled", "analyticsEnabled", "crashReportingEnabled")
            (root / "lib/config/launch_containment.dart").write_text(
                "\n".join(f"static const bool {feature} = false;" for feature in features))
            env = {"GITHUB_ACTIONS": "true", "GITHUB_SHA": tooling_sha, "CANDIDATE_SHA": source_sha,
                   "CANDIDATE_CI_RUN": "42", "GITHUB_REPOSITORY": "ghostheart5/fantastic-guacamole",
                   "CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS": "a" * 64,
                   "CHRONOSPARK_REVIEWER_ACCOUNT_DIGEST": "b" * 64,
                   "RUNNER_TEMP": folder,
                   "CANDIDATE_POLICY_SHA256": policy_hash(assemble_candidate_defines(
                       {name: "synthetic-setting" for name in SETTINGS},
                       json.dumps(policy_template()),
                       merge_assistant_internal_cohort("a" * 64, "b" * 64))),
                   "ANDROID_GOOGLE_SERVICES_JSON_BASE64": "e30=",
                   **{name: "synthetic-setting" for name in SETTINGS},
                   **{name: "synthetic-signing-value" for name in
                      ("ANDROID_KEYSTORE_BASE64", "ANDROID_STORE_PASSWORD", "ANDROID_KEY_PASSWORD", "ANDROID_KEY_ALIAS")}}
            observed = []
            billing_receipt = {
                "verified": True, "licenseTestGuard": "v1",
                "internalBillingCohortMatched": True,
                "backendRepairGate": {
                    "schemaVersion": 1, "internalAiCohortMatched": True,
                    "obsoleteDebitDenied": True, "canonicalCreditAuthorityIntact": True,
                    "deletionCapabilityGateway": True, "migrationVersion": "20260909065846",
                },
            }
            def fake_command(args, cwd, capture=False, env=None):
                if args[:2] == ["gh", "api"]:
                    return json.dumps(ci)
                if args == ["git", "rev-parse", "HEAD"]:
                    return source_sha if cwd == root.resolve() else tooling_sha
                if args == ["node", "scripts/verify_internal_billing_backend.mjs"]:
                    self.assertFalse((root / "android/app/upload-keystore.jks").exists())
                    self.assertFalse((root / "android/key.properties").exists())
                    return json.dumps(billing_receipt)
                if args[0] == "dart":
                    path = Path(next(value[10:] for value in args if value.startswith("--defines=")))
                    if os.name != "nt":
                        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                    observed.append(strict_json(path.read_text()))
                    self.assertFalse((root / "android/app/upload-keystore.jks").exists())
                    self.assertFalse((root / "android/key.properties").exists())
                    raise RuntimeError("preflight reached; no build")
                self.assertNotEqual(args[:3], ["flutter", "build", "appbundle"])
                return ""
            with patch.dict(os.environ, env, clear=True), patch.object(candidate, "command", side_effect=fake_command):
                with self.assertRaisesRegex(RuntimeError, "preflight reached"):
                    build(root, Path(folder) / "bundletool.jar")
            expected = assemble_candidate_defines({name: "synthetic-setting" for name in SETTINGS},
                json.dumps(policy_template()), merge_assistant_internal_cohort("a" * 64, "b" * 64))
            self.assertEqual(observed, [expected])
            self.assertFalse((Path(folder) / "chronospark-candidate-defines.json").exists())
            # The real build entrypoint must reject the older successful
            # receipt before it can materialize a signing input or a define file.
            del billing_receipt["backendRepairGate"]
            with patch.dict(os.environ, {**env, "CANDIDATE_BILLING_TEST": "true"}, clear=True), \
                 patch.object(candidate, "command", side_effect=fake_command):
                with self.assertRaisesRegex(ValueError, "backend repair verification"):
                    build(root, Path(folder) / "bundletool.jar")
            self.assertEqual(observed, [expected])
            self.assertFalse((root / "android/app/upload-keystore.jks").exists())
            self.assertFalse((root / "android/key.properties").exists())
            self.assertFalse((Path(folder) / "chronospark-candidate-defines.json").exists())


class ReleaseRegenerationTests(unittest.TestCase):
    """Exercise build orchestration with synthetic keys and no Flutter process."""

    def run_release_fixture(self, drift=None):
        import android_candidate_build as candidate
        source_sha, tooling_sha = "a" * 40, "b" * 40
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
            (root / "pubspec.yaml").write_text(f"version: 4.1.0+{MINIMUM_VERSION_CODE}\n")
            lock = root / "pubspec.lock"
            lock.write_text("frozen dependency fixture")
            (root / candidate.POLICY_PATH).write_text(json.dumps(policy_template()))
            features = ("externalAiEnabled", "subscriptionsEnabled", "creditSpendingEnabled",
                        "cloudSyncEnabled", "cloudRestoreEnabled", "analyticsEnabled", "crashReportingEnabled")
            (root / "lib/config/launch_containment.dart").write_text(
                "\n".join(f"static const bool {feature} = false;" for feature in features))
            registrant = root / "android/app/GeneratedPluginRegistrant.java"
            env = {"GITHUB_ACTIONS": "true", "GITHUB_SHA": tooling_sha, "CANDIDATE_SHA": source_sha,
                   "CANDIDATE_CI_RUN": "42", "GITHUB_REPOSITORY": "ghostheart5/fantastic-guacamole",
                   "CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS": "a" * 64,
                   "CHRONOSPARK_REVIEWER_ACCOUNT_DIGEST": "b" * 64, "RUNNER_TEMP": folder,
                   "CANDIDATE_POLICY_SHA256": policy_hash(assemble_candidate_defines(
                       {name: "synthetic-setting" for name in SETTINGS}, json.dumps(policy_template()),
                       merge_assistant_internal_cohort("a" * 64, "b" * 64))),
                   "ANDROID_GOOGLE_SERVICES_JSON_BASE64": "e30=",
                   **{name: "synthetic-setting" for name in SETTINGS},
                   "ANDROID_KEYSTORE_BASE64": "c3ludGhldGljLW5vdC1hLWtleQ==",
                   **{name: "synthetic-signing-value" for name in
                      ("ANDROID_STORE_PASSWORD", "ANDROID_KEY_PASSWORD", "ANDROID_KEY_ALIAS")}}
            observed = []
            built = False

            def fake_command(args, cwd, capture=False, env=None):
                nonlocal built
                observed.append(args)
                if args[:2] == ["gh", "api"]:
                    return json.dumps(ci)
                if args == ["git", "rev-parse", "HEAD"]:
                    return source_sha if cwd == root.resolve() else tooling_sha
                if args == ["flutter", "pub", "get"]:
                    registrant.write_text("pl.leancode.patrol.PatrolPlugin")
                if args[0] == "keytool":
                    return "PrivateKeyEntry\nSHA1: " + UPLOAD_SHA1
                if args[:3] == ["flutter", "build", "appbundle"]:
                    self.assertIn("--release", args)
                    self.assertNotIn("--no-pub", args)
                    self.assertIn("PatrolPlugin", registrant.read_text())
                    defines = Path(next(arg.split("=", 1)[1] for arg in args
                                       if arg.startswith("--dart-define-from-file=")))
                    validate_candidate_defines(strict_json(defines.read_text()),
                                               os.environ["CANDIDATE_POLICY_SHA256"])
                    self.assertTrue((root / "android/app/upload-keystore.jks").exists())
                    self.assertIn("GRADLE_USER_HOME", env)
                    # Model Flutter's normal release regeneration, not product writes.
                    registrant.write_text("runtime plugins only")
                    built = True
                    if drift == "lock":
                        lock.write_text("unexpected dependency change")
                if built and args == ["git", "diff", "--exit-code"] and drift == "lock":
                    raise subprocess.CalledProcessError(1, args)
                if built and args == ["git", "status", "--porcelain", "--untracked-files=all"]:
                    return "?? unexpected-source-file" if drift == "source" else ""
                return ""

            with patch.dict(os.environ, env, clear=True), patch.object(candidate, "command", side_effect=fake_command):
                if drift == "lock":
                    with self.assertRaises(subprocess.CalledProcessError):
                        build(root, Path(folder) / "bundletool.jar")
                else:
                    with self.assertRaisesRegex(ValueError, "Source changed during build" if drift else "AAB missing"):
                        build(root, Path(folder) / "bundletool.jar")
            self.assertTrue(built)
            self.assertNotIn("PatrolPlugin", registrant.read_text())
            self.assertLess(observed.index(["flutter", "pub", "get"]),
                            next(i for i, args in enumerate(observed) if args[:3] == ["flutter", "build", "appbundle"]))
            self.assertEqual(observed.count(["git", "diff", "--exit-code"]), 2)
            self.assertFalse((root / "android/app/upload-keystore.jks").exists())
            self.assertFalse((root / "android/key.properties").exists())
            self.assertFalse((Path(folder) / "chronospark-candidate-defines.json").exists())
            self.assertFalse((root / "build/candidate-evidence").exists())

    def test_release_regenerates_dev_registrant_before_artifact_verification(self):
        self.run_release_fixture()

    def test_release_dependency_drift_still_rejects_artifact(self):
        self.run_release_fixture("lock")

    def test_release_source_drift_still_rejects_artifact(self):
        self.run_release_fixture("source")


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

    def test_all_candidate_profiles_reject_advertising_permissions(self):
        permissions = ('com.google.android.gms.permission.AD_ID',
                       'android.permission.ACCESS_ADSERVICES_AD_ID',
                       'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
                       'android.permission.ACCESS_ADSERVICES_TOPICS',
                       'android.permission.ACCESS_ADSERVICES_CUSTOM_AUDIENCE')
        for billing in (False, True):
            for tag in ('uses-permission', 'uses-permission-sdk-23'):
                for permission in permissions:
                    xml = manifest(billing=billing).replace('</manifest>',
                        f'<{tag} android:name="{permission}"/></manifest>')
                    with self.subTest(billing=billing, tag=tag, permission=permission), \
                            self.assertRaisesRegex(ValueError, 'No-ads policy'):
                        manifest_identity(xml, ('4.1.0', '2026083003'), billing_test=billing)

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


class DiagnosticFilterTests(unittest.TestCase):
    def test_secret_messages_and_frames_never_reach_output(self):
        secret = "deliberateSecretValue"
        d = FailureDiagnostics({"ANDROID_KEY_PASSWORD": secret})
        payload = ("Caused by: java.security.UnrecoverableKeyException: " + secret + "\n"
                   "raw bearer " + secret + "\n"
                   "\tat com.android." + secret + ".Signer.run(Signer.java:12)\n"
                   "\tat com.android.tools.Signing.run(Signing.java:42)\n")
        for offset in range(0, len(payload), 7):
            d.feed(payload[offset:offset+7].encode())
        result = "\n".join(d.finish())
        self.assertNotIn(secret, result)
        self.assertNotIn("bearer", result)
        self.assertNotIn("Signer.run", result)
        self.assertIn("exception-class: java.security.UnrecoverableKeyException", result)
        self.assertIn("stack-frame: com.android.tools.Signing.run:42", result)

    def test_output_byte_and_line_caps_apply(self):
        d = FailureDiagnostics({})
        for _ in range(MAX_OUTPUT_LINES * 4):
            d.feed(("Caused by: java." + "E" * 175 + ": untrusted message\n").encode())
        lines = d.finish()
        self.assertLessEqual(len(lines) + 1, MAX_OUTPUT_LINES)
        self.assertLessEqual(len(("\n".join(lines) + "\n" +
            "Flutter release failed; raw output suppressed.\n").encode()), MAX_OUTPUT_BYTES)
        self.assertLess(len(lines), MAX_OUTPUT_LINES - 1)  # byte cap also exercised

    def test_long_unterminated_line_is_discarded_with_bounded_buffer(self):
        d = FailureDiagnostics({})
        d.feed(b"Caused by: java.lang.Error: " + b"x" * (MAX_INPUT_LINE_BYTES * 20))
        self.assertLessEqual(len(d._pending), MAX_INPUT_LINE_BYTES)
        d.feed(b"\nCaused by: java.lang.NullPointerException\n")
        self.assertEqual(d.finish(), ("exception-class: java.lang.NullPointerException",))

    def test_short_diagnostics_hit_line_cap_before_byte_cap(self):
        d = FailureDiagnostics({})
        d.feed(b"Caused by: java.lang.Error\n" * (MAX_OUTPUT_LINES * 4))
        self.assertEqual(len(d.finish()), MAX_OUTPUT_LINES - 1)

    def test_nested_root_cause_survives_a_large_framework_trace(self):
        d = FailureDiagnostics({})
        d.feed(b"Caused by: org.gradle.api.GradleException: wrapper\n")
        d.feed(b"\tat org.gradle.execution.Task.run(Task.java:42)\n" * 200)
        d.feed(b"Caused by: java.security.UnrecoverableKeyException: private value\n")
        lines = d.finish()
        self.assertIn("exception-class: java.security.UnrecoverableKeyException", lines)
        self.assertIn("exception-class: org.gradle.api.GradleException", lines)
        self.assertLessEqual(len(lines) + 1, MAX_OUTPUT_LINES)

    def test_unknown_messages_paths_and_ansi_noise_are_omitted(self):
        d = FailureDiagnostics({})
        d.feed(b"/private/keystore/file\npassword=hidden\n"
               b"\x1b[31mCaused by: java.lang.Error: hidden\n"
               b"Execution failed for task ':app:signReleaseBundle'.\r\n")
        self.assertEqual(d.finish(), ("failed-task: :app:signReleaseBundle",))

    def test_package_and_script_import_paths_remain_available(self):
        result = subprocess.run([sys.executable, "-B", "-c",
            "from scripts.android_candidate_build import validate_internal_policy"],
            cwd=Path(__file__).resolve().parent.parent, capture_output=True)
        self.assertEqual(result.returncode, 0)


class DiagnosticProcessTests(unittest.TestCase):
    def test_nonzero_exit_preserved_and_secret_output_suppressed(self):
        out = io.StringIO()
        env = {**os.environ, "ANDROID_STORE_PASSWORD": "synthetic-secret"}
        code = "import sys; print('Caused by: java.lang.IllegalStateException: synthetic-secret'); sys.exit(9)"
        rc = run_flutter_release([sys.executable, "-c", code], Path.cwd(), env, out)
        self.assertEqual(rc, 9)
        self.assertNotIn("synthetic-secret", out.getvalue())
        self.assertIn("java.lang.IllegalStateException", out.getvalue())

    def test_success_does_not_emit_raw_stdout_or_stderr(self):
        out = io.StringIO()
        rc = run_flutter_release([sys.executable, "-c",
            "import sys; print('stdout-secret'); print('stderr-secret', file=sys.stderr)"], Path.cwd(), output=out)
        self.assertEqual(rc, 0)
        self.assertNotIn("secret", out.getvalue())
        self.assertIn("artifact verification remains required", out.getvalue())

    def test_failed_release_command_cleans_isolated_signing_state(self):
        real_popen = subprocess.Popen
        def fixture_process(args, **kwargs):
            self.assertEqual(args, ["flutter", "build", "appbundle", "--release"])
            return real_popen([sys.executable, "-c",
                "import sys; print('Caused by: java.lang.NullPointerException: secret-value'); sys.exit(7)"], **kwargs)
        out = io.StringIO()
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "bounded diagnostics"), contextlib.redirect_stderr(out):
                with candidate.signing_environment(Path(__file__).parent, folder) as env:
                    home = Path(env["GRADLE_USER_HOME"])
                    env["ANDROID_KEY_PASSWORD"] = "secret-value"
                    self.assertTrue(home.exists())
                    with patch("candidate_build_diagnostics.subprocess.Popen", side_effect=fixture_process):
                        candidate.command(["flutter", "build", "appbundle", "--release"], Path.cwd(), env=env)
            self.assertFalse(home.exists())
        self.assertNotIn("secret-value", out.getvalue())
        self.assertIn("java.lang.NullPointerException", out.getvalue())

    def test_raw_capture_is_rejected_before_spawning_release(self):
        with patch("candidate_build_diagnostics.subprocess.Popen") as spawn:
            with self.assertRaisesRegex(ValueError, "Raw Flutter"):
                candidate.command(["flutter", "build", "appbundle"], Path.cwd(), capture=True)
            spawn.assert_not_called()



if __name__ == "__main__":
    unittest.main()
