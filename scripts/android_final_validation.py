"""Disposable hosted validation; never publishes or accesses production secrets."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import zipfile
import xml.etree.ElementTree as ET

import android_candidate_build as candidate_tools

PACKAGE = "com.ghostheart5.chronospark"
BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
SOURCE_FILES = (
    "app_startup_test.dart", "auth_flow_integration_test.dart",
    "persistence_recovery_test.dart", "planner_learning_identity_test.dart",
)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def validate_run(run, source, run_id, repository):
    require(re.fullmatch(r"[a-f0-9]{40}", source or ""), "Invalid immutable source SHA")
    require(re.fullmatch(r"[1-9][0-9]*", run_id or ""), "Invalid candidate run ID")
    require(str(run.get("id")) == run_id and
            run.get("repository", {}).get("full_name") == repository and
            run.get("head_repository", {}).get("full_name") == repository and
            run.get("head_branch") == "fix/app-only-readiness-priority2-20260902" and
            run.get("path") == ".github/workflows/android-candidate-build.yml" and
            run.get("event") == "workflow_dispatch" and
            run.get("status") == "completed" and run.get("conclusion") == "success" and
            re.fullmatch(r"[a-f0-9]{40}", run.get("head_sha", "")) and
            type(run.get("run_attempt")) is int and run["run_attempt"] > 0,
            "Candidate run is not a successful completed build in this repository")


def validate_artifact(artifact, run, source, run_id):
    expected = f"chronospark-candidate-{source}-{run_id}-{run['run_attempt']}"
    require(artifact.get("name") == expected and artifact.get("expired") is False and
            type(artifact.get("id")) is int and artifact["id"] > 0 and
            0 < artifact.get("size_in_bytes", 0) <= 1024 * 1024 * 1024 and
            artifact.get("workflow_run", {}).get("id") == int(run_id) and
            artifact.get("workflow_run", {}).get("head_sha") == run["head_sha"] and
            re.fullmatch(r"sha256:[a-f0-9]{64}", artifact.get("digest", "")),
            "Candidate artifact identity, expiry, size or digest is invalid")


def verify_candidate(archive_path, run, artifact, source, run_id, repository):
    validate_run(run, source, run_id, repository)
    validate_artifact(artifact, run, source, run_id)
    archive_sha = digest(archive_path)
    require(artifact["digest"] == "sha256:" + archive_sha, "Downloaded artifact ZIP digest mismatch")
    with zipfile.ZipFile(archive_path) as archive:
        require(len(archive.namelist()) == len(set(archive.namelist())), "Duplicate artifact ZIP entries")
        for name in ("candidate.json", "additional-license-verification.json"):
            require(name in archive.namelist() and archive.getinfo(name).file_size < 1024 * 1024,
                    "Candidate evidence is missing or oversized")
        candidate = json.loads(archive.read("candidate.json"))
        licenses = json.loads(archive.read("additional-license-verification.json"))
        require(candidate.get("sourceSha") == source and
                str(candidate.get("buildRunId")) == run_id and
                str(candidate.get("runAttempt")) == str(run["run_attempt"]) and
                candidate.get("toolingSha") == run["head_sha"] and
                candidate.get("package") == PACKAGE and
                type(candidate.get("versionCode")) is int and candidate["versionCode"] > 0 and
                re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", candidate.get("versionName", "")),
                "Candidate manifest does not bind this source, build, tooling and package")
        require("app-release.aab" in archive.namelist() and
                0 < archive.getinfo("app-release.aab").file_size <= 1024 * 1024 * 1024,
                "Candidate AAB is missing or oversized")
        aab_hash = hashlib.sha256()
        with archive.open("app-release.aab") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                aab_hash.update(chunk)
        aab_sha = aab_hash.hexdigest()
        require(aab_sha == candidate.get("aabSha256"), "Candidate AAB SHA256 mismatch")
        require(licenses.get("success") is True and licenses.get("artifactSha256") == aab_sha,
                "Candidate complete-license artifact receipt is absent or mismatched")
    return {"sourceSha": source, "candidateRunId": run_id,
            "candidateRunAttempt": run["run_attempt"], "candidateToolingSha": run["head_sha"],
            "candidateArtifactId": artifact["id"], "candidateArtifactSha256": archive_sha,
            "aabSha256": aab_sha, "versionName": candidate["versionName"],
            "versionCode": candidate["versionCode"], "uploadSignerSha256": candidate["uploadSignerSha256"],
            "package": PACKAGE, "repository": repository}


class Commands:
    def __init__(self, evidence):
        self.evidence = Path(evidence).resolve()
        self.evidence.mkdir(parents=True, exist_ok=True)
        self.records = []

    def run(self, label, argv, *, cwd=None, timeout=120, input_text=None, check=True):
        start = time.monotonic()
        record = {"label": label, "argv": [str(x) for x in argv], "cwd": str(cwd) if cwd else None,
                  "startedAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  "timeoutSeconds": timeout}
        log = self.evidence / (label + ".log")
        try:
            result = subprocess.run(argv, cwd=cwd, input=input_text, encoding="utf-8",
                                    errors="replace", stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=timeout)
            log.write_text(result.stdout, encoding="utf-8")
            record["exitCode"] = result.returncode
            record["timedOut"] = False
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            log.write_text(output.decode("utf-8", "replace") if isinstance(output, bytes) else output,
                           encoding="utf-8")
            record.update(exitCode=None, timedOut=True)
            raise RuntimeError(f"Command timed out: {label}") from error
        finally:
            record["seconds"] = round(time.monotonic() - start, 3)
            self.records.append(record)
            write_json(self.evidence / "commands.json", self.records)
        if check:
            require(result.returncode == 0, f"Command failed: {label}; see retained log")
        return result.stdout.strip()


def source_receipt(source, tooling, evidence):
    commands = Commands(evidence)
    actual = commands.run("source-head", ["git", "rev-parse", "HEAD"], cwd=source)
    tooling_sha = commands.run("tooling-head", ["git", "rev-parse", "HEAD"], cwd=tooling)
    require(actual == os.environ["SOURCE_SHA"] and tooling_sha == os.environ["GITHUB_SHA"],
            "Source or validation tooling checkout mismatch")
    require(not commands.run("tracked-status", ["git", "status", "--porcelain", "--untracked-files=no"], cwd=source),
            "Tracked source is dirty")
    result = {"sourceSha": actual, "validationToolingSha": tooling_sha,
              "repository": os.environ["GITHUB_REPOSITORY"],
              "validationRunId": os.environ["GITHUB_RUN_ID"],
              "validationRunAttempt": os.environ["GITHUB_RUN_ATTEMPT"],
              "job": os.environ["GITHUB_JOB"],
              "candidateRunId": os.environ["CANDIDATE_RUN"],
              "candidateArtifactId": os.environ["CANDIDATE_ARTIFACT_ID"],
              "candidateArtifactSha256": os.environ["CANDIDATE_ARTIFACT_SHA"],
              "candidateToolingSha": os.environ["CANDIDATE_TOOLING_SHA"],
              "aabSha256": os.environ["CANDIDATE_AAB_SHA"],
              "pubspecLockSha256": digest(source / "pubspec.lock"),
              "commandsExecutedAfterCompletedCandidateGate": True}
    write_json(Path(evidence) / "source-provenance.json", result)


def verify_terminal(path):
    receipt = read_json(path)
    totals = receipt.get("totals", {})
    require(receipt.get("finalSuccess") is True and receipt.get("exitCode") == 0 and
            receipt.get("terminalCompletion") is True and receipt.get("terminalSuccess") is True and
            receipt.get("timedOut") is False and receipt.get("launchFailed") is False and
            totals.get("total", 0) > 0 and totals.get("passed") == totals.get("total") and
            all(totals.get(key) == 0 for key in ("failed", "error", "skipped")) and
            receipt.get("completedTests") == totals["total"] and receipt.get("reportParseErrors") == [],
            "Canonical test receipt is not a complete passing zero-skip execution")
    return totals


def configure_avd(path):
    settings = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            settings[key.strip()] = value.strip()
    settings.update({"hw.ramSize": "2048", "hw.cpu.ncore": "2", "hw.gpu.enabled": "yes",
                     "hw.gpu.mode": "swiftshader", "hw.audioInput": "no", "hw.audioOutput": "no",
                     "hw.lcd.width": "320", "hw.lcd.height": "640", "hw.lcd.density": "160",
                     "fastboot.forceColdBoot": "yes", "fastboot.forceFastBoot": "no"})
    path.write_text("\n".join(f"{k}={v}" for k, v in settings.items()) + "\n", encoding="utf-8")
    return settings


def integration(commands, source, adb):
    actual = {path.name for path in (source / "integration_test").glob("*_test.dart")}
    require(actual == set(SOURCE_FILES), "Maintained native test inventory changed; review this runner")
    results = []
    for viewport in ("320x640", "411x891"):
        commands.run("viewport-" + viewport, adb + ["shell", "wm", "size", viewport])
        files = SOURCE_FILES if viewport == "320x640" else ("auth_flow_integration_test.dart",)
        for filename in files:
            label = Path(filename).stem + "-" + viewport
            manifest = commands.evidence / (label + "-manifest.json")
            commands.run(label, ["dart", "run", "tool/run_flutter_tests.dart", "--report",
                                str(commands.evidence / (label + ".jsonl")), "--manifest", str(manifest),
                                "--timeout-seconds", "900", "--", "integration_test/" + filename,
                                "--no-pub", "--concurrency=1", "-d", "emulator-5554"],
                         cwd=source, timeout=960, check=False)
            entry = {"file": filename, "viewport": viewport,
                     "runnerExitCode": commands.records[-1]["exitCode"], "passed": False}
            try:
                require(entry["runnerExitCode"] == 0, "Original canonical runner exited unsuccessfully")
                entry["totals"] = verify_terminal(manifest)
                entry["passed"] = True
            except (RuntimeError, OSError, ValueError) as error:
                entry["failure"] = str(error)
            results.append(entry)
            write_json(commands.evidence / "integration-results.json", results)
    commands.run("restore-viewport", adb + ["shell", "wm", "size", "320x640"])
    require(all(entry["passed"] for entry in results), "One or more native integration runs failed")
    return {"runs": results, "boundary": "Test-fake native integration, not the signed release or Play Billing."}


def fatal_lines(log, package=PACKAGE):
    patterns = [r"FATAL EXCEPTION", r"Fatal signal \d+", r"E/flutter.*(?:Unhandled Exception|\[ERROR)",
                r"MissingPluginException", r"Failed assertion", r"ANR in\s+" + re.escape(package),
                r"Process\s+" + re.escape(package) + r"\s+has died"]
    return [line for line in log.splitlines() if any(re.search(pattern, line) for pattern in patterns)]


def verify_rendered_onboarding(path):
    nodes = list(ET.parse(path).iter("node"))
    labels = [(node.get("text", "") + "\n" + node.get("content-desc", "")).upper() for node in nodes]
    require(any("CHRONOSPARK" in re.sub(r"\s+", "", label) for label in labels),
            "ChronoSpark's fresh welcome content is not rendered")
    for node, label in zip(nodes, labels):
        if not any(action in label for action in ("CONTINUE TO LOGIN", "CONTINUAR AL ACCESO")):
            continue
        bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
        if (node.get("enabled") == "true" and node.get("clickable") == "true" and bounds and
                0 <= int(bounds[1]) < int(bounds[3]) <= 320 and
                0 <= int(bounds[2]) < int(bounds[4]) <= 640):
            return
    raise RuntimeError("Fresh onboarding's enabled login CTA is not visibly reachable")


def release_16kb(commands, source, tooling, adb, sdk):
    require(commands.run("page-size", adb + ["shell", "getconf", "PAGE_SIZE"]) == "16384",
            "Guest page size is not 16384; no 4KB fallback is permitted")
    require(commands.run("guest-sdk", adb + ["shell", "getprop", "ro.build.version.sdk"]) == "37" and
            commands.run("guest-sdk-full", adb + ["shell", "getprop", "ro.build.version.sdk_full"]) == "37.1" and
            commands.run("guest-build-type", adb + ["shell", "getprop", "ro.build.type"]) == "userdebug",
            "The expected API37.1 userdebug guest is not running")
    commands.run("root-owned-userdebug-adb", adb + ["root"])
    commands.run("wait-for-root-adb", adb + ["wait-for-device"], timeout=60)
    require(commands.run("root-readback", adb + ["shell", "id", "-u"]) == "0",
            "Strict compatibility validation requires the verified userdebug image")
    for name, value in (("bionic.linker.16kb.app_compat.enabled", "fatal"),
                        ("pm.16kb.app_compat.disabled", "true")):
        commands.run("set-" + name, adb + ["shell", "setprop", name, value])
        require(commands.run("read-" + name, adb + ["shell", "getprop", name]) == value,
                "Strict 16KB compatibility mode could not be established")
    archive = Path(os.environ["CANDIDATE_ZIP"])
    candidate = verify_candidate(archive, read_json(os.environ["CANDIDATE_RUN_JSON"]),
                                 read_json(os.environ["CANDIDATE_ARTIFACT_JSON"]),
                                 os.environ["SOURCE_SHA"], os.environ["CANDIDATE_RUN"],
                                 os.environ["GITHUB_REPOSITORY"])
    require(candidate["aabSha256"] == os.environ["CANDIDATE_AAB_SHA"], "Gated AAB identity changed")
    version = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$",
                        (source / "pubspec.yaml").read_text(), re.MULTILINE)
    require(version and version[1] == candidate["versionName"] and int(version[2]) == candidate["versionCode"],
            "Candidate version does not match the immutable source manifest")
    temp = Path(os.environ["RUNNER_TEMP"]) / "derived-release"
    temp.mkdir(exist_ok=False)
    aab = temp / "app-release.aab"
    with zipfile.ZipFile(archive) as zipped, zipped.open("app-release.aab") as stream, aab.open("wb") as dest:
        shutil.copyfileobj(stream, dest)
    bundletool = Path(os.environ["BUNDLETOOL"])
    require(digest(bundletool) == BUNDLETOOL_SHA256, "Bundletool checksum mismatch")
    upload_signer = commands.run("aab-signature", ["java", str(tooling / "scripts/VerifyCandidateSignature.java"),
                                  str(aab), candidate_tools.UPLOAD_SHA1], cwd=source)
    require(upload_signer == candidate["uploadSignerSha256"], "Upload signer SHA256 differs from the candidate receipt")
    commands.run("aab-licenses", ["python3", "scripts/verify_additional_licenses.py", "--artifact", str(aab),
                                 "--repo-root", str(source), "--flutter-executable", shutil.which("flutter"),
                                 "--report", str(commands.evidence / "aab-licenses.json")], cwd=source)
    bundle = ["java", "-jar", str(bundletool)]
    commands.run("bundle-validate", bundle + ["validate", "--bundle=" + str(aab)])
    require("PAGE_ALIGNMENT_16K" in commands.run("bundle-config", bundle + ["dump", "config", "--bundle=" + str(aab)]),
            "AAB does not declare 16KB ZIP alignment")
    manifest = commands.run("bundle-manifest", bundle + ["dump", "manifest", "--bundle=" + str(aab), "--module=base"])
    # Billing permission may be present; this lane never signs in or purchases.
    candidate_tools.manifest_identity(manifest, (candidate["versionName"], str(candidate["versionCode"])),
                                     billing_test="com.android.vending.BILLING" in manifest)
    keystore = temp / "disposable-test.jks"
    commands.run("generate-disposable-signing-key", ["keytool", "-genkeypair", "-keystore", str(keystore),
                  "-storepass", "android", "-keypass", "android", "-alias", "validation", "-keyalg", "RSA",
                  "-keysize", "2048", "-validity", "2", "-dname", "CN=Disposable ChronoSpark validation"])
    apks = commands.evidence / "aab-derived-test-signed.apks"
    try:
        commands.run("derive-apks", bundle + ["build-apks", "--bundle=" + str(aab), "--output=" + str(apks),
                     "--mode=universal", "--ks=" + str(keystore), "--ks-key-alias=validation",
                     "--ks-pass=pass:android", "--key-pass=pass:android"], timeout=300)
    finally:
        keystore.unlink(missing_ok=True)
    apk = commands.evidence / "aab-derived-test-signed.apk"
    with zipfile.ZipFile(apks) as zipped:
        require(zipped.namelist().count("universal.apk") == 1, "Expected one derived universal APK")
        with zipped.open("universal.apk") as stream, apk.open("wb") as dest:
            shutil.copyfileobj(stream, dest)
    alignment = {}
    with zipfile.ZipFile(apk) as zipped, zipfile.ZipFile(aab) as original:
        require("lib/x86_64/libflutter.so" in zipped.namelist(), "AAB has no native x86_64 Flutter payload")
        for name in zipped.namelist():
            if re.fullmatch(r"lib/(x86_64|arm64-v8a)/[^/]+\.so", name):
                body = zipped.read(name)
                require(body == original.read("base/" + name), "Derived native bytes differ from the candidate AAB")
                alignment[name] = candidate_tools.elf_alignment(body)
    write_json(commands.evidence / "derived-native-alignment.json", alignment)
    build_tools = sdk / "build-tools/36.0.0"
    commands.run("derived-zipalign-16k", [str(build_tools / "zipalign"), "-c", "-P", "16", "-v", "4", str(apk)])
    signer = commands.run("derived-apk-signature", [str(build_tools / "apksigner"), "verify", "--verbose", "--print-certs", str(apk)])
    cert = re.search(r"Signer #1 certificate SHA-256 digest:\s*([a-fA-F0-9]{64})", signer)
    require(cert is not None and cert[1].lower() != candidate["uploadSignerSha256"].lower(),
            "Derived APK must identify its distinct disposable test signer")
    commands.run("derived-apk-licenses", ["python3", "scripts/verify_additional_licenses.py", "--artifact", str(apk),
                 "--repo-root", str(source), "--flutter-executable", shutil.which("flutter"),
                 "--report", str(commands.evidence / "derived-apk-licenses.json")], cwd=source)
    require(not commands.run("fresh-package-check", adb + ["shell", "pm", "path", PACKAGE], check=False),
            "Release validation requires a fresh empty emulator")
    commands.run("install-derived-release", adb + ["install", "--no-streaming", str(apk)], timeout=180)
    package = commands.run("installed-package", adb + ["shell", "dumpsys", "package", PACKAGE])
    require(re.search(r"versionCode=" + str(candidate["versionCode"]) + r"\b", package) and
            "versionName=" + candidate["versionName"] in package and "primaryCpuAbi=x86_64" in package,
            "Installed package version or native ABI mismatch")
    commands.run("clear-cold-launch-log", adb + ["logcat", "-c"])
    commands.run("force-stop-before-cold-launch", adb + ["shell", "am", "force-stop", PACKAGE])
    launch = commands.run("cold-launch", adb + ["shell", "am", "start", "-W", "-n", PACKAGE + "/.MainActivity"], timeout=90)
    require("Status: ok" in launch and "Error:" not in launch, "Release cold launch failed")
    for index in range(10):
        time.sleep(3)
        require(re.fullmatch(r"\d+(?: \d+)*", commands.run(f"process-alive-{index}", adb + ["shell", "pidof", PACKAGE])),
                "Release process died during cold-launch observation")
    activities = commands.run("resumed-activity", adb + ["shell", "dumpsys", "activity", "activities"])
    require(any(PACKAGE in line and re.search(r"(?:mResumedActivity|topResumedActivity)", line)
                for line in activities.splitlines()), "ChronoSpark is not the resumed foreground activity")
    log = commands.run("cold-launch-logcat", adb + ["logcat", "-d", "-v", "threadtime"], timeout=60)
    failures = fatal_lines(log)
    write_json(commands.evidence / "cold-launch-fatal-scan.json", {"fatalLines": failures, "passed": not failures})
    require(not failures, "Crash, ANR or Flutter error in the cold-launch observation window")
    with (commands.evidence / "cold-launch.png").open("wb") as stream:
        subprocess.run(adb + ["exec-out", "screencap", "-p"], stdout=stream, check=True, timeout=30)
    require((commands.evidence / "cold-launch.png").stat().st_size > 8, "Native screenshot is missing")
    commands.run("cold-launch-ui-dump", adb + ["shell", "uiautomator", "dump", "/sdcard/validation-window.xml"])
    commands.run("cold-launch-ui-pull", adb + ["pull", "/sdcard/validation-window.xml", str(commands.evidence / "cold-launch.xml")])
    verify_rendered_onboarding(commands.evidence / "cold-launch.xml")
    return {**candidate, "derivedApkSha256": digest(apk), "derivedApksSha256": digest(apks),
            "derivedSignerSha256": cert[1].lower(), "pageSize": 16384, "strict16KbCompatibilityDisabled": True,
            "coldLaunchObservationSeconds": 30, "renderedFreshOnboardingVerified": True,
            "boundary": "AAB-derived APK with disposable test signer; no Play signing, authentication, microphone, purchase or billing proof."}


def android(mode, source, tooling, evidence):
    commands = Commands(evidence)
    sdk = Path(os.environ["ANDROID_HOME"])
    adb = [str(sdk / "platform-tools/adb"), "-s", "emulator-5554"]
    bootstrap_manager = sdk / "cmdline-tools/latest/bin"
    image_id = ("system-images;android-36;google_atd;x86_64" if mode == "integration" else
                "system-images;android-37.1;google_apis_ps16k;x86_64")
    emulator = sdk / "emulator/emulator"
    require(os.access("/dev/kvm", os.R_OK | os.W_OK), "KVM is unavailable; software CPU fallback is forbidden")
    commands.run("install-pinned-command-line-tools", [str(bootstrap_manager / "sdkmanager"),
                  "cmdline-tools;22.0"], timeout=600, input_text="y\n" * 100)
    manager = sdk / "cmdline-tools/22.0/bin"
    commands.run("command-line-tools-version", [str(manager / "sdkmanager"), "--version"])
    commands.run("install-sdk-packages", [str(manager / "sdkmanager"), "platform-tools", "emulator",
                  "platforms;android-36", "build-tools;36.0.0", image_id], timeout=900, input_text="y\n" * 100)
    commands.run("emulator-version", [str(emulator), "-version"])
    acceleration = commands.run("acceleration-check", [str(emulator), "-accel-check"])
    require("KVM" in acceleration and "usable" in acceleration.lower(), "Usable KVM acceleration was not confirmed")
    properties = sdk / Path(*image_id.split(";")) / "source.properties"
    shutil.copy2(properties, commands.evidence / "image-source.properties")
    image_properties = dict(line.split("=", 1) for line in properties.read_text().splitlines() if "=" in line)
    require(image_properties.get("SystemImage.Abi") == "x86_64", "Unexpected SDK image ABI")
    if mode == "16kb":
        require(image_properties.get("AndroidVersion.ApiLevel") == "37.1" and
                image_properties.get("Pkg.Revision") == "9" and
                "page_size_16kb" in image_properties.get("SystemImage.TagId", ""),
                "Expected API37.1 revision9 16KB image is unavailable")
    else:
        require(image_properties.get("AndroidVersion.ApiLevel") == "36" and
                image_properties.get("Pkg.Revision") == "1" and
                image_properties.get("SystemImage.TagId") == "google_atd",
                "Expected API36 revision1 ATD image is unavailable")
    owned = Path(os.environ["RUNNER_TEMP"]) / ("chronospark-" + mode)
    owned.mkdir(exist_ok=False)
    os.environ["ANDROID_AVD_HOME"] = str(owned / "avd")
    os.environ["ANDROID_USER_HOME"] = str(owned / "user")
    os.environ["ANDROID_EMULATOR_HOME"] = str(owned / "user")
    Path(os.environ["ANDROID_AVD_HOME"]).mkdir()
    Path(os.environ["ANDROID_USER_HOME"]).mkdir()
    avd_name = "ChronoSpark_Final_" + mode
    avd_path = Path(os.environ["ANDROID_AVD_HOME"]) / (avd_name + ".avd")
    commands.run("create-owned-avd", [str(manager / "avdmanager"), "create", "avd", "--name", avd_name,
                  "--package", image_id, "--path", str(avd_path)], input_text="no\n")
    settings = configure_avd(avd_path / "config.ini")
    launch = [str(emulator), "-avd", avd_name, "-port", "5554", "-no-window", "-no-audio",
              "-no-snapshot", "-no-boot-anim", "-accel", "on", "-gpu", "swiftshader", "-memory", "2048", "-cores", "2"]
    write_json(commands.evidence / "emulator-launch.json", {"argv": launch, "settings": settings,
               "image": image_id, "imagePropertiesSha256": digest(properties), "ownedDirectory": str(owned)})
    process = None
    result = {"passed": False, "mode": mode}
    try:
        with (commands.evidence / "emulator.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen(launch, stdout=log, stderr=subprocess.STDOUT)
            commands.run("wait-for-device", adb + ["wait-for-device"], timeout=120)
            deadline = time.monotonic() + 360
            while True:
                require(process.poll() is None, "Owned emulator exited before boot completed")
                boot = commands.run("boot-completion", adb + ["shell", "getprop", "sys.boot_completed"], timeout=15)
                if boot == "1":
                    break
                require(time.monotonic() < deadline, "Owned emulator boot timed out")
                time.sleep(3)
            props = commands.run("guest-properties", adb + ["shell", "getprop"])
            require(commands.run("guest-primary-abi", adb + ["shell", "getprop", "ro.product.cpu.abi"]) == "x86_64",
                    "Guest primary x86_64 ABI missing")
            if mode == "integration":
                require(commands.run("guest-integration-sdk", adb + ["shell", "getprop", "ro.build.version.sdk"]) == "36",
                        "Integration guest is not API36")
            for key in ("window_animation_scale", "transition_animation_scale", "animator_duration_scale"):
                commands.run("disable-" + key, adb + ["shell", "settings", "put", "global", key, "0"])
            commands.run("set-density", adb + ["shell", "wm", "density", "160"])
            commands.run("dismiss-keyguard", adb + ["shell", "wm", "dismiss-keyguard"])
            result.update(integration(commands, source, adb) if mode == "integration" else
                          release_16kb(commands, source, tooling, adb, sdk))
            result["passed"] = True
    finally:
        if process is not None:
            try:
                commands.run("final-logcat", adb + ["logcat", "-d", "-v", "threadtime"], timeout=30, check=False)
                with (commands.evidence / "final-native-screen.png").open("wb") as stream:
                    subprocess.run(adb + ["exec-out", "screencap", "-p"], stdout=stream,
                                   stderr=subprocess.DEVNULL, timeout=20, check=False)
                commands.run("stop-owned-emulator", adb + ["emu", "kill"], timeout=20, check=False)
            except Exception as error:
                result["cleanupCaptureError"] = type(error).__name__
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)
            remaining = []
            for entry in Path("/proc").iterdir():
                if not entry.name.isdigit():
                    continue
                try:
                    argv = (entry / "cmdline").read_bytes().split(b"\0")
                except (OSError, PermissionError):
                    continue
                if b"-avd" in argv and avd_name.encode() in argv:
                    remaining.append(int(entry.name))
            try:
                commands.run("owned-adb-after-stop", adb + ["get-state"], timeout=10, check=False)
                adb_stopped = commands.records[-1]["exitCode"] != 0
            except RuntimeError:
                adb_stopped = False
            result["remainingOwnedEmulatorPids"] = remaining
            result["ownedEmulatorStopped"] = process.poll() is not None and not remaining and adb_stopped
            if not result["ownedEmulatorStopped"]:
                result["passed"] = False
        write_json(commands.evidence / "android-result.json", result)
        require(result.get("ownedEmulatorStopped", process is None), "Owned emulator shutdown was not confirmed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("candidate", "source", "integration", "16kb", "terminal"))
    parser.add_argument("--source", type=Path, default=Path("source"))
    parser.add_argument("--tooling", type=Path, default=Path("tooling"))
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    if args.mode == "candidate":
        receipt = verify_candidate(Path(os.environ["CANDIDATE_ZIP"]), read_json(os.environ["CANDIDATE_RUN_JSON"]),
                                   read_json(os.environ["CANDIDATE_ARTIFACT_JSON"]), os.environ["SOURCE_SHA"],
                                   os.environ["CANDIDATE_RUN"], os.environ["GITHUB_REPOSITORY"])
        write_json(args.evidence / "candidate-provenance.json", receipt)
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                for name, value in {"aab_sha": receipt["aabSha256"], "artifact_id": receipt["candidateArtifactId"],
                                    "artifact_sha": receipt["candidateArtifactSha256"],
                                    "candidate_tooling_sha": receipt["candidateToolingSha"]}.items():
                    output.write(f"{name}={value}\n")
    elif args.mode == "source":
        source_receipt(args.source.resolve(), args.tooling.resolve(), args.evidence)
    elif args.mode == "terminal":
        write_json(args.evidence / "verified-terminal.json", verify_terminal(args.manifest))
    else:
        android(args.mode, args.source.resolve(), args.tooling.resolve(), args.evidence)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Final validation failed: {type(error).__name__}: {error}", file=sys.stderr)
        raise SystemExit(1)
