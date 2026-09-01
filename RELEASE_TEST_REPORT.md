# ChronoSpark Production-Candidate Release Test Report

Updated: 2026-09-01T08:18:51-05:00

Verdict: **NOT VERIFIED**

This report will cover the exact signed AAB built from the final candidate commit. A build success, debug APK, mock service, source inspection, or unrelated earlier artifact does not count as release evidence.

## Candidate identity

| Field | Evidence |
| --- | --- |
| Repository | `ghostheart5/fantastic-guacamole` |
| Checkout | `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901` |
| Branch | `codex/production-candidate-20260901` |
| Green base | `33a7e39dd3de49b219c0de750bb1fdd31e9d8573` |
| Candidate checkpoint | `8bec7af2780f2e2e07d5ea8d2ea724ea317fa5fa` was exact-head green, but its artifact is superseded by the pending accessibility repair commit |
| Final tested commit | NOT VERIFIED |
| versionName / versionCode | `4.1.0` / `2026083003` (confirmed in superseded artifact; final artifact pending) |
| AAB path | `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901\build\app\outputs\bundle\release\app-release-prod-vc2026083003.aab` (SUPERSEDED; will be overwritten by final rebuild) |
| AAB SHA-256 | `8E96865BFEB2DA907346976F0F9BC5BD0FBC72E9D9292ACBBA470FBECAB4D614` (SUPERSEDED) |
| Upload certificate SHA-1 | `8A:24:D7:BA:AC:AB:52:F0:A3:77:7D:D0:47:C9:07:96:2E:82:FA:A5` (local-to-Play match) |
| Build timestamp / command | 2026-09-01 07:55:01-05:00 to 07:59:45-05:00; `powershell -File scripts/build_android_aab_prod_guarded.ps1` (SUPERSEDED) |

## Current preflight

| Gate | Result | Evidence boundary |
| --- | --- | --- |
| Exact-main GitHub suite | PASS | Run `33481507007` at base commit only |
| Candidate exact-head GitHub suite | REPAIR ATTEMPT 1 OF 3 | Run `33508432103` passed all 10 applicable checks at `8bec7af2`. Run `33512733923` at the accessibility repair commit passed formatting and secret guards, then failed analysis only because the new test used a deprecated semantics helper under `--fatal-infos`; its replacement uses the current API. |
| Isolated clean candidate | PASS at creation | Must be rechecked before build |
| JDK / Flutter / Android SDK / ADB / bundletool / Maestro | PASS | Tool presence and versions inspected |
| Release signing identity | PASS | Local keystore SHA-1 matches Play Console upload key |
| Production endpoint shape | PASS after secret repair | Real reconciliation endpoint reached |
| Backend reconciliation response contract | LOCAL FOCUSED PASS; LIVE BLOCKED | Workflow parser, release contract, and both secret guards pass. Attempt 2 was rejected before execution by production-environment branch protection; no backend call occurred. |
| Dedicated real test account | PASS | One isolated, auto-confirmed production Auth user; Windows Credential Manager storage; real sign-in HTTP 200; verification session revoked |
| Minimum API 24 environment | PREFLIGHT PASS | Image installed; `ChronoSpark_API_24` boot complete on SDK 24 with network connectivity |
| Newest available API environment | AVAILABLE | API 37.1 16 KB-page-size image and `ChronoSpark_API_37_1` AVD created; runtime boot pending |
| Exact AAB validation/install/runtime | SUPERSEDED PARTIAL PASS | The `8bec7af2` AAB validated, generated an APKS archive, installed on API 24, and passed first-launch stability/log checks. A later source repair invalidates it as the final artifact. |

## Runtime matrix

| Device/API | Exact AAB-derived install | Maestro | Integration | Monkey | Human journeys | Logs/soak |
| --- | --- | --- | --- | --- | --- | --- |
| Minimum supported API 24 | SUPERSEDED INSTALL PASS | Onboarding PASS; login BLOCKED then repaired in source | Auth not reached; no request sent | NOT RUN | First launch PASS; login UI visually correct but inaccessible to UI Automator | First 90 seconds PASS; 0 critical matches |
| Newest available API 37.1 | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Connected physical phone | NOT ATTACHED | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |

## Required final evidence

- bundletool validation and APKS generation from the exact AAB
- AAB/APKS full paths and SHA-256 checksums
- installed package/version/signing evidence
- clean install, available upgrade, onboarding, auth/session/storage, navigation, real AI/SI, validation inputs, permissions, offline/network loss, lifecycle/process recreation, accessibility, R8-only behavior, crash/ANR/logcat, and bounded soak results
- exact live AI/API call count (current: `0` AI calls; `2` production Auth API calls)
- known limitations, reproduction commands, rollback instructions, and stable-branch preservation proof

## Superseded artifact evidence

- AAB bytes: `84,769,831`; SHA-256: `8E96865BFEB2DA907346976F0F9BC5BD0FBC72E9D9292ACBBA470FBECAB4D614`.
- APKS path: `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901\build\app\outputs\bundle\release\app-release-prod-vc2026083003.apks`; bytes: `104,876,953`; SHA-256: `D8736FF4735751A3EF70F5AC9925D4764D2788E69A10E6036AC2D2BD63AD2588`.
- Installed API 24 splits were selected from that APKS archive and the base master APK verified with the expected SHA-256 signing certificate fingerprint `D8:8E:CF:C6:1A:95:B5:8B:53:3E:38:96:37:8A:2D:70:89:4D:6E:F2:74:D8:C5:6C:9F:90:A7:7C:54:4E:8D:79`.
- These values are retained only as an audit trail. They are not final candidate evidence because app source changed afterward.

## Runtime repair evidence

- API 24 UI Automator exposed both visible login `EditText` nodes with empty content description, text, and resource ID. Maestro could not select a field, so the tester credential was never entered and no production authentication request was made.
- The app now wraps the existing field `Semantics` and `TextField` in `MergeSemantics`; the focused widget assertion proves the label and editable-text flag occupy the same semantics node.
- Focused command: `flutter test test/features/auth/login_screen_golden_test.dart --plain-name "names login fields and the password visibility action"` — PASS.
- `git diff --check` — PASS. A fresh signed AAB and full release validation are required after exact-head CI passes.
- Commit `8b9f681ea8bce2ed00151d7852eaef062dce7fc7` subsequently passed all applicable GitHub checks in run `33513135260`, built and validated, and produced an exact APKS archive that clean-installed on API 24.
- API 24 first launch stayed alive through 90 seconds on the fully rendered Welcome screen. Strict Logcat counts were zero for fatal exceptions, `E/flutter`, app AndroidRuntime errors, and package ANRs. The corrected onboarding Maestro flow passed.
- Login remained blocked before credential entry: the native API 24 UI tree still reported both `EditText` nodes with empty labels. This is final repair cycle 3 of 3; native non-floating `InputDecoration.labelText` values now provide the visible placeholder and editable-node semantics directly.
