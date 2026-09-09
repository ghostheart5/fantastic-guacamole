"""Build-only runner. Never publishes, changes cloud settings, or creates keys."""
import base64
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

# Dispatch must identify a newly reviewed immutable source and its green CI.
# Never silently fall back to the previous candidate.
MINIMUM_VERSION_CODE = 2026083022
# Existing repository upload-identity pin; independent Play readback remains open.
UPLOAD_SHA1 = "8A24D7BAACAB52F0A3777DD047C907962E82FAA5"
PACKAGE = "com.ghostheart5.chronospark"
SETTINGS = (
    "CHRONOSPARK_SUPABASE_URL", "CHRONOSPARK_SUPABASE_ANON_KEY",
    "CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT", "CHRONOSPARK_AI_PROXY_ENDPOINT",
    "CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT", "CHRONOSPARK_ANDROID_SHA256_CERT",
)
FLAGS = {
    "CHRONOSPARK_APP_FLAVOR": "prod",
    "CHRONOSPARK_BACKEND_MODE": "cloud",
    "CHRONOSPARK_ENFORCE_PROD_READINESS": "true",
    "CHRONOSPARK_INTERNAL_BILLING_TEST": "false",
    "CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS": "",
    **{name: "false" for name in (
        "CHRONOSPARK_VERBOSE_LOGS", "CHRONOSPARK_ENABLE_MOCK_LOGIN",
        "CHRONOSPARK_ENABLE_MOCK_MODE", "CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS",
        "CHRONOSPARK_PAYWALL_DISABLED", "CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS",
        "CHRONOSPARK_ENABLE_CLOUD_SYNC", "CHRONOSPARK_ENABLE_ANALYTICS",
        "CHRONOSPARK_ENABLE_CRASH_REPORTING",
    )},
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_billing_preflight(receipt):
    require(type(receipt) is dict and receipt.get("verified") is True and
            receipt.get("licenseTestGuard") == "v1", "Live billing preflight failed")
    repair = receipt.get("backendRepairGate")
    expected = {
        "schemaVersion": 1,
        "internalAiCohortMatched": True,
        "obsoleteDebitDenied": True,
        "canonicalCreditAuthorityIntact": True,
        "deletionCapabilityGateway": True,
        "migrationVersion": "20260909065846",
    }
    require(type(repair) is dict and all(
        type(repair.get(key)) is type(value) and repair.get(key) == value
        for key, value in expected.items()
    ), "Deployed backend repair verification is required before signing")


POLICY_PATH = "tool/internal_testing_assistant_release.json"
POLICY_FIXED = {
    "assistant_release_stage": "internal",
    "assistant_release_canary_basis_points": 0,
    "assistant_shadow_evaluation_enabled": False,
    "kill_assistant_smart_planner_v2": False,
    "kill_assistant_si_console_v2": False,
    "kill_assistant_governed_memory": False,
    "kill_assistant_safety_critic": False,
    "kill_assistant_planner_explanation": True,
}
COHORT_KEY = "assistant_release_internal_account_digests"


def strict_json(text):
    def object_pairs(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key rejected")
            result[key] = value
        return result
    try:
        return json.loads(text, object_pairs_hook=object_pairs,
                          parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
    except (ValueError, TypeError):
        # Input may contain account information; never echo parser context.
        raise ValueError("Invalid or duplicate JSON configuration") from None


def validate_internal_policy(policy):
    require(type(policy) is dict and set(policy) == set(POLICY_FIXED) | {COHORT_KEY},
            "Internal policy keys are missing or unknown")
    for key, expected in POLICY_FIXED.items():
        require(type(policy[key]) is type(expected) and policy[key] == expected,
                "Internal policy violates stage, safety, memory, or containment requirements")
    raw = policy[COHORT_KEY]
    require(type(raw) is str and bool(raw), "Verified internal account cohort is required")
    digests = raw.split(",")
    excluded = {hashlib.sha256(value.encode()).hexdigest()
                for value in ("v2.signed_out", "v2.unsafe", "")}
    require(0 < len(digests) <= 100 and len(digests) == len(set(digests)),
            "Internal account cohort must contain 1-100 unique digests")
    require(all(re.fullmatch(r"[a-f0-9]{64}", value) and value not in excluded
                for value in digests), "Internal account cohort contains an invalid or unsafe digest")
    return {**policy, COHORT_KEY: ",".join(sorted(digests))}


def assemble_candidate_defines(settings, policy_text, verified_cohort, billing_test=False):
    require(type(billing_test) is bool, "Billing profile must be explicitly true or false")
    policy = strict_json(policy_text)
    require(type(policy) is dict and policy.get(COHORT_KEY) == "",
            "Reviewed policy must use the private verified cohort input")
    policy[COHORT_KEY] = verified_cohort
    policy = validate_internal_policy(policy)
    for name in SETTINGS:
        require(type(settings.get(name)) is str and bool(settings[name].strip()),
                f"Missing setting: {name}")
    return {**FLAGS, **{name: settings[name] for name in SETTINGS},
            "CHRONOSPARK_INTERNAL_BILLING_TEST": "true" if billing_test else "false",
            "CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS": policy[COHORT_KEY] if billing_test else "",
            "CHRONOSPARK_REMOTE_CONFIG_JSON": json.dumps(policy, sort_keys=True, separators=(",", ":"))}


def validate_candidate_defines(defines, expected_policy_sha256, billing_test=False):
    require(type(billing_test) is bool, "Billing profile must be explicitly true or false")
    require(type(defines) is dict and set(defines) ==
            set(FLAGS) | set(SETTINGS) | {"CHRONOSPARK_REMOTE_CONFIG_JSON"},
            "Final candidate defines contain missing or unknown settings")
    policy = validate_internal_policy(strict_json(defines["CHRONOSPARK_REMOTE_CONFIG_JSON"]))
    expected_flags = {**FLAGS,
        "CHRONOSPARK_INTERNAL_BILLING_TEST": "true" if billing_test else "false",
        "CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS": policy[COHORT_KEY] if billing_test else ""}
    require(all(type(defines[key]) is str and defines[key] == value
                for key, value in expected_flags.items()), "Final candidate flags violate production containment")
    require(all(type(defines[key]) is str and bool(defines[key].strip()) for key in SETTINGS),
            "Final candidate service settings are missing")
    canonical = json.dumps(policy, sort_keys=True, separators=(",", ":"))
    require(defines["CHRONOSPARK_REMOTE_CONFIG_JSON"] == canonical,
            "Final candidate policy must use canonical encoding")
    digest = hashlib.sha256(canonical.encode()).hexdigest()
    require(re.fullmatch(r"[a-f0-9]{64}", expected_policy_sha256 or "") and
            expected_policy_sha256 == digest, "Reviewed effective policy digest mismatch")
    return {"sha256": digest, "stage": "internal",
            "cohortCount": len(policy[COHORT_KEY].split(",")),
            "enabledLocalCapabilities": ["smartPlannerV2", "siConsoleV2", "governedMemory", "safetyCritic"],
            "rolledBackCapabilities": ["plannerExplanation"],
            "consentRequired": True, "runtimeFlagsEnabled": False,
            "internalBillingTest": billing_test,
            "billingRequiresVerifiedTestPurchase": billing_test}


def validate_ci_evidence(evidence, source_sha, ci_run, repository):
    require(re.fullmatch(r"[a-f0-9]{40}", source_sha or "") and
            re.fullmatch(r"[1-9][0-9]*", ci_run or ""), "Explicit source SHA and CI run are required")
    require(type(evidence) is dict and str(evidence.get("id")) == ci_run and
            evidence.get("head_sha") == source_sha and
            evidence.get("repository", {}).get("full_name") == repository and
            evidence.get("path") == ".github/workflows/ci.yml" and
            evidence.get("event") == "workflow_dispatch" and
            evidence.get("status") == "completed" and evidence.get("conclusion") == "success",
            "Candidate CI evidence does not match successful exact-source CI")
    return {"id": ci_run, "headSha": source_sha, "conclusion": "success",
            "runAttempt": evidence.get("run_attempt"), "url": evidence.get("html_url")}


def command(args, root, capture=False, env=None):
    result = subprocess.run(args, cwd=root, text=True, capture_output=capture, env=env)
    require(result.returncode == 0, f"{args[0]} command failed (output not retained)")
    return result.stdout.strip() if capture else ""


SIGNING_BOOTSTRAP = (
    "# Non-secret bootstrap; real signing values are injected in memory.\n"
    "storePassword=environment-injected\n"
    "keyPassword=environment-injected\n"
    "keyAlias=environment-injected\n"
    "storeFile=app/upload-keystore.jks\n"
)


@contextmanager
def signing_environment(tooling, runner_temp):
    # Scope the hook and any Gradle daemon/cache state to this one build.
    # Never serialize the environment or interpolate secret values into a script.
    with tempfile.TemporaryDirectory(prefix="chronospark-signing-", dir=runner_temp) as folder:
        home = Path(folder)
        (home / "init.d").mkdir()
        shutil.copyfile(tooling / "candidate-signing.init.gradle",
                        home / "init.d/candidate-signing.init.gradle")
        (home / "gradle.properties").write_text(
            "org.gradle.daemon=false\norg.gradle.configuration-cache=false\n",
            encoding="ascii")
        env = os.environ.copy()
        env["GRADLE_USER_HOME"] = str(home)
        env["GRADLE_OPTS"] = (env.get("GRADLE_OPTS", "") +
                              " -Dorg.gradle.daemon=false -Dorg.gradle.configuration-cache=false")
        yield env


def elf_alignment(data):
    require(data[:4] == b"\x7fELF" and data[5] == 1, "Invalid/little-endian ELF required")
    # 16 KB applies to the shipped 64-bit ARM/x86 libraries; inspect all LOADs.
    require(data[4] == 2, "Expected 64-bit ELF")
    offset = struct.unpack_from("<Q", data, 32)[0]
    entry_size, count = struct.unpack_from("<HH", data, 54)
    require(entry_size >= 56 and count > 0, "Invalid ELF program headers")
    loads = []
    for index in range(count):
        fields = struct.unpack_from("<IIQQQQQQ", data, offset + index * entry_size)
        if fields[0] == 1:
            file_offset, virtual_address, alignment = fields[2], fields[3], fields[7]
            require(alignment >= 16384 and alignment & (alignment - 1) == 0,
                    "Native LOAD alignment is below 16 KB or invalid")
            require(file_offset % alignment == virtual_address % alignment,
                    "Native LOAD offset/address alignment mismatch")
            loads.append(alignment)
    require(bool(loads), "ELF has no LOAD segment")
    return min(loads)


def manifest_identity(xml, version, billing_test=False):
    require(type(billing_test) is bool, "Billing profile must be explicitly true or false")
    manifest = ET.fromstring(xml)
    android = "{http://schemas.android.com/apk/res/android}"
    require(manifest.get("package") == PACKAGE, "AAB package mismatch")
    require(manifest.get(android + "versionName") == version[0], "AAB version name mismatch")
    require(manifest.get(android + "versionCode") == version[1], "AAB version code mismatch")
    sdk = manifest.find("uses-sdk")
    require(sdk is not None and int(sdk.get(android + "targetSdkVersion", "0")) >= 36,
            "AAB target SDK below source requirement")
    app = manifest.find("application")
    require(app is not None and app.get(android + "debuggable", "false") == "false",
            "Debuggable AAB rejected")
    require(app.get(android + "testOnly", "false") == "false", "Test-only AAB rejected")
    billing_permission = any(node.get(android + "name") == "com.android.vending.BILLING"
                             for node in manifest.findall("uses-permission"))
    require(billing_permission == billing_test,
            "Compiled billing permission does not match the selected billing profile")
    return int(sdk.get(android + "targetSdkVersion"))


def build(root, bundletool):
    root = root.resolve()
    tooling = Path(__file__).resolve().parent
    require(os.environ.get("GITHUB_ACTIONS") == "true", "Runner-only script")
    billing_profile = os.environ.get("CANDIDATE_BILLING_TEST", "false")
    require(billing_profile in ("true", "false"), "Unknown billing build profile")
    billing_test = billing_profile == "true"
    source_sha = os.environ.get("CANDIDATE_SHA", "")
    ci_run = os.environ.get("CANDIDATE_CI_RUN", "")
    require(re.fullmatch(r"[a-f0-9]{40}", source_sha) and re.fullmatch(r"[1-9][0-9]*", ci_run),
            "Explicit source SHA and CI run are required")
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    require(repository == "ghostheart5/fantastic-guacamole", "Unexpected candidate repository")
    ci = strict_json(command(["gh", "api", f"repos/{repository}/actions/runs/{ci_run}"], root, True))
    ci_receipt = validate_ci_evidence(ci, source_sha, ci_run, repository)
    require(command(["git", "rev-parse", "HEAD"], tooling.parent, True) == os.environ["GITHUB_SHA"],
            "Tooling SHA mismatch")
    require(not command(["git", "status", "--porcelain", "--untracked-files=all"], tooling.parent, True),
            "Build tooling checkout is dirty")
    require(command(["git", "rev-parse", "HEAD"], root, True) == source_sha,
            "Source SHA mismatch")
    require(not command(["git", "status", "--porcelain", "--untracked-files=all"], root, True),
            "Candidate checkout is dirty")
    required = SETTINGS + ("ANDROID_KEYSTORE_BASE64", "ANDROID_STORE_PASSWORD",
                           "ANDROID_KEY_PASSWORD", "ANDROID_KEY_ALIAS",
                           "ANDROID_GOOGLE_SERVICES_JSON_BASE64")
    for name in required:
        require(bool(os.environ.get(name, "").strip()), f"Missing setting: {name}")
    for name in ("ANDROID_STORE_PASSWORD", "ANDROID_KEY_PASSWORD", "ANDROID_KEY_ALIAS"):
        require(not any(ord(c) < 32 or ord(c) > 65535 for c in os.environ[name]),
                f"Unsupported control character in {name}")
    # Configuration drift must not silently change the frozen app tree.
    firebase = json.loads(base64.b64decode(os.environ["ANDROID_GOOGLE_SERVICES_JSON_BASE64"], validate=True))
    require(firebase == json.loads((root / "android/app/google-services.json").read_text()),
            "Firebase secret differs from frozen source; review required")
    version = re.search(r"(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$",
                        (root / "pubspec.yaml").read_text())
    require(version is not None, "Invalid committed version")
    require(int(version[2]) >= MINIMUM_VERSION_CODE, "Replacement version code must exceed the installed candidate")
    containment = (root / "lib/config/launch_containment.dart").read_text()
    for feature in ("externalAiEnabled", "subscriptionsEnabled", "creditSpendingEnabled",
                    "cloudSyncEnabled", "cloudRestoreEnabled", "analyticsEnabled", "crashReportingEnabled"):
        require(re.search(rf"static const bool {feature}\s*=\s*false;", containment),
                f"Containment changed: {feature}")
    command(["flutter", "pub", "get"], root)
    command(["git", "diff", "--exit-code"], root)
    command(["pwsh", "-NoProfile", "-File", "scripts/release_guard.ps1"], root)
    billing_receipt = None
    if billing_test:
        billing_receipt = strict_json(command(
            ["node", "scripts/verify_internal_billing_backend.mjs"], root, True))
        validate_billing_preflight(billing_receipt)
    key = root / "android/app/upload-keystore.jks"
    props = root / "android/key.properties"
    defines = Path(os.environ["RUNNER_TEMP"]) / "chronospark-candidate-defines.json"
    require(not any(p.exists() for p in (key, props, defines)), "Temporary signing path already exists")
    os.umask(0o077)
    try:
        assembled = assemble_candidate_defines(os.environ, (root / POLICY_PATH).read_text(encoding="utf-8"),
                                              os.environ.get("CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS", ""), billing_test)
        defines.write_text(json.dumps(assembled), encoding="utf-8")
        # Read back and validate exactly the file passed to Flutter, before touching keys.
        policy_receipt = validate_candidate_defines(strict_json(defines.read_text(encoding="utf-8")),
                                                   os.environ.get("CANDIDATE_POLICY_SHA256", ""), billing_test)
        command(["dart", "run", "scripts/validate_production_config.dart", "--platform=android",
                 "--google-services=android/app/google-services.json", "--defines=" + str(defines)], root)
        require(strict_json(defines.read_text(encoding="utf-8")) == assembled,
                "Final defines changed during production validation")
        key.write_bytes(base64.b64decode(os.environ["ANDROID_KEYSTORE_BASE64"], validate=True))
        props.write_text(SIGNING_BOOTSTRAP, encoding="ascii")
        cert = command(["keytool", "-list", "-v", "-J-Duser.language=en",
                        "-keystore", str(key), "-storepass:env", "ANDROID_STORE_PASSWORD",
                        "-alias", os.environ["ANDROID_KEY_ALIAS"]], root, True)
        require("PrivateKeyEntry" in cert, "Selected alias is not a private-key entry")
        fingerprint = re.search(r"SHA1:\s*([A-Fa-f0-9:]+)", cert)
        require(fingerprint and fingerprint[1].replace(":", "").upper() == UPLOAD_SHA1,
                "Existing upload identity pin mismatch")
        with signing_environment(tooling, Path(os.environ["RUNNER_TEMP"])) as env:
            command(["flutter", "build", "appbundle", "--release", "--no-pub",
                     "--dart-define-from-file=" + str(defines)], root, env=env)
    finally:
        for path in (key, props, defines):
            path.unlink(missing_ok=True)
    command(["git", "diff", "--exit-code"], root)
    require(not command(["git", "status", "--porcelain", "--untracked-files=all"], root, True),
            "Source changed during build")
    aab = root / "build/app/outputs/bundle/release/app-release.aab"
    require(aab.is_file() and aab.stat().st_size > 0, "AAB missing")
    signer = command(["java", str(tooling / "VerifyCandidateSignature.java"), str(aab), UPLOAD_SHA1], root, True)
    require(re.fullmatch(r"[0-9A-F]{64}", signer), "Invalid signer verification output")
    bundle = ["java", "-jar", str(bundletool.resolve())]
    command(bundle + ["validate", "--bundle=" + str(aab)], root)
    config = command(bundle + ["dump", "config", "--bundle=" + str(aab)], root, True)
    require("PAGE_ALIGNMENT_16K" in config and "PAGE_ALIGNMENT_4K" not in config,
            "Bundle does not request 16 KB ZIP alignment")
    manifest = command(bundle + ["dump", "manifest", "--bundle=" + str(aab), "--module=base"], root, True)
    target = manifest_identity(manifest, (version[1], version[2]), billing_test=billing_test)
    native = {}
    with zipfile.ZipFile(aab) as archive:
        require(len(archive.namelist()) == len(set(archive.namelist())), "Duplicate archive entries")
        for name in archive.namelist():
            if re.search(r"/lib/(arm64-v8a|x86_64)/[^/]+\.so$", name):
                native[name] = elf_alignment(archive.read(name))
        require(any("/arm64-v8a/" in name for name in native), "Missing ARM64 native payload")
    evidence = root / "build/candidate-evidence"
    require(not evidence.exists(), "Evidence directory already exists")
    evidence.mkdir()
    digest = hashlib.sha256(aab.read_bytes()).hexdigest()
    shutil.copy2(aab, evidence / "app-release.aab")
    (evidence / "app-release.aab.sha256").write_text(digest + "  app-release.aab\n")
    (evidence / "manifest.xml").write_text(manifest)
    (evidence / "bundle-config.json").write_text(config)
    symbols = root / "build/app/outputs/mapping/release"
    require((symbols / "mapping.txt").is_file(), "R8 mapping missing")
    shutil.copy2(symbols / "mapping.txt", evidence / "mapping.txt")
    report = {
        "sourceSha": source_sha, "ciRunId": ci_run, "ciEvidence": ci_receipt,
        "toolingSha": os.environ["GITHUB_SHA"], "buildRunId": os.environ["GITHUB_RUN_ID"],
        "runAttempt": os.environ["GITHUB_RUN_ATTEMPT"], "aabSha256": digest,
        "uploadSignerSha256": signer, "package": PACKAGE,
        "versionName": version[1], "versionCode": int(version[2]), "targetSdk": target,
        "compiledBillingPermission": billing_test,
        "buildFlags": {**FLAGS, "CHRONOSPARK_INTERNAL_BILLING_TEST": str(billing_test).lower(),
                       "CHRONOSPARK_INTERNAL_BILLING_ACCOUNT_DIGESTS": "private cohort" if billing_test else ""},
        "assistantPolicy": policy_receipt, "native64BitLoadAlignment": native,
        "internalBillingBackend": billing_receipt,
        "nativeSymbols": "Inspect bundled debug-symbol metadata; presence, build-ID matching and completeness require independent verification",
        "boundary": "BUILD ONLY - NOT RELEASE APPROVAL",
        "notVerified": ["Play upload certificate authority", "Play version-code monotonicity",
                        "Phase 5 HTTPS and legal parity", "live backend", "physical device",
                        "16 KB runtime behavior", "human UAT"],
    }
    (evidence / "candidate.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Verified candidate saved; deferred release gates remain open.")


if __name__ == "__main__":
    try:
        build(Path(sys.argv[1]), Path(sys.argv[2]))
    except Exception as error:
        # Only our authored gate messages are log-safe; library errors may echo input.
        print(str(error) if type(error) is ValueError else
              "Candidate build failed; sensitive exception detail suppressed.", file=sys.stderr)
        sys.exit(1)
