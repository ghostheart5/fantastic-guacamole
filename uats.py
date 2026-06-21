#!/usr/bin/env python3
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(os.getcwd())

REPORTS = {
    "structure": "structure_report.json",
    "imports": "import_report.json",
    "signatures": "signature_report.json",
    "ui": "ui_report.json",
    "tests": "test_report.json",
}

# Project-shaped expectations for this repo.
EXPECTED_LIB_FOLDERS = ["app", "core", "data", "domain", "features", "theme", "ui"]
EXPECTED_DOMAIN_SUBFOLDERS = ["entities", "repositories", "usecases"]

IMPORT_RELATED_CODES = {
    "uri_does_not_exist",
    "undefined_class",
    "undefined_function",
    "undefined_getter",
    "undefined_identifier",
    "undefined_method",
}

SIGNATURE_RELATED_CODES = {
    "extra_positional_arguments",
    "missing_required_argument",
    "not_enough_positional_arguments",
    "undefined_named_parameter",
}


def write_report(name, data):
    with open(REPORTS[name], "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)


def run_command(command):
    return subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        shell=True,
    )


def parse_flutter_analyze(output):
    diagnostics = []
    pattern = re.compile(
        r"^\s*(error|warning|info)\s*-\s*(.*?)\s*-\s*([^:]+):(\d+):(\d+)\s*-\s*([a-z0-9_]+)\s*$",
        re.IGNORECASE,
    )
    for line in output.splitlines():
        match = pattern.match(line)
        if not match:
            continue
        severity, message, file_path, line_no, col_no, code = match.groups()
        diagnostics.append(
            {
                "severity": severity.lower(),
                "message": message.strip(),
                "file": file_path.strip(),
                "line": int(line_no),
                "column": int(col_no),
                "code": code.strip(),
            }
        )
    return diagnostics


def run_analyzer_once():
    result = run_command("flutter analyze")
    output = (result.stdout or "") + "\n" + (result.stderr or "")
    diagnostics = parse_flutter_analyze(output)
    return result.returncode, diagnostics, output.strip()


# ---------------------------------------------------------
# PHASE 1 — STRUCTURE AUDIT
# ---------------------------------------------------------
def audit_structure():
    issues = []

    lib_root = ROOT / "lib"
    for folder in EXPECTED_LIB_FOLDERS:
        if not (lib_root / folder).exists():
            issues.append(f"Missing folder: lib/{folder}")

    domain_root = lib_root / "domain"
    if domain_root.exists():
        for sub in EXPECTED_DOMAIN_SUBFOLDERS:
            if not (domain_root / sub).exists():
                issues.append(f"Missing domain subfolder: {domain_root / sub}")

    write_report("structure", {"issues": issues})
    return issues


# ---------------------------------------------------------
# PHASE 2 — IMPORT & DEPENDENCY AUDIT
# ---------------------------------------------------------
def audit_imports(diagnostics):
    issues = []

    for d in diagnostics:
        if d["code"] in IMPORT_RELATED_CODES:
            issues.append(
                f"{d['severity']} [{d['code']}] {d['file']}:{d['line']}:{d['column']} - {d['message']}"
            )

    write_report("imports", {"issues": issues})
    return issues


# ---------------------------------------------------------
# PHASE 3 — LOGIC & SIGNATURE AUDIT
# ---------------------------------------------------------
def audit_signatures(diagnostics):
    issues = []

    for d in diagnostics:
        if d["code"] in SIGNATURE_RELATED_CODES:
            issues.append(
                f"{d['severity']} [{d['code']}] {d['file']}:{d['line']}:{d['column']} - {d['message']}"
            )

    write_report("signatures", {"issues": issues})
    return issues


# ---------------------------------------------------------
# PHASE 4 — UI & ROUTER AUDIT
# ---------------------------------------------------------
def audit_ui():
    issues = []

    routes_file = ROOT / "lib" / "app" / "routes.dart"
    if not routes_file.exists():
        issues.append("Missing router file: lib/app/routes.dart")
        write_report("ui", {"issues": issues})
        return issues

    content = routes_file.read_text(encoding="utf-8", errors="ignore")

    expected_routes = [
        "/",
        "/creator",
        "/logs",
        "/temporal",
        "/si",
        "/settings",
    ]

    for route in expected_routes:
        if f"case '{route}'" not in content:
            issues.append(f"Route not registered in routes.dart: {route}")

    write_report("ui", {"issues": issues})
    return issues


# ---------------------------------------------------------
# PHASE 5 — FULL TEST SUITE
# ---------------------------------------------------------
def audit_tests():
    issues = []

    test_dir = ROOT / "test"
    if not test_dir.exists():
        issues.append("No test directory found (test/).")
        write_report("tests", {"issues": issues})
        return issues

    result = run_command("flutter test")
    if result.returncode != 0:
        issues.append("Flutter tests failed")
        if result.stdout:
            issues.append(result.stdout.strip())
        if result.stderr:
            issues.append(result.stderr.strip())

    write_report("tests", {"issues": issues})
    return issues


# ---------------------------------------------------------
# MAIN EXECUTION
# ---------------------------------------------------------
def main():
    print("Running Universal Audit & Test Script (Analyzer-backed Mode)...")

    analyzer_exit, diagnostics, raw_output = run_analyzer_once()
    if analyzer_exit != 0 and not diagnostics:
        print("Analyzer command failed unexpectedly.")
        print(raw_output)

    structure = audit_structure()
    imports = audit_imports(diagnostics)
    signatures = audit_signatures(diagnostics)
    ui = audit_ui()
    tests = audit_tests()

    print("\nAudit complete. Reports generated:")
    for _, file in REPORTS.items():
        print(f" - {file}")

    print("\nSummary:")
    print(f"Structure issues: {len(structure)}")
    print(f"Import issues: {len(imports)}")
    print(f"Signature issues: {len(signatures)}")
    print(f"UI issues: {len(ui)}")
    print(f"Test issues: {len(tests)}")


if __name__ == "__main__":
    main()
