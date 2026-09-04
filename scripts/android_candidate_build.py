"""Build-only runner. Never publishes, changes cloud settings, or creates keys."""
import base64
<<<<<<< HEAD
=======
from contextlib import contextmanager
>>>>>>> origin/main
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
<<<<<<< HEAD
=======
import tempfile
>>>>>>> origin/main
import xml.etree.ElementTree as ET
import zipfile

CANDIDATE_SHA = "9e1ba13376d0747fa6393f428d66f71f353985a5"
CI_RUN = "33924430045"
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
    "CHRONOSPARK_ENFORCE_PROD_READINESS": "true",
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


<<<<<<< HEAD
def command(args, root, capture=False):
    result = subprocess.run(args, cwd=root, text=True, capture_output=capture)
=======
def command(args, root, capture=False, env=None):
    result = subprocess.run(args, cwd=root, text=True, capture_output=capture, env=env)
>>>>>>> origin/main
    require(result.returncode == 0, f"{args[0]} command failed (output not retained)")
    return result.stdout.strip() if capture else ""


<<<<<<< HEAD
def properties_escape(value):
    # java.util.Properties is ISO-8859-1; do not corrupt non-ASCII passwords.
    return "".join(f"\\u{ord(c):04x}" if ord(c) > 126 else
                   "\\" + c if c in "\\ :=#!" else c for c in value)
=======
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
>>>>>>> origin/main


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


def manifest_identity(xml, version):
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
    return int(sdk.get(android + "targetSdkVersion"))


def build(root, bundletool):
    root = root.resolve()
    tooling = Path(__file__).resolve().parent
    require(os.environ.get("GITHUB_ACTIONS") == "true", "Runner-only script")
    require(os.environ.get("CANDIDATE_SHA") == CANDIDATE_SHA and
            os.environ.get("CANDIDATE_CI_RUN") == CI_RUN, "Candidate evidence mismatch")
    require(command(["git", "rev-parse", "HEAD"], root, True) == CANDIDATE_SHA,
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
    containment = (root / "lib/config/launch_containment.dart").read_text()
    for feature in ("externalAiEnabled", "subscriptionsEnabled", "creditSpendingEnabled",
                    "cloudSyncEnabled", "cloudRestoreEnabled", "analyticsEnabled", "crashReportingEnabled"):
        require(re.search(rf"static const bool {feature}\s*=\s*false;", containment),
                f"Containment changed: {feature}")
    command(["flutter", "pub", "get"], root)
    command(["git", "diff", "--exit-code"], root)
    command(["pwsh", "-NoProfile", "-File", "scripts/release_guard.ps1"], root)
    command(["dart", "run", "scripts/validate_production_config.dart", "--platform=android",
             "--google-services=android/app/google-services.json"], root)
    key = root / "android/app/upload-keystore.jks"
<<<<<<< HEAD
    defines = Path(os.environ["RUNNER_TEMP"]) / "chronospark-candidate-defines.json"
    require(not any(p.exists() for p in (key, defines)), "Temporary signing path already exists")
    os.umask(0o077)
    try:
        key.write_bytes(base64.b64decode(os.environ["ANDROID_KEYSTORE_BASE64"], validate=True))
=======
    props = root / "android/key.properties"
    defines = Path(os.environ["RUNNER_TEMP"]) / "chronospark-candidate-defines.json"
    require(not any(p.exists() for p in (key, props, defines)), "Temporary signing path already exists")
    os.umask(0o077)
    try:
        key.write_bytes(base64.b64decode(os.environ["ANDROID_KEYSTORE_BASE64"], validate=True))
        props.write_text(SIGNING_BOOTSTRAP, encoding="ascii")
>>>>>>> origin/main
        cert = command(["keytool", "-list", "-v", "-J-Duser.language=en",
                        "-keystore", str(key), "-storepass:env", "ANDROID_STORE_PASSWORD",
                        "-alias", os.environ["ANDROID_KEY_ALIAS"]], root, True)
        require("PrivateKeyEntry" in cert, "Selected alias is not a private-key entry")
        fingerprint = re.search(r"SHA1:\s*([A-Fa-f0-9:]+)", cert)
        require(fingerprint and fingerprint[1].replace(":", "").upper() == UPLOAD_SHA1,
                "Existing upload identity pin mismatch")
        defines.write_text(json.dumps({**FLAGS, **{name: os.environ[name] for name in SETTINGS}}))
<<<<<<< HEAD
        command(["flutter", "build", "appbundle", "--release", "--no-pub",
                 "--dart-define-from-file=" + str(defines),
                 "-Pandroid.injected.signing.store.file=app/upload-keystore.jks",
                 "-Pandroid.injected.signing.store.password=$ANDROID_STORE_PASSWORD",
                 "-Pandroid.injected.signing.key.alias=" + os.environ["ANDROID_KEY_ALIAS"],
                 "-Pandroid.injected.signing.key.password=$ANDROID_KEY_PASSWORD"], root)
    finally:
        for path in (key, defines):
=======
        with signing_environment(tooling, Path(os.environ["RUNNER_TEMP"])) as env:
            command(["flutter", "build", "appbundle", "--release", "--no-pub",
                     "--dart-define-from-file=" + str(defines)], root, env=env)
    finally:
        for path in (key, props, defines):
>>>>>>> origin/main
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
    target = manifest_identity(manifest, (version[1], version[2]))
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
        "sourceSha": CANDIDATE_SHA, "ciRunId": CI_RUN,
        "toolingSha": os.environ["GITHUB_SHA"], "buildRunId": os.environ["GITHUB_RUN_ID"],
        "runAttempt": os.environ["GITHUB_RUN_ATTEMPT"], "aabSha256": digest,
        "uploadSignerSha256": signer, "package": PACKAGE,
        "versionName": version[1], "versionCode": int(version[2]), "targetSdk": target,
        "buildFlags": FLAGS, "native64BitLoadAlignment": native,
        "nativeSymbols": "Not generated by this candidate; completeness remains open",
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
