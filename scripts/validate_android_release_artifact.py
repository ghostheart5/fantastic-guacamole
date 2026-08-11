#!/usr/bin/env python3
"""Validate a built ChronoSpark Android App Bundle and emit release evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


ANDROID = "{http://schemas.android.com/apk/res/android}"
FORBIDDEN_PERMISSIONS = {
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.CALL_PHONE",
    "android.permission.CAMERA",
    "android.permission.READ_CALL_LOG",
    "android.permission.READ_CONTACTS",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.READ_MEDIA_AUDIO",
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
    "android.permission.READ_PHONE_STATE",
    "android.permission.READ_SMS",
    "android.permission.SEND_SMS",
    "android.permission.WRITE_CALL_LOG",
    "android.permission.WRITE_CONTACTS",
    "android.permission.WRITE_EXTERNAL_STORAGE",
    "com.google.android.gms.permission.AD_ID",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--aab", required=True, type=Path)
    parser.add_argument("--expected-package", required=True)
    parser.add_argument("--expected-version-name", required=True)
    parser.add_argument("--expected-version-code", required=True)
    parser.add_argument("--minimum-target-sdk", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def find_merged_manifest(
    package_name: str,
    version_name: str,
    version_code: str,
) -> tuple[Path, ET.Element]:
    candidates = sorted(
        Path("build/app/intermediates").rglob("AndroidManifest.xml"),
        key=lambda path: (
            "release" not in path.as_posix().lower(),
            "merged_manifest" not in path.as_posix().lower(),
            len(path.parts),
        ),
    )
    for candidate in candidates:
        try:
            root = ET.parse(candidate).getroot()
        except (ET.ParseError, OSError):
            continue
        if (
            root.attrib.get("package") == package_name
            and root.attrib.get(f"{ANDROID}versionName") == version_name
            and root.attrib.get(f"{ANDROID}versionCode") == version_code
        ):
            return candidate, root
    raise SystemExit("No release merged manifest matches the expected package and version.")


def main() -> None:
    args = parse_args()
    if not args.aab.is_file() or args.aab.stat().st_size == 0:
        raise SystemExit(f"AAB is missing or empty: {args.aab}")

    required_entries = {
        "BundleConfig.pb",
        "base/dex/classes.dex",
        "base/manifest/AndroidManifest.xml",
        "base/resources.pb",
    }
    with zipfile.ZipFile(args.aab) as bundle:
        corrupt_entry = bundle.testzip()
        if corrupt_entry is not None:
            raise SystemExit(f"AAB contains a corrupt ZIP entry: {corrupt_entry}")
        entries = set(bundle.namelist())
        missing_entries = sorted(required_entries - entries)
        if missing_entries:
            raise SystemExit("AAB is missing required entries: " + ", ".join(missing_entries))
        mapping_entries = sorted(
            entry for entry in entries if "obfuscation" in entry.lower() and entry.endswith(".map")
        )
        if not mapping_entries:
            raise SystemExit("AAB does not contain R8/obfuscation mapping metadata.")
        raw_manifest = bundle.read("base/manifest/AndroidManifest.xml")
        env_entries = sorted(entry for entry in entries if entry.endswith("flutter_assets/.env"))
        if len(env_entries) != 1:
            raise SystemExit("AAB must contain exactly one generated Flutter .env asset.")
        env_keys = sorted(
            line.split("=", 1)[0].strip()
            for line in bundle.read(env_entries[0]).decode("utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#") and "=" in line
        )
        if env_keys != ["CHRONOSPARK_SUPABASE_ANON_KEY", "CHRONOSPARK_SUPABASE_URL"]:
            raise SystemExit("AAB .env contains unexpected or missing configuration keys.")

    mapping_file = Path("build/app/outputs/mapping/release/mapping.txt")
    if not mapping_file.is_file() or mapping_file.stat().st_size == 0:
        raise SystemExit("Release R8 mapping.txt is missing or empty.")

    manifest_path, manifest = find_merged_manifest(
        args.expected_package,
        args.expected_version_name,
        args.expected_version_code,
    )
    application = manifest.find("application")
    if application is None:
        raise SystemExit("Merged manifest has no application element.")

    expected_application_flags = {
        "allowBackup": "false",
        "debuggable": "false",
        "usesCleartextTraffic": "false",
    }
    actual_application_flags = {
        flag: application.attrib.get(f"{ANDROID}{flag}", "false")
        for flag in expected_application_flags
    }
    bad_flags = sorted(
        flag
        for flag, expected in expected_application_flags.items()
        if actual_application_flags[flag].lower() != expected
    )
    if bad_flags:
        raise SystemExit("Unsafe merged manifest application flags: " + ", ".join(bad_flags))

    profileable = application.find("profileable")
    if profileable is not None and profileable.attrib.get(f"{ANDROID}shell", "false").lower() == "true":
        raise SystemExit("Release application must not be shell-profileable.")

    uses_sdk = manifest.find("uses-sdk")
    if uses_sdk is None:
        raise SystemExit("Merged manifest has no uses-sdk element.")
    target_sdk = int(uses_sdk.attrib.get(f"{ANDROID}targetSdkVersion", "0"))
    min_sdk = int(uses_sdk.attrib.get(f"{ANDROID}minSdkVersion", "0"))
    if target_sdk < args.minimum_target_sdk:
        raise SystemExit(
            f"Release target SDK {target_sdk} is below required floor {args.minimum_target_sdk}."
        )

    permissions = sorted(
        {
            node.attrib.get(f"{ANDROID}name", "")
            for node in manifest.findall("uses-permission")
            if node.attrib.get(f"{ANDROID}name")
        }
    )
    forbidden_permissions = sorted(set(permissions) & FORBIDDEN_PERMISSIONS)
    if forbidden_permissions:
        raise SystemExit(
            "Merged manifest contains forbidden permissions: " + ", ".join(forbidden_permissions)
        )

    exported_components = []
    for component_type in ("activity", "activity-alias", "provider", "receiver", "service"):
        for node in application.findall(component_type):
            if node.attrib.get(f"{ANDROID}exported", "false").lower() == "true":
                exported_components.append(
                    {
                        "type": component_type,
                        "name": node.attrib.get(f"{ANDROID}name", ""),
                    }
                )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    evidence_manifest = args.output.parent / "merged-AndroidManifest.xml"
    evidence_mapping = args.output.parent / "mapping.txt"
    shutil.copy2(manifest_path, evidence_manifest)
    shutil.copy2(mapping_file, evidence_mapping)

    evidence = {
        "aab": {
            "path": args.aab.as_posix(),
            "sha256": sha256(args.aab),
            "size_bytes": args.aab.stat().st_size,
            "entry_count": len(entries),
            "raw_manifest_sha256": hashlib.sha256(raw_manifest).hexdigest(),
            "mapping_entries": mapping_entries,
            "environment_asset_keys": env_keys,
        },
        "application": {
            "package": args.expected_package,
            "version_name": args.expected_version_name,
            "version_code": args.expected_version_code,
            "min_sdk": min_sdk,
            "target_sdk": target_sdk,
            "flags": actual_application_flags,
            "permissions": permissions,
            "exported_components": exported_components,
        },
        "mapping_sha256": sha256(mapping_file),
        "merged_manifest_sha256": sha256(manifest_path),
    }
    args.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
