# Axiomara exact-main test receipts — September 24, 2026

These small files are verbatim copies from the GitHub Actions artifacts for
source `baf802d08b4e6472820e1c229c554d90fdbc12ea`. They preserve the
machine-readable results after workflow artifacts expire; the linked runs and
their full logs remain the primary execution record.

- [CI/CD run 36071219646](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/36071219646): `exact-commit.json`, `flutter-tests-manifest.json`, and `qa-config-tests-manifest.json`. The manifests report 3,396/3,396 Flutter and 15/15 QA configuration tests passed, with zero failures, errors, or skips.
- [Maestro Runtime Gate 36071219710](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/36071219710): `maestro-preflight.json`, `maestro-manifest.json`, and `maestro-results.xml`. A clean Android 15 guest executed five selected QA journeys, with five JUnit cases and zero failures, errors, or skips. The manifest reports no fatal log markers and the app alive throughout.

| File | SHA-256 |
|---|---|
| `exact-commit.json` | `cbffa446ae1e72d933290ba86e8960c2d280aba272f814c892f73d3358d0f2e8` |
| `flutter-tests-manifest.json` | `1a1c69b7a526f976f5702354d919d24c65bd248038ff6c10e6ebdcf413c12bde` |
| `qa-config-tests-manifest.json` | `66595669ccf4828f9aef5fc5853ef4b6ab74a79c16ffe8d724494e31434838b7` |
| `maestro-preflight.json` | `9d04511425c0f0bb1a0d1bcac260d46dcc2f41dccc6b41a10e19a124d235a7ca` |
| `maestro-manifest.json` | `bbb01d49903e0de5a9a6d438b918b06e5b02cf5e997d16f3d9130fa056032dd6` |
| `maestro-results.xml` | `87db7e67ae06a0a683737453bedd7c21a953bbd8e69db97b8829241707c09156` |

The Android artifact is a debug QA APK built from this source, version
`4.1.0+2026083084`, SHA-256
`17dbc48b5baea12b3930502745eee774bb45ffea127987269f47390e1a81576c`.
It is not Play-signed, and the QA profile does not enable public paid features.
These receipts do not prove a production release, Play billing, live backend
journeys, or full-device coverage.
