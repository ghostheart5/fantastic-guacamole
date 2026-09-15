"""Bounded, source-bound 16 KiB QA launch probe without an on-device test agent."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

SERIAL = "emulator-5554"
PACKAGE = "com.ghostheart5.chronospark"
ACTIVITY = f"{PACKAGE}/.MainActivity"
EXPECTED_VERSION = "2026083053"
ROOT = Path("test-results/native-16k-ci")
APK = Path("build/app/outputs/flutter-apk/app-debug.apk")


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
        assert shell("getprop", "ro.kernel.qemu") == "1"
        assert shell("getprop", "ro.build.version.sdk") == "35"
        assert shell("getconf", "PAGE_SIZE") == "16384"
        receipt["pageSize"] = 16384
        assert APK.is_file()
        receipt["apkSha256"] = sha256(APK)
        run("install", "-r", str(APK.resolve()), timeout=120)
        package_info = shell("dumpsys", "package", PACKAGE, timeout=30)
        version_match = re.search(r"versionCode=(\d+)", package_info)
        assert version_match and version_match.group(1) == EXPECTED_VERSION
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
            screenshot = ROOT / f"launch-{number}.png"
            screenshot.write_bytes(run("exec-out", "screencap", "-p", timeout=30, binary=True))
            assert screenshot.stat().st_size > 1000
            receipt["launches"].append(
                {
                    "number": number,
                    "pid": pid,
                    "focus": current_focus,
                    "resumedActivity": current_resumed,
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
    except (AssertionError, KeyError, OSError, subprocess.SubprocessError) as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
    finally:
        (ROOT / "manifest.json").write_text(
            json.dumps(receipt, indent=2) + "\n", encoding="utf-8"
        )
    print(json.dumps({key: value for key, value in receipt.items() if key != "launches"}))
    return 0 if receipt["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
