"""Check complete additional notices and their pinned SDK provenance in an AAB/APK."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import zipfile
import zlib

EXPECTED_DART_REVISION = "d684a576a6aa954ae107a03b2b4e1d61c3bebe93"
MAX_NOTICES_BYTES = 64 * 1024 * 1024


class VerificationError(Exception):
    """A fixed diagnostic code, never native error text or file contents."""


def declared_notices(repo_root: Path) -> list[Path]:
    """Read the simple path list supported by this repository's pubspec policy.

    Fail closed on unsupported YAML forms instead of ignoring declarations.
    The Flutter manifest parser independently validates the whole pubspec.
    """
    root = repo_root.resolve()
    lines = (root / "pubspec.yaml").read_text(encoding="utf-8").splitlines()
    in_flutter = False
    in_licenses = False
    seen_licenses = False
    paths: list[Path] = []
    for line in lines:
        content = line.strip()
        if not content or content.startswith("#"):
            continue
        if not line[0].isspace():
            if in_flutter:
                break
            in_flutter = content == "flutter:"
            continue
        if not in_flutter:
            continue
        indentation = len(line) - len(line.lstrip(" "))
        if indentation == 2:
            if content.startswith("licenses:"):
                if content != "licenses:" or seen_licenses:
                    raise VerificationError("unsupported_license_declaration")
                in_licenses = seen_licenses = True
            else:
                in_licenses = False
            continue
        if not in_licenses:
            continue
        if indentation != 4 or not content.startswith("- "):
            raise VerificationError("unsupported_license_declaration")
        relative = content[2:]
        if not re.fullmatch(r"[A-Za-z0-9_./-]+", relative):
            raise VerificationError("unsupported_license_path")
        path = (root / relative).resolve()
        if not path.is_relative_to(root) or path in paths:
            raise VerificationError("unsafe_or_duplicate_license_path")
        if not path.is_file():
            raise VerificationError("declared_license_missing")
        body = path.read_bytes()
        if not body.strip():
            raise VerificationError("declared_license_empty")
        try:
            body.decode("utf-8")
        except UnicodeError as error:
            raise VerificationError("declared_license_invalid_utf8") from error
        paths.append(path)
    if not paths:
        raise VerificationError("additional_licenses_not_declared")
    return paths


def sdk_proof(flutter_executable: str) -> dict:
    resolved = shutil.which(flutter_executable)
    executable = Path(resolved or flutter_executable).resolve()
    if not executable.is_file() or executable.name not in ("flutter", "flutter.bat"):
        raise VerificationError("flutter_executable_unresolved")
    revision_file = executable.parent / "cache" / "dart-sdk" / "revision"
    if not revision_file.is_file():
        raise VerificationError("dart_sdk_revision_missing")
    revision = revision_file.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[a-f0-9]{40}", revision):
        raise VerificationError("dart_sdk_revision_invalid")
    return {
        "flutterExecutable": str(executable),
        "revisionFile": str(revision_file),
        "expectedDartRevision": EXPECTED_DART_REVISION,
        "actualDartRevision": revision,
        "matches": revision == EXPECTED_DART_REVISION,
    }


def verify_artifact(artifact: Path, repo_root: Path, flutter_executable: str) -> dict:
    expected_entry = {
        ".aab": "base/assets/flutter_assets/NOTICES.Z",
        ".apk": "assets/flutter_assets/NOTICES.Z",
    }.get(artifact.suffix.lower())
    if expected_entry is None:
        raise VerificationError("unsupported_artifact_type")
    root = repo_root.resolve()
    notices = declared_notices(root)
    sdk = sdk_proof(flutter_executable)
    artifact_hash = hashlib.sha256()
    with artifact.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            artifact_hash.update(chunk)
    with zipfile.ZipFile(artifact) as bundle:
        entries = [entry for entry in bundle.infolist()
                   if entry.filename.endswith("/flutter_assets/NOTICES.Z")]
        if len(entries) != 1 or entries[0].filename != expected_entry:
            raise VerificationError("bundled_notices_missing_or_ambiguous")
        entry = entries[0]
        if entry.file_size > MAX_NOTICES_BYTES:
            raise VerificationError("bundled_notices_too_large")
        # Bound decoded input as well as ZIP entry size.
        with bundle.open(entry) as compressed, gzip.GzipFile(fileobj=compressed) as decoded:
            content = decoded.read(MAX_NOTICES_BYTES + 1)
        if len(content) > MAX_NOTICES_BYTES:
            raise VerificationError("bundled_notices_too_large")
        try:
            content.decode("utf-8")
        except UnicodeError as error:
            raise VerificationError("bundled_notices_invalid_utf8") from error
    checks = []
    for path in notices:
        body = path.read_bytes()
        checks.append({
            "path": path.relative_to(root).as_posix(),
            "sha256": hashlib.sha256(body).hexdigest(),
            "byteLength": len(body),
            "completeTextPresent": body in content,
        })
    return {
        "schemaVersion": 1,
        "success": sdk["matches"] and all(check["completeTextPresent"] for check in checks),
        "artifact": str(artifact.resolve()),
        "artifactSha256": artifact_hash.hexdigest(),
        "bundledNoticesEntry": entry.filename,
        "bundledNoticesSha256": hashlib.sha256(content).hexdigest(),
        "sdk": sdk,
        "notices": checks,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", required=True, type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--flutter-executable", required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)
    try:
        result = verify_artifact(args.artifact, args.repo_root, args.flutter_executable)
    except VerificationError as error:
        result = {"schemaVersion": 1, "success": False, "errorCode": str(error)}
    except (OSError, ValueError, UnicodeError, zipfile.BadZipFile, EOFError, zlib.error):
        result = {"schemaVersion": 1, "success": False, "errorCode": "artifact_or_input_unreadable"}
    output = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output, encoding="utf-8", newline="\n")
    sys.stdout.write(output)
    return 0 if result["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
