"""Bounded, source-bound 16 KiB QA probe without a third-party device agent."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

SERIAL = "emulator-5554"
PACKAGE = "com.ghostheart5.chronospark"
ACTIVITY = f"{PACKAGE}/.MainActivity"
ROOT = Path("test-results/native-16k-ci")
APK = Path("build/app/outputs/flutter-apk/app-debug.apk")
UI_MARKERS = (
    "CONTINUE TO LOGIN",
    "START LOGIN",
    "SKIP FOR NOW",
    "TESTER ACCESS",
    "ENTER SYSTEM",
    "NEXUS",
)


def run(*args: str, timeout: int = 30, binary: bool = False) -> str | bytes:
    completed = subprocess.run(
        ["adb", "-s", SERIAL, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=True,
    )
    return completed.stdout if binary else completed.stdout.decode("utf-8", "replace")


def shell(*args: str, timeout: int = 30) -> str:
    return str(run("shell", *args, timeout=timeout)).strip()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_version_code(pubspec: Path = Path("pubspec.yaml"),
                        gradle: Path = Path("android/gradle.properties")) -> str:
    """Bind the installed QA package to the selected source's version guards."""
    published = re.search(r"(?m)^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$", pubspec.read_text())
    android = re.search(r"(?m)^CHRONOSPARK_VERSION_CODE=(\d+)\s*$", gradle.read_text())
    assert published and android and published.group(1) == android.group(1)
    return published.group(1)


def focused_window(input_dump: str) -> str:
    """Read display 0's actual input focus, excluding stale window records."""
    focused: set[str] = set()
    in_windows = False
    for line in input_dump.splitlines():
        if line.strip() == "FocusedWindows:":
            in_windows = True
            continue
        if in_windows and line.startswith("  ") and not line.startswith("    "):
            in_windows = False
        if in_windows:
            match = re.fullmatch(r"\s*displayId=0, name='([^']+)'\s*", line)
            if match:
                focused.add(match.group(1))
    return next(iter(focused)) if len(focused) == 1 else ""


def resumed_activity(activity_dump: str) -> str:
    """Read the top resumed activity rather than any historic task entry."""
    matches = [
        line.strip()
        for line in activity_dump.splitlines()
        if "topResumedActivity=" in line
    ]
    if not matches:
        matches = [
            line.strip()
            for line in activity_dump.splitlines()
            if line.strip().startswith("ResumedActivity:")
        ]
    return matches[0] if len(set(matches)) == 1 and matches else ""


def is_chronospark_activity(value: str) -> bool:
    return f"{PACKAGE}/.MainActivity" in value or f"{PACKAGE}/{PACKAGE}.MainActivity" in value


def focus() -> tuple[str, str]:
    return (
        focused_window(shell("dumpsys", "input", timeout=20)),
        resumed_activity(shell("dumpsys", "activity", "activities", timeout=20)),
    )


def app_ui_marker(xml_bytes: bytes) -> tuple[str, int]:
    """Require a visible app-owned navigation/authentication control."""
    try:
        hierarchy = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return "", 0
    app_nodes = [node for node in hierarchy.iter("node") if node.attrib.get("package") == PACKAGE]
    for node in app_nodes:
        label = " ".join((node.attrib.get("content-desc", ""), node.attrib.get("text", ""))).upper()
        for marker in UI_MARKERS:
            if re.search(rf"(?<!\w){re.escape(marker)}(?!\w)", label):
                return marker, len(app_nodes)
    return "", len(app_nodes)


def read_ui(number: int) -> bytes:
    guest_path = f"/sdcard/chronospark-native-16k-ui-{number}.xml"
    try:
        shell("uiautomator", "dump", guest_path, timeout=30)
        data = run("exec-out", "cat", guest_path, timeout=20, binary=True)
        assert isinstance(data, bytes)
        return data
    finally:
        # This is a disposable guest, and the temporary tree is never uploaded.
        try:
            shell("rm", guest_path, timeout=10)
        except subprocess.CalledProcessError:
            pass


def app_fatals(log: str) -> list[str]:
    lines = log.splitlines()
    matches: list[str] = []
    for index, line in enumerate(lines):
        if "FATAL EXCEPTION" in line and any(
            f"Process: {PACKAGE}" in candidate
            for candidate in lines[index : index + 9]
        ):
            matches.append(line)
        if "Fatal signal" in line and any(
            f"Cmdline: {PACKAGE}" in candidate or f">>> {PACKAGE} <<<" in candidate
            for candidate in lines[index : index + 35]
        ):
            matches.append(line)
    return matches


