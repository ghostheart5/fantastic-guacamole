"""Disposable hosted validation; never publishes or accesses production secrets."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import struct
import subprocess
import sys
import time
import zipfile
import xml.etree.ElementTree as ET
import zlib

import android_candidate_build as candidate_tools
from owned_adb_server import OwnedAdbServer

PACKAGE = "com.ghostheart5.chronospark"
BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
MAESTRO_SHA256 = "29b675e10cc12080e445e9bfb2e2b4e4dfb9c0f2e30d5884120d258b5e1cd991"
SOURCE_FILES = (
    "app_startup_test.dart", "auth_flow_integration_test.dart",
    "persistence_recovery_test.dart", "planner_learning_identity_test.dart",
)
INTEGRATION_CASES = (
    ("app_startup_test.dart", "320x640", 1),
    ("auth_flow_integration_test.dart", "320x640", 6),
    ("persistence_recovery_test.dart", "320x640", 1),
    ("planner_learning_identity_test.dart", "320x640", 1),
    ("auth_flow_integration_test.dart", "411x891", 6),
)
REVIEWED_TEST_REPAIR_BASE = "66d5a8dafb718b712f58f9fa8d9a74e692bd5bf1"
REVIEWED_TEST_REPAIR_PATHS = frozenset((
    "check_architecture.ps1",
    "test/architecture/repository_ownership_checker_test.dart",
    "test/release/maestro_android_runner_fixture_test.dart",
    ".maestro/subflows/reveal-creator-review.yaml",
))


def validate_test_only_delta(raw, base, target):
    require(base == REVIEWED_TEST_REPAIR_BASE and
            re.fullmatch(r"[a-f0-9]{40}", target or "") and target != base,
            "Unreviewed test repair base or validation SHA")
    fields = raw.split("\0")
    require(fields[-1] == "" and len(fields) > 1 and len(fields) % 2 == 1,
            "Malformed or empty test repair diff")
    entries = []
    for index in range(0, len(fields) - 1, 2):
        header, path = fields[index:index + 2]
        match = re.fullmatch(r":(100644) (100644) ([a-f0-9]{40}) ([a-f0-9]{40}) M", header)
        require(match and path in REVIEWED_TEST_REPAIR_PATHS,
                "Unreviewed path, file type, rename, deletion or mode change in test repair")
        entries.append({"path": path, "beforeBlob": match[3], "afterBlob": match[4],
                        "beforeMode": match[1], "afterMode": match[2]})
    require(len(entries) == len(REVIEWED_TEST_REPAIR_PATHS) and
            {entry["path"] for entry in entries} == REVIEWED_TEST_REPAIR_PATHS,
            "The complete reviewed four-file test repair is required")
    return entries


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
                  "timeoutSeconds": timeout, "exitCode": None, "timedOut": False, "launchFailed": False}
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
        except OSError as error:
            record["launchFailed"] = True
            log.write_text(type(error).__name__ + ": command could not be launched\n", encoding="utf-8")
            raise RuntimeError(f"Command could not be launched: {label}") from error
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
    candidate_source = os.environ["SOURCE_SHA"]
    validation_source = os.environ.get("VALIDATION_SOURCE_SHA") or candidate_source
    require(actual == validation_source and tooling_sha == os.environ["GITHUB_SHA"],
            "Source or validation tooling checkout mismatch")
    require(not commands.run("tracked-status", ["git", "status", "--porcelain", "--untracked-files=no"], cwd=source),
            "Tracked source is dirty")
    test_delta = None
    if actual != candidate_source:
        require(os.environ.get("WINDOWS_ONLY") == "true", "Test repair source is restricted to Windows-only validation")
        commands.run("candidate-is-ancestor", ["git", "merge-base", "--is-ancestor", candidate_source, actual], cwd=source)
        raw = commands.run("complete-test-repair-diff", ["git", "diff", "--raw", "-z", "--abbrev=40",
                           "--no-renames", candidate_source, actual, "--"], cwd=source)
        test_delta = validate_test_only_delta(raw, candidate_source, actual)
        commands.run("complete-test-repair-patch", ["git", "diff", "--binary", "--no-renames",
                     candidate_source, actual, "--"], cwd=source)
        for entry in test_delta:
            entry["workingFileSha256"] = digest(source / entry["path"])
        write_json(Path(evidence) / "reviewed-test-only-delta.json", {
            "candidateSourceSha": candidate_source, "validationSourceSha": actual,
            "entries": test_delta, "allOtherTrackedPathsAndModesUnchanged": True,
            "boundary": "Clean newer tests; unchanged complete product and build tree. Not an exact candidate-source test run."})
    result = {"sourceSha": actual, "candidateSourceSha": candidate_source,
              "validationSourceSha": actual, "reviewedTestOnlyDelta": test_delta,
              "validationToolingSha": tooling_sha,
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


def verify_emulator_library_listing(listing):
    require("libc.so" in listing and not re.search(r"=>\s*not found\b", listing),
            "Emulator dynamic-library preflight is incomplete or has unresolved libraries")


def verify_png(data):
    require(data.startswith(b"\x89PNG\r\n\x1a\n"), "Screenshot is not a PNG")
    offset, dimensions, image_data, ended = 8, None, False, False
    while offset + 12 <= len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        require(offset + 12 + size <= len(data), "Screenshot PNG is truncated")
        payload = data[offset + 8:offset + 8 + size]
        crc = struct.unpack_from(">I", data, offset + 8 + size)[0]
        require(zlib.crc32(kind + payload) & 0xffffffff == crc, "Screenshot PNG CRC mismatch")
        if dimensions is None:
            require(kind == b"IHDR" and size == 13, "Screenshot PNG lacks its header")
            dimensions = struct.unpack_from(">II", payload)
            require(all(0 < value <= 4096 for value in dimensions), "Invalid screenshot dimensions")
        image_data |= kind == b"IDAT" and size > 0
        offset += 12 + size
        if kind == b"IEND":
            require(size == 0 and offset == len(data), "Invalid screenshot PNG ending")
            ended = True
            break
    require(ended and image_data, "Screenshot PNG has no complete image")
    return list(dimensions)


def capture_guest_png(commands, adb, label, viewport):
    path = commands.evidence / (label + ".png")
    record = {"argv": adb + ["exec-out", "screencap", "-p"], "exitCode": None,
              "timedOut": False, "launchFailed": False, "valid": False}
    try:
        with path.open("xb") as stream:
            result = subprocess.run(record["argv"], stdout=stream, stderr=subprocess.PIPE, timeout=20)
        record["exitCode"] = result.returncode
        (commands.evidence / (label + ".stderr.txt")).write_bytes(result.stderr)
        require(result.returncode == 0, "Screenshot command failed")
        record["dimensions"] = verify_png(path.read_bytes())
        require(record["dimensions"] == [int(value) for value in viewport.split("x")],
                "Screenshot dimensions do not match the required viewport")
        record["valid"] = True
    except subprocess.TimeoutExpired as error:
        record["timedOut"] = True
        (commands.evidence / (label + ".stderr.txt")).write_bytes(error.stderr or b"")
        raise RuntimeError("Screenshot command timed out") from error
    except OSError as error:
        record["launchFailed"] = True
        raise RuntimeError("Screenshot could not be captured") from error
    finally:
        record["bytes"] = path.stat().st_size if path.exists() else 0
        write_json(commands.evidence / (label + ".json"), record)
    return record


def guest_health(commands, adb, process, label):
    result = {"passed": False, "emulatorPid": process.pid, "deviceSerial": adb[-1]}
    try:
        require('-port' in process.args and '-avd' in process.args,
                "Owned emulator launch identity is missing")
        port = process.args[process.args.index('-port') + 1]
        avd = process.args[process.args.index('-avd') + 1]
        require(port in ('5554', '5586', '5588', '5590', '5592', '5594') and
                avd.startswith('ChronoSpark_Final_') and adb[-2:] == ['-s', 'emulator-' + port],
                "Health check targets an unowned device")
        require(process.poll() is None, "Owned emulator process exited")
        require(commands.run(label + "-state", adb + ["get-state"], timeout=15) == "device",
                "Owned device is not online")
        require(commands.run(label + "-boot", adb + ["shell", "getprop", "sys.boot_completed"], timeout=15) == "1",
                "Owned guest is not fully booted")
        require(commands.run(label + "-shell", adb + ["shell", "echo", "CHRONOSPARK_GUEST_READY"], timeout=15) ==
                "CHRONOSPARK_GUEST_READY", "Owned guest shell is not responsive")
        result["passed"] = True
    finally:
        write_json(commands.evidence / (label + ".json"), result)
    return result


def integration(commands, source, adb, process, case):
    filename, viewport, expected = case
    label = Path(filename).stem + "-" + viewport
    manifest = commands.evidence / (label + "-manifest.json")
    entry = {"file": filename, "viewport": viewport, "expectedTests": expected,
             "runnerExitCode": None, "passed": False, "failures": [],
             "debugTransport": "flutter-default-dds",
             "stateBoundary": "Fresh guest for this invocation; state is preserved across every test in this file."}
    collector = None
    begin, end = "CS_CASE_BEGIN_" + label, "CS_CASE_END_" + label
    log_path = commands.evidence / "continuous-logcat.log"
    stream = errors = None
    collector_receipt = {"started": False, "exitBeforeStop": None, "stopped": False}
    try:
        guest_health(commands, adb, process, "pre-test-health")
        commands.run("required-viewport", adb + ["shell", "wm", "size", viewport])
        capture_guest_png(commands, adb, "pre-test-screen", viewport)
        commands.run("clear-test-log", adb + ["logcat", "-c"], timeout=15)
        stream = log_path.open("xb")
        errors = (commands.evidence / "continuous-logcat.stderr.txt").open("xb")
        collector = subprocess.Popen(adb + ["logcat", "-v", "threadtime"], stdout=stream, stderr=errors)
        collector_receipt.update(started=True, pid=collector.pid)
        commands.run("begin-test-log", adb + ["shell", "log", "-t", "ChronoSparkValidation", begin], timeout=15)
        print(json.dumps({"event": "integration-start", "file": filename, "viewport": viewport,
                          "expectedTests": expected}), flush=True)
        commands.run(label, ["dart", "run", "tool/run_flutter_tests.dart", "--report",
                            str(commands.evidence / (label + ".jsonl")), "--manifest", str(manifest),
                            "--timeout-seconds", "900", "--", "integration_test/" + filename,
                            "--no-pub", "--concurrency=1", "-d", adb[-1]],
                     cwd=source, timeout=960, check=False)
        entry["runnerExitCode"] = commands.records[-1]["exitCode"]
        require(entry["runnerExitCode"] == 0, "Original canonical runner exited unsuccessfully")
        entry["totals"] = verify_terminal(manifest)
        require(entry["totals"]["total"] == expected, "Maintained native test count changed or tests were omitted")
    except (RuntimeError, OSError, ValueError) as error:
        entry["failures"].append(str(error))
    finally:
        # Capture immediately, even when Flutter failed. Never launch another
        # file on this guest or turn a capture failure into passing evidence.
        for name, capture in (
            ("post-test-health", lambda: guest_health(commands, adb, process, "post-test-health")),
            ("end-test-log", lambda: commands.run("end-test-log", adb + ["shell", "log", "-t",
                                                          "ChronoSparkValidation", end], timeout=15)),
            ("post-test-screen", lambda: capture_guest_png(commands, adb, "post-test-screen", viewport)),
        ):
            try:
                capture()
            except (RuntimeError, OSError, ValueError) as error:
                entry["failures"].append(name + ": " + str(error))
        if collector is not None:
            # The shell command returning does not guarantee that the separate
            # logcat stream has drained its final marker yet.
            drain_deadline = time.monotonic() + 2
            while collector.poll() is None and time.monotonic() < drain_deadline:
                try:
                    with log_path.open("rb") as captured:
                        captured.seek(max(0, log_path.stat().st_size - 65536))
                        if end.encode() in captured.read():
                            break
                except OSError as error:
                    entry["failures"].append("Log marker readback failed: " + type(error).__name__)
                    break
                time.sleep(0.05)
            collector_receipt["exitBeforeStop"] = collector.poll()
            try:
                if collector.poll() is None:
                    collector.terminate()
                    try:
                        collector.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        collector.kill()
                        collector.wait(timeout=5)
            except (OSError, subprocess.TimeoutExpired) as error:
                entry["failures"].append("Log collector cleanup failed: " + type(error).__name__)
            collector_receipt.update(stopped=collector.poll() is not None, finalExitCode=collector.returncode)
        if stream is not None:
            stream.close()
        if errors is not None:
            errors.close()
        write_json(commands.evidence / "continuous-logcat-result.json", collector_receipt)
        text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
        if (not collector_receipt["started"] or collector_receipt["exitBeforeStop"] is not None or
                not collector_receipt["stopped"] or begin not in text or end not in text):
            entry["failures"].append("Continuous logcat did not cover the complete invocation")
        # Flutter intentionally installs/stops each test application. Preserve
        # plain process lifecycle events separately; fatal/ANR/error signatures
        # remain fatal regardless of whether tests otherwise passed.
        lifecycle = [line for line in text.splitlines() if re.search(
            r"Process\s+" + re.escape(PACKAGE) + r"\s+has died|Force stopping\s+" + re.escape(PACKAGE), line)]
        fatal = fatal_lines(text, include_process_exit=False)
        entry["ownedLogCollectorStopped"] = collector is None or collector_receipt["stopped"]
        entry["runtimeEvidence"] = {"fatalLines": fatal, "processLifecycleLines": lifecycle,
                                    "lifecycleBoundary": "Installation and Flutter runner teardown included; plain lifecycle lines retained for review."}
        if fatal:
            entry["failures"].append("Native fatal or Flutter error evidence was captured")
        entry["passed"] = not entry["failures"] and entry.get("totals", {}).get("total") == expected
        write_json(commands.evidence / "integration-case-result.json", entry)
        print(json.dumps({"event": "integration-finished", "file": filename, "viewport": viewport,
                          "passed": entry["passed"], "runnerExitCode": entry["runnerExitCode"],
                          "totals": entry.get("totals"), "failures": entry["failures"]}), flush=True)
    return entry


def fatal_lines(log, package=PACKAGE, *, include_process_exit=True):
    patterns = [r"FATAL EXCEPTION", r"Fatal signal \d+", r"(?:E/flutter|\bE\s+flutter\s*:).*(?:Unhandled Exception|\[ERROR)",
                r"MissingPluginException", r"Failed assertion", r"ANR in\s+" + re.escape(package)]
    if include_process_exit:
        patterns.append(r"Process\s+" + re.escape(package) + r"\s+has died")
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


def verify_one_maestro_case(path):
    root = ET.parse(path).getroot()
    require(root.tag in ("testsuite", "testsuites"), "Unexpected Maestro JUnit root")
    cases = list(root.iter("testcase"))
    require(len(cases) == 1, "Standalone onboarding requires exactly one completed Maestro testcase")
    require(not any(node.tag in ("failure", "error", "skipped") for node in root.iter()),
            "Standalone onboarding has a failed, errored or skipped testcase")
    require(cases[0].get("status", "").casefold() in ("", "passed", "run", "success", "completed"),
            "Standalone onboarding testcase status does not indicate execution")
    for suite in root.iter():
        if suite.tag not in ("testsuite", "testsuites"):
            continue
        expected = {"tests": len(list(suite.iter("testcase"))), "failures": 0, "errors": 0, "skipped": 0}
        for name, count in expected.items():
            if name in suite.attrib:
                require(re.fullmatch(r"\d+", suite.attrib[name]) and int(suite.attrib[name]) == count,
                        "Maestro JUnit counters disagree with the actual completed case")
    return {"testCases": 1, "passed": 1, "failures": 0, "errors": 0, "skipped": 0,
            "name": cases[0].get("name", "")}


def verify_rendered_login(path):
    nodes = list(ET.parse(path).iter("node"))
    text = "\n".join(node.get("text", "") + "\n" + node.get("content-desc", "") + "\n" +
                     node.get("resource-id", "") for node in nodes).upper()
    require("ENTER SYSTEM" in text and ("EMAIL ADDRESS" in text or "LOGIN-EMAIL-FIELD" in text) and
            "PASSWORD" in text and "CONTINUE TO LOGIN" not in text,
            "Native login handoff did not render its email/password form")


def standalone_onboarding(commands, source, adb):
    require(adb[-2:] == ["-s", "emulator-5554"], "Onboarding data reset requires this job's owned emulator")
    maestro = shutil.which("maestro")
    require(maestro is not None, "Checksum-pinned Maestro was not installed")
    flow = source / ".maestro/flows/03-onboarding-tutorial.yaml"
    junit = commands.evidence / "standalone-onboarding-junit.xml"
    require(flow.is_file() and not junit.exists(), "Standalone flow or fresh JUnit destination is invalid")
    receipt = {"passed": False, "flow": str(flow.relative_to(source)), "flowSha256": digest(flow),
               "maestroVersion": "2.10.0", "maestroArchiveSha256": MAESTRO_SHA256,
               "deviceSerial": "emulator-5554", "timeoutSeconds": 180,
               "clearStateBoundary": "Only the owned fresh AAB-derived emulator installation; no account login.",
               "originalMaestroExitCode": None}
    try:
        version = commands.run("onboarding-maestro-version", [maestro, "--version"], timeout=60)
        require(re.search(r"\b2\.10\.0\b", version), "Unexpected Maestro runtime version")
        commands.run("stop-app-before-onboarding-reset", adb + ["shell", "am", "force-stop", PACKAGE])
        require(not commands.run("verify-app-stopped-before-onboarding-reset",
                adb + ["shell", "pidof", PACKAGE], check=False),
                "App remained running before the owned onboarding reset")
        commands.run("clear-onboarding-flow-log", adb + ["logcat", "-c"])
        commands.run("standalone-onboarding-maestro", [maestro, "test", "--udid", "emulator-5554",
                     "--no-ansi", "--format", "JUNIT", "--output", str(junit), "--debug-output",
                     str(commands.evidence / "onboarding-maestro-debug"), "--test-output-dir",
                     str(commands.evidence / "onboarding-maestro-artifacts"), "--test-suite-name",
                     "ChronoSpark signed-artifact onboarding", str(flow)], cwd=source, timeout=180, check=False)
        receipt["originalMaestroExitCode"] = commands.records[-1]["exitCode"]
        during = commands.run("onboarding-flow-logcat", adb + ["logcat", "-d", "-v", "threadtime"], timeout=60)
        # The app was already stopped before this log window. The immutable
        # flow's clearState therefore needs no process-death scan exception.
        during_failures = fatal_lines(during)
        receipt["duringFlowFatalScan"] = {"failures": during_failures}
        require(receipt["originalMaestroExitCode"] == 0, "Standalone onboarding Maestro command failed")
        receipt["junit"] = verify_one_maestro_case(junit)
        require(not during_failures, "Crash/ANR/Flutter error during standalone onboarding")
        require(digest(flow) == receipt["flowSha256"], "Immutable onboarding flow changed during execution")
        commands.run("clear-post-onboarding-log", adb + ["logcat", "-c"])
        for index in range(5):
            time.sleep(3)
            require(re.fullmatch(r"\d+(?: \d+)*", commands.run(f"post-onboarding-process-{index}",
                    adb + ["shell", "pidof", PACKAGE])), "App died after onboarding login handoff")
        activities = commands.run("post-onboarding-activity", adb + ["shell", "dumpsys", "activity", "activities"])
        require(any(PACKAGE in line and re.search(r"(?:mResumedActivity|topResumedActivity)", line)
                    for line in activities.splitlines()), "Login handoff lost the foreground app")
        commands.run("post-onboarding-ui-dump", adb + ["shell", "uiautomator", "dump", "/sdcard/onboarding-handoff.xml"])
        xml = commands.evidence / "onboarding-login-handoff.xml"
        commands.run("post-onboarding-ui-pull", adb + ["pull", "/sdcard/onboarding-handoff.xml", str(xml)])
        verify_rendered_login(xml)
        screenshot = commands.evidence / "onboarding-login-handoff.png"
        with screenshot.open("wb") as stream:
            subprocess.run(adb + ["exec-out", "screencap", "-p"], stdout=stream, check=True, timeout=30)
        require(screenshot.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), "Login handoff screenshot is invalid")
        after = commands.run("post-onboarding-logcat", adb + ["logcat", "-d", "-v", "threadtime"], timeout=60)
        failures = fatal_lines(after)
        receipt["postFlowFatalScan"] = {"observationSeconds": 15, "fatalLines": failures,
                                        "processExitExceptions": False}
        require(not failures, "Runtime error after standalone onboarding login handoff")
        receipt.update(passed=True, renderedLoginHandoffVerified=True)
        return receipt
    finally:
        attempts = [item for item in commands.records if item["label"] == "standalone-onboarding-maestro"]
        if attempts:
            receipt["originalMaestroExitCode"] = attempts[-1].get("exitCode")
            receipt["maestroTimedOut"] = attempts[-1].get("timedOut", False)
            receipt["maestroLaunchFailed"] = attempts[-1].get("launchFailed", False)
        write_json(commands.evidence / "standalone-onboarding-result.json", receipt)


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
    onboarding = standalone_onboarding(commands, source, adb)
    return {**candidate, "derivedApkSha256": digest(apk), "derivedApksSha256": digest(apks),
            "derivedSignerSha256": cert[1].lower(), "pageSize": 16384, "strict16KbCompatibilityDisabled": True,
            "coldLaunchObservationSeconds": 30, "renderedFreshOnboardingVerified": True,
            "standaloneOnboarding": onboarding,
            "boundary": "AAB-derived APK with disposable test signer; no Play signing, authentication, microphone, purchase or billing proof."}


def execute_integration_cases(commands, source, launch_case):
    require({path.name for path in (source / "integration_test").glob("*_test.dart")} == set(SOURCE_FILES),
            "Maintained native test inventory changed; review this runner")
    results = []
    summary = {"passed": False, "mode": "integration", "expectedInvocations": 5, "expectedTests": 15,
               "boundary": "Five fresh guests, one independent file/viewport per guest; no retries or within-file state clearing. Test fakes, not signed release or Play Billing."}
    try:
        for index, case in enumerate(INTEGRATION_CASES, 1):
            label = f"{index:02d}-" + Path(case[0]).stem + "-" + case[1]
            guest_commands = Commands(commands.evidence / label)
            result = launch_case(case, index, guest_commands)
            results.append({"file": case[0], "viewport": case[1], "expectedTests": case[2],
                            "evidenceDirectory": label, **result})
            write_json(commands.evidence / "integration-results.json", results)
            require(result.get("ownedEmulatorStopped") is True and
                    result.get("ownedLogCollectorStopped") is True and
                    result.get("ownedAdbServerStopped") is True,
                    "Prior owned guest/collector cleanup was not proved; no further guest may start")
        summary["passed"] = all(result["passed"] for result in results)
        require(summary["passed"], "One or more fresh-guest integration invocations failed")
    finally:
        summary.update(runs=results, completedInvocations=len(results),
                       notRun=[{"file": case[0], "viewport": case[1]} for case in INTEGRATION_CASES[len(results):]],
                       ownedEmulatorStopped=bool(results) and all(result.get("ownedEmulatorStopped") for result in results))
        write_json(commands.evidence / "android-result.json", summary)
    return summary


NATIVE_EMULATOR_URL = 'https://dl.google.com/android/repository/emulator-linux_x64-15507667.zip'
NATIVE_EMULATOR_SHA256 = '1eade4cf2df6ea8eeead4902c635897ba12aaa32aac4389eaae0fdb498a5b830'


def install_native_emulator(commands):
    # Keep the SDK and strict-16KB runtime intact. This pin is only for API36
    # integration guests; verify Google's published archive before extraction.
    root = Path(os.environ['RUNNER_TEMP']) / 'chronospark-native-emulator-36.6.11'
    root.mkdir(exist_ok=False)
    archive = root / 'emulator.zip'
    commands.run('download-pinned-native-emulator', ['curl', '--fail', '--location', '--silent',
                 '--show-error', NATIVE_EMULATOR_URL, '--output', str(archive)], timeout=600)
    actual = digest(archive)
    require(actual == NATIVE_EMULATOR_SHA256, 'Native emulator archive checksum mismatch')
    commands.run('extract-pinned-native-emulator', ['unzip', '-q', str(archive), '-d', str(root)], timeout=120)
    emulator = root / 'emulator/emulator'
    version = commands.run('pinned-native-emulator-version', [str(emulator), '-version'])
    require('36.6.11.0' in version and '15507667' in version, 'Unexpected pinned emulator version')
    write_json(commands.evidence / 'native-emulator-pin.json', {
        'passed': True, 'url': NATIVE_EMULATOR_URL, 'sha256': actual,
        'version': version, 'executable': str(emulator), 'sdkEmulatorChanged': False})
    return emulator


def android(mode, source, tooling, evidence):
    commands = Commands(evidence)
    sdk = Path(os.environ["ANDROID_HOME"])
    adb = [str(sdk / "platform-tools/adb"), "-s", "emulator-5554"]
    bootstrap_manager = sdk / "cmdline-tools/latest/bin"
    image_id = ("system-images;android-36;google_apis;x86_64" if mode == "integration" else
                "system-images;android-37.1;google_apis_ps16k;x86_64")
    emulator = sdk / "emulator/emulator"
    require(os.access("/dev/kvm", os.R_OK | os.W_OK), "KVM is unavailable; software CPU fallback is forbidden")
    commands.run("install-pinned-command-line-tools", [str(bootstrap_manager / "sdkmanager"),
                  "cmdline-tools;22.0"], timeout=600, input_text="y\n" * 100)
    manager = sdk / "cmdline-tools/22.0/bin"
    commands.run("command-line-tools-version", [str(manager / "sdkmanager"), "--version"])
    commands.run("install-sdk-packages", [str(manager / "sdkmanager"), "platform-tools", "emulator",
                  "platforms;android-36", "build-tools;36.0.0", image_id], timeout=900, input_text="y\n" * 100)
    if mode == 'integration':
        emulator = install_native_emulator(commands)
    library_root = emulator.parent / 'lib64'
    library_path = os.pathsep.join(str(path) for path in
                                  (library_root, library_root / "qt/lib", library_root / "gles_swiftshader"))
    libraries = commands.run("emulator-dynamic-libraries", ["env", "LD_LIBRARY_PATH=" + library_path,
                             "ldd", str(emulator.parent / 'qemu/linux-x86_64/qemu-system-x86_64')])
    verify_emulator_library_listing(libraries)
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
                image_properties.get("Pkg.Revision") == "7" and
                image_properties.get("SystemImage.TagId") == "google_apis",
                "Expected API36 revision7 Google APIs image is unavailable")
    if mode == "integration":
        # Keep the host ADB identity stable while replacing guest userdata.
        # This directory is new for this job and never contains app state.
        shared_user_home = Path(os.environ["RUNNER_TEMP"]) / "chronospark-integration-host-user"
        shared_user_home.mkdir(exist_ok=False)
        def launch_case(case, ordinal, guest_commands):
            return owned_android_guest(mode, source, tooling, guest_commands, sdk, manager,
                                       emulator, image_id, properties, case=case, ordinal=ordinal,
                                       shared_user_home=shared_user_home)
        return execute_integration_cases(commands, source, launch_case)
    result = owned_android_guest(mode, source, tooling, commands, sdk, manager, emulator, image_id, properties)
    require(result["passed"], "Owned Android validation failed; see its retained result")
    return result


def prepare_native_build(commands, source):
    target = source / 'integration_test/app_startup_test.dart'
    require(target.is_file(), 'Maintained startup integration target is missing')
    receipt = {'passed': False, 'applicationTestsExecuted': 0, 'emulatorsStarted': 0,
               'boundary': 'Compile-only preparation before any guest boots; canonical test invocations still build and execute normally.'}
    try:
        commands.run('compile-native-dependencies', ['flutter', 'build', 'apk', '--debug', '--no-pub',
                     '--target-platform', 'android-x64', '--target', 'integration_test/app_startup_test.dart'],
                     cwd=source, timeout=1200)
        apk = source / 'build/app/outputs/flutter-apk/app-debug.apk'
        require(apk.is_file() and zipfile.is_zipfile(apk), 'Compile-only preparation did not produce an APK')
        receipt.update(passed=True, apkSha256=digest(apk), apkBytes=apk.stat().st_size)
        return receipt
    finally:
        write_json(commands.evidence / 'native-build-preparation.json', receipt)


def prepare_integration_kvm(commands, emulator):
    # A named-user ACL granted once at job setup was no longer effective for
    # later fresh guests. Reassert only that same ACL at each launch boundary.
    device = Path("/dev/kvm")
    receipt = {"passed": False, "device": str(device), "softwareFallbackAllowed": False}
    def snapshot():
        info = device.lstat()
        require(stat.S_ISCHR(info.st_mode), "KVM path is not a character device")
        return {"deviceId": info.st_dev, "inode": info.st_ino, "rdev": info.st_rdev,
                "mode": stat.S_IMODE(info.st_mode), "ownerUid": info.st_uid,
                "ownerGid": info.st_gid, "readWriteAccessible": os.access(device, os.R_OK | os.W_OK)}
    try:
        receipt["runnerUid"] = os.getuid()
        receipt["before"] = snapshot()
        commands.run("kvm-acl-before", ["getfacl", "--absolute-names", "--numeric", str(device)], timeout=15)
        commands.run("restore-current-user-kvm-acl", ["sudo", "-n", "setfacl", "-m",
                     f"u:{receipt['runnerUid']}:rw", str(device)], timeout=15)
        receipt["after"] = snapshot()
        commands.run("kvm-acl-after", ["getfacl", "--absolute-names", "--numeric", str(device)], timeout=15)
        receipt["deviceIdentityChangedDuringPreparation"] = any(
            receipt["before"][key] != receipt["after"][key] for key in ("deviceId", "inode", "rdev"))
        require(receipt["after"]["readWriteAccessible"], "KVM remains inaccessible after current-user ACL repair")
        descriptor = os.open(device, os.O_RDWR | os.O_CLOEXEC)
        try:
            opened = os.fstat(descriptor)
            require((opened.st_dev, opened.st_ino, opened.st_rdev) ==
                    tuple(receipt["after"][key] for key in ("deviceId", "inode", "rdev")),
                    "KVM device changed between permission readback and open")
            receipt["readWriteOpenSucceeded"] = True
        finally:
            os.close(descriptor)
        acceleration = commands.run("guest-acceleration-check", [str(emulator), "-accel-check"], timeout=30)
        require(re.search(r"(?m)^KVM[^\r\n]*\bis installed and usable\.[ \t]*$", acceleration),
                "Usable KVM acceleration was not confirmed for this fresh guest")
        receipt["passed"] = True
        return receipt
    except Exception as error:
        receipt["failure"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        write_json(commands.evidence / "kvm-preparation.json", receipt)


def owned_android_guest(mode, source, tooling, commands, sdk, manager, emulator, image_id, properties,
                        *, case=None, ordinal=None, shared_user_home=None):
    suffix = mode + (f"-{ordinal:02d}" if ordinal is not None else "")
    owned = Path(os.environ["RUNNER_TEMP"]) / ("chronospark-" + suffix)
    owned.mkdir(exist_ok=False)
    os.environ["ANDROID_AVD_HOME"] = str(owned / "avd")
    user_home = shared_user_home if shared_user_home is not None else owned / "user"
    os.environ["ANDROID_USER_HOME"] = str(user_home)
    os.environ["ANDROID_EMULATOR_HOME"] = str(user_home)
    Path(os.environ["ANDROID_AVD_HOME"]).mkdir()
    if shared_user_home is None:
        user_home.mkdir()
    avd_name = "ChronoSpark_Final_" + suffix.replace("-", "_")
    avd_path = Path(os.environ["ANDROID_AVD_HOME"]) / (avd_name + ".avd")
    commands.run("create-owned-avd", [str(manager / "avdmanager"), "create", "avd", "--name", avd_name,
                  "--package", image_id, "--path", str(avd_path)], input_text="no\n")
    settings = configure_avd(avd_path / "config.ini")
    # Fresh integration ports are outside the default ADB emulator scan range.
    # This prevents another server from rediscovering and replacing our transport.
    emulator_port = str(5584 + 2 * (ordinal or 1)) if mode == "integration" else "5554"
    launch = [str(emulator), "-avd", avd_name, "-port", emulator_port, "-no-window", "-no-audio",
              "-no-snapshot", "-no-boot-anim", "-accel", "on", "-gpu", "swiftshader", "-memory", "2048", "-cores", "2"]
    if mode == 'integration':
        launch.append('-show-kernel')
    write_json(commands.evidence / "emulator-launch.json", {"argv": launch, "settings": settings,
               "image": image_id, "imagePropertiesSha256": digest(properties), "ownedDirectory": str(owned),
               "ownedHostUserDirectory": str(user_home), "freshGuestData": True})
    adb = [str(sdk / "platform-tools/adb"), "-s", "emulator-" + emulator_port]
    process = None
    adb_server = None
    result = {"passed": False, "mode": mode, "ownedEmulatorStopped": False,
              "ownedLogCollectorStopped": True, "ownedAdbServerStopped": True}
    try:
        if mode == "integration":
            result["kvmPreparation"] = prepare_integration_kvm(commands, emulator)
            adb_server = OwnedAdbServer(sdk / "platform-tools/adb", commands.evidence, 55000 + (ordinal or 0))
            adb_server.start()
            result["ownedAdbServerStopped"] = False
            commands.run("owned-adb-version", [str(sdk / "platform-tools/adb"), "version"])
            commands.run("owned-adb-status", [str(sdk / "platform-tools/adb"), "server-status"])
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
            if mode == "integration":
                adb_server.assert_alive()
                result["integrationInvoked"] = True
                result["ownedLogCollectorStopped"] = False
                result.update(integration(commands, source, adb, process, case))
                adb_server.assert_alive()
            else:
                result.update(release_16kb(commands, source, tooling, adb, sdk))
                result["passed"] = True
    except Exception as error:
        result.update(passed=False, failure=f"{type(error).__name__}: {error}")
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
        if result.get("integrationInvoked"):
            collector_file = commands.evidence / "continuous-logcat-result.json"
            try:
                collector = read_json(collector_file)
                result["ownedLogCollectorStopped"] = (collector.get("started") is False or
                                                       collector.get("stopped") is True)
            except (OSError, ValueError):
                result["ownedLogCollectorStopped"] = False
            if not result["ownedLogCollectorStopped"]:
                result["passed"] = False
        if adb_server is not None:
            try:
                adb_server.stop()
                result["ownedAdbServerStopped"] = adb_server.receipt["stopped"]
                result["ownedAdbServerContinuous"] = not adb_server.receipt["unexpectedServerExit"]
                if not result["ownedAdbServerStopped"] or not result["ownedAdbServerContinuous"]:
                    result["passed"] = False
            except Exception as error:
                result.update(passed=False, ownedAdbServerStopped=False,
                              adbCleanupError=f"{type(error).__name__}: {error}")
        write_json(commands.evidence / "android-result.json", result)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("candidate", "source", "prepare", "integration", "16kb", "terminal"))
    parser.add_argument("--source", type=Path, default=Path("source"))
    parser.add_argument("--tooling", type=Path, default=Path("tooling"))
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    if args.mode == 'prepare':
        prepare_native_build(Commands(args.evidence), args.source)
        return
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
