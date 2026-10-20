from __future__ import annotations

import argparse
import hashlib
import pathlib
import zipfile


OFFICIAL_AAR_SHA256 = "adca1d7cde73406fcca2a0eeabac63459adc9d1fe201b79ba08711fa2e331984"
ARTIFACT = "datastore-core-android-symbolized"
VERSION = "1.1.7-gh1"
ABIS = ("arm64-v8a", "armeabi-v7a", "x86", "x86_64")
LIBRARY = "libdatastore_shared_counter.so"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--official-aar", required=True, type=pathlib.Path)
    parser.add_argument("--official-pom", required=True, type=pathlib.Path)
    parser.add_argument("--libraries", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()

    official_bytes = args.official_aar.read_bytes()
    if digest(official_bytes) != OFFICIAL_AAR_SHA256:
        raise SystemExit("The official AndroidX DataStore 1.1.7 AAR digest did not match.")

    replacements = {
        f"jni/{abi}/{LIBRARY}": (args.libraries / f"{abi}.so").read_bytes()
        for abi in ABIS
    }
    output_aar = args.output / f"{ARTIFACT}-{VERSION}.aar"
    args.output.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(args.official_aar) as source:
        source_names = source.namelist()
        if len(source_names) != len(set(source_names)):
            raise SystemExit("Official AAR contains duplicate members.")
        if not set(replacements).issubset(source_names):
            raise SystemExit("A required ABI library is absent from the official AAR.")
        with zipfile.ZipFile(output_aar, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as target:
            for name in source_names:
                contents = replacements.get(name, source.read(name))
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                target.writestr(info, contents)

    pom = args.official_pom.read_text(encoding="utf-8")
    original_identity = "<groupId>androidx.datastore</groupId>\n  <artifactId>datastore-core-android</artifactId>\n  <version>1.1.7</version>"
    rebuilt_identity = f"<groupId>com.ghostheart5.rebuilt</groupId>\n  <artifactId>{ARTIFACT}</artifactId>\n  <version>{VERSION}</version>"
    if pom.count(original_identity) != 1:
        raise SystemExit("Official POM identity did not match the expected coordinates.")
    pom_path = args.output / f"{ARTIFACT}-{VERSION}.pom"
    pom_path.write_text(pom.replace(original_identity, rebuilt_identity, 1), encoding="utf-8", newline="\n")

    print(f"Official AAR SHA-256: {digest(official_bytes)}")
    print(f"Rebuilt AAR SHA-256: {digest(output_aar.read_bytes())}")
    for name, contents in replacements.items():
        print(f"{name} SHA-256: {digest(contents)}")


if __name__ == "__main__":
    main()