def main() -> int:
    ROOT.mkdir(parents=True, exist_ok=True)
    source = os.environ["QA_SOURCE_SHA"]
    tooling = os.environ["GITHUB_SHA"]
    expected_api = os.environ["QA_GUEST_API"]
    script_hash = sha256(Path(__file__))
    receipt: dict[str, object] = {
        "schemaVersion": 1,
        "suite": "qa-16k-native",
        "sourceSha": source,
        "workflowToolingSha": tooling,
        "toolScriptSha256": script_hash,
        "serial": SERIAL,
        "package": PACKAGE,
        "status": "failed",
        "launches": [],
    }
    try:
        assert re.fullmatch(r"[0-9a-f]{40}", source)
        assert re.fullmatch(r"[0-9a-f]{40}", tooling)
        assert expected_api in {"35", "36"}
        assert shell("getprop", "ro.kernel.qemu") == "1"
        actual_api = shell("getprop", "ro.build.version.sdk")
        assert actual_api == expected_api
        receipt["androidApi"] = actual_api
        assert shell("getconf", "PAGE_SIZE") == "16384"
        receipt["pageSize"] = 16384
        assert APK.is_file()
        receipt["apkSha256"] = sha256(APK)
        receipt["sourceVersionCode"] = source_version_code()
        run("install", "-r", str(APK.resolve()), timeout=120)
        package_info = shell("dumpsys", "package", PACKAGE, timeout=30)
        version_match = re.search(r"versionCode=(\d+)", package_info)
        assert version_match and version_match.group(1) == receipt["sourceVersionCode"]
        receipt["installedVersionCode"] = version_match.group(1)
        run("logcat", "-c", timeout=20)
        for number in range(1, 6):
            shell("am", "force-stop", PACKAGE, timeout=20)
            launch = shell("am", "start", "-W", "-n", ACTIVITY, timeout=45)
            assert "Status: ok" in launch, f"launch {number}: {launch}"
            current_focus = ""
            current_resumed = ""
            pid = ""
            for _ in range(15):
                current_focus, current_resumed = focus()
                try:
                    pid = shell("pidof", PACKAGE, timeout=10)
                except subprocess.CalledProcessError:
                    pid = ""
                if is_chronospark_activity(current_focus) and is_chronospark_activity(current_resumed) and pid:
                    break
                time.sleep(1)
            assert is_chronospark_activity(current_focus) and is_chronospark_activity(current_resumed) and pid, (
                f"launch {number}: focus={current_focus}, resumed={current_resumed}, pid={pid}"
            )
            ui_marker = ""
            ui_nodes = 0
            ui_hash = ""
            ui_start = time.monotonic()
            for _ in range(8):
                time.sleep(5)
                ui_bytes = read_ui(number)
                ui_marker, ui_nodes = app_ui_marker(ui_bytes)
                ui_hash = hashlib.sha256(ui_bytes).hexdigest()
                if ui_marker:
                    break
            if not ui_marker:
                unready = ROOT / f"unready-launch-{number}.png"
                unready.write_bytes(run("exec-out", "screencap", "-p", timeout=30, binary=True))
                receipt["unreadyCapture"] = {"number": number, "screenshotSha256": sha256(unready),
                                             "uiNodeCount": ui_nodes, "uiTreeSha256": ui_hash}
                raise AssertionError(f"launch {number}: app UI did not become ready in 8 bounded checks; app nodes={ui_nodes}")
            current_focus, current_resumed = focus()
            current_pid = shell("pidof", PACKAGE, timeout=10)
            assert is_chronospark_activity(current_focus) and is_chronospark_activity(current_resumed) and current_pid == pid, (
                f"launch {number}: app lost foreground or restarted during UI wait"
            )
            screenshot = ROOT / f"launch-{number}.png"
            screenshot.write_bytes(run("exec-out", "screencap", "-p", timeout=30, binary=True))
            assert screenshot.stat().st_size > 1000
            receipt["launches"].append(
                {
                    "number": number,
                    "pid": pid,
                    "focus": current_focus,
                    "resumedActivity": current_resumed,
                    "uiReadyMarker": ui_marker,
                    "uiNodeCount": ui_nodes,
                    "uiTreeSha256": ui_hash,
                    "uiWaitSeconds": round(time.monotonic() - ui_start, 2),
                    "screenshotSha256": sha256(screenshot),
                    "screenshotBytes": screenshot.stat().st_size,
                }
            )
        log = str(run("logcat", "-d", "-b", "main", "-b", "crash", "-v", "threadtime", timeout=40))
        receipt["logcatSha256"] = hashlib.sha256(log.encode("utf-8")).hexdigest()
        receipt["logcatBytes"] = len(log.encode("utf-8"))
        fatals = app_fatals(log)
        receipt["appFatalCount"] = len(fatals)
        assert not fatals, f"app fatal markers: {fatals[:3]}"
        assert len(receipt["launches"]) == 5
        receipt["status"] = "passed"
    except (AssertionError, KeyError, OSError, subprocess.SubprocessError, ET.ParseError) as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
    finally:
        (ROOT / "manifest.json").write_text(
            json.dumps(receipt, indent=2) + "\n", encoding="utf-8"
        )
    print(json.dumps({key: value for key, value in receipt.items() if key != "launches"}))
    return 0 if receipt["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
