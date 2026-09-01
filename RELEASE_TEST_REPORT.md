# ChronoSpark Production-Candidate Release Test Report

Updated: 2026-09-01T10:20:00-05:00

Verdict: **NOT VERIFIED FOR PRODUCTION**

The exact signed AAB was built, validated, converted to APK splits, installed, and exercised on the minimum and newest available Android API lanes. The candidate is not production-ready because minimum-supported API 24 still does not expose usable native login-field labels, blocking real release authentication and every authenticated journey after the three permitted repair cycles.

## Candidate identity

| Field | Evidence |
| --- | --- |
| Repository | `ghostheart5/fantastic-guacamole` |
| Checkout | `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901` |
| Branch | `codex/production-candidate-20260901` |
| Green base | `33a7e39dd3de49b219c0de750bb1fdd31e9d8573` |
| Candidate checkpoint | `9b5d0aa925f64d979fa8873172a58d116cd8c048` |
| Final tested app-source commit | `9b5d0aa925f64d979fa8873172a58d116cd8c048` |
| versionName / versionCode | `4.1.0` / `2026083003` |
| AAB path | `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901\build\app\outputs\bundle\release\app-release-prod-vc2026083003.aab` |
| AAB bytes / SHA-256 | `84,769,126` / `161A85F12F910B6B1BBF3D64CD49342B425DEAA7411FE89AC8BAAC1A7B27A6F4` |
| APKS path | `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901\build\app\outputs\bundle\release\app-release-prod-vc2026083003.apks` |
| APKS bytes / SHA-256 | `104,876,953` / `FC7AADD110E250B88C113BF425D3918F0FE07EC4011E92CE43EF8C2E2E03A5EB` |
| Upload certificate SHA-1 | `8A:24:D7:BA:AC:AB:52:F0:A3:77:7D:D0:47:C9:07:96:2E:82:FA:A5` (local-to-Play match) |
| Upload certificate SHA-256 | `D8:8E:CF:C6:1A:95:B5:8B:53:3E:38:96:37:8A:2D:70:89:4D:6E:F2:74:D8:C5:6C:9F:90:A7:7C:54:4E:8D:79` |
| Build timestamp / command | AAB completed 2026-09-01 09:44:56-05:00; `powershell -File scripts/build_android_aab_prod_guarded.ps1 -SigningPropertiesPath <external-key.properties> -SigningKeystorePath <external-upload-keystore.jks>` |

## Current preflight

| Gate | Result | Evidence boundary |
| --- | --- | --- |
| Exact-main GitHub suite | PASS | Run `33481507007` at base commit only |
| Candidate exact-head GitHub suite | PASS | Run `33519048862` passed at `9b5d0aa9`; 10 applicable checks successful, Supabase Preview intentionally skipped, 0 failed/pending; PR #83 clean and mergeable |
| Isolated clean candidate | PASS | Clean during final build and runtime; final documentation is committed separately without app-source changes |
| JDK / Flutter / Android SDK / ADB / bundletool / Maestro | PASS | Tool presence and versions inspected |
| Release signing identity | PASS | Local keystore SHA-1 matches Play Console upload key |
| Production endpoint shape | PASS after secret repair | Real reconciliation endpoint reached |
| Backend reconciliation response contract | LOCAL FOCUSED PASS; LIVE BLOCKED | Workflow parser, release contract, and both secret guards pass. Attempt 2 was rejected before execution by production-environment branch protection; no backend call occurred. |
| Dedicated real test account | PASS | One isolated, auto-confirmed production Auth user; Windows Credential Manager storage; real sign-in HTTP 200; verification session revoked |
| Minimum API 24 environment | PREFLIGHT PASS | Image installed; `ChronoSpark_API_24` boot complete on SDK 24 with network connectivity |
| Newest available API environment | PASS | `ChronoSpark_API_37_1`, Android API 37 / Android 17, 16 KB-page-size image booted and tested |
| Exact AAB validation/install/runtime | ARTIFACT PASS; PRODUCTION GATE FAIL | `bundletool validate` passed; exact-AAB APKs installed on API 24 and API 37. Authentication remains blocked on API 24. |

## Runtime matrix

| Device/API | Exact AAB-derived install | Maestro | Integration | Monkey | Human journeys | Logs/soak |
| --- | --- | --- | --- | --- | --- | --- |
| Minimum supported API 24 | PASS | Onboarding handoff PASS; login BLOCKED | Auth/session/storage/AI not reached; no credential or request sent | PASS, 5 stages / 1,700 events | First launch, lifecycle, force-stop/reopen, airplane/reconnect PASS; native login accessibility FAIL | 90 seconds PASS; 0 strict critical matches |
| Newest available API 37.1 | PASS | Onboarding handoff PASS; login not retried after global retry limit | Auth/session/storage/AI not run | PASS, 5 stages / 1,700 events | First launch, lifecycle, force-stop/reopen, airplane/reconnect PASS; native hints present | 90 seconds PASS; repeat 180-second soak PASS; 0 strict critical matches |
| Connected physical phone | NOT ATTACHED | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |

## Production-gate blockers

- API 24 native UI Automator reports both visible login `EditText` nodes with empty text, content description, hint, and resource ID. Maestro cannot address a field, so the test credential was never entered.
- This same minimum-API failure survived all three permitted repair cycles. No fourth app repair or login retry was attempted.
- Real release account creation/login/logout, session restoration, authenticated storage/provider behavior, authenticated navigation, persistence after restart, permission journeys behind login, and real ChronoSpark AI/SI remain `NOT VERIFIED`.
- No physical phone was attached. Google Play Internal Testing was not uploaded or exercised.
- Live AI calls: `0`. Other live production API calls: `2` for tester sign-in and immediate session revocation before release-device testing.

## Superseded artifact evidence

- AAB bytes: `84,769,831`; SHA-256: `8E96865BFEB2DA907346976F0F9BC5BD0FBC72E9D9292ACBBA470FBECAB4D614`.
- APKS path: `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901\build\app\outputs\bundle\release\app-release-prod-vc2026083003.apks`; bytes: `104,876,953`; SHA-256: `D8736FF4735751A3EF70F5AC9925D4764D2788E69A10E6036AC2D2BD63AD2588`.
- Installed API 24 splits were selected from that APKS archive and the base master APK verified with the expected SHA-256 signing certificate fingerprint `D8:8E:CF:C6:1A:95:B5:8B:53:3E:38:96:37:8A:2D:70:89:4D:6E:F2:74:D8:C5:6C:9F:90:A7:7C:54:4E:8D:79`.
- These values are retained only as an audit trail. They are not final candidate evidence because app source changed afterward.

## Runtime repair history (superseded where noted)

- API 24 UI Automator exposed both visible login `EditText` nodes with empty content description, text, and resource ID. Maestro could not select a field, so the tester credential was never entered and no production authentication request was made.
- The app now wraps the existing field `Semantics` and `TextField` in `MergeSemantics`; the focused widget assertion proves the label and editable-text flag occupy the same semantics node.
- Focused command: `flutter test test/features/auth/login_screen_golden_test.dart --plain-name "names login fields and the password visibility action"` — PASS.
- `git diff --check` — PASS. At that checkpoint, a fresh signed AAB and full release validation were still required; the final evidence below records their later completion.
- Commit `8b9f681ea8bce2ed00151d7852eaef062dce7fc7` subsequently passed all applicable GitHub checks in run `33513135260`, built and validated, and produced an exact APKS archive that clean-installed on API 24.
- API 24 first launch stayed alive through 90 seconds on the fully rendered Welcome screen. Strict Logcat counts were zero for fatal exceptions, `E/flutter`, app AndroidRuntime errors, and package ANRs. The corrected onboarding Maestro flow passed.
- Login remained blocked before credential entry: the native API 24 UI tree still reported both `EditText` nodes with empty labels. This is final repair cycle 3 of 3; native non-floating `InputDecoration.labelText` values now provide the visible placeholder and editable-node semantics directly.
- Final-repair CI run `33517088967` passed 1,968 tests and failed only the pre-existing typography assertion that still read `hintStyle` after the intentional move to `labelStyle`. The narrow test-only expectation now follows the actual accessible field style; app code is unchanged by this correction.

## Final exact-AAB runtime evidence

- Final exact-head run `33519048862` passed all applicable GitHub checks at `9b5d0aa9`.
- `bundletool validate` passed for the final AAB. The APKS archive was generated from that exact AAB and installed as four device-selected splits on both API lanes.
- API 24 lifecycle evidence: background/resume preserved the PID; force-stop/reopen rendered the login screen; true airplane mode produced `Active default network: none`; reconnection restored a validated network; strict critical Logcat count was zero.
- API 24 Monkey evidence: smoke 100, balanced 500, navigation 300, touch-motion 500, and lifecycle 300 events all passed with successful relaunch and zero package crash/ANR markers. The repository harness's API-24 focus query was incompatible with that OS, so the same bounded arguments were run directly after Activity Manager proved ChronoSpark was resumed.
- API 37 first launch stayed rendered with one PID through the 90-second sample window. Google Play Services then killed that process at about 129 seconds while reloading `measurement.dynamite`; a second cold-start soak kept the same top-resumed PID for 180 seconds with no repeat or strict critical log match.
- API 37 onboarding, lifecycle, force-stop/reopen, true airplane-mode startup/reconnection, and the same five Monkey stages passed. The lifecycle seed was run alone after a system Battery Saver welcome dialog prevented the first attempt from starting any stress events.
- API 37 native UI inspection exposes field hints. API 24 does not; minimum API therefore controls the release verdict.
- Evidence root: `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901\build\release-test-evidence\final-9b5d0aa9`.

## Reproduction commands

```powershell
# Run from the clean candidate checkout with the required production variables
# already present in process/user scope. Signing sources remain outside the repo.
powershell -File scripts/build_android_aab_prod_guarded.ps1 `
  -SigningPropertiesPath "<external-key.properties>" `
  -SigningKeystorePath "<external-upload-keystore.jks>"

java -jar "<bundletool-all-1.18.3.jar>" validate `
  --bundle="build/app/outputs/bundle/release/app-release-prod-vc2026083003.aab"

# Generate APKS with signing passwords supplied securely in memory, never in this report.
java -jar "<bundletool-all-1.18.3.jar>" build-apks `
  --bundle="build/app/outputs/bundle/release/app-release-prod-vc2026083003.aab" `
  --output="build/app/outputs/bundle/release/app-release-prod-vc2026083003.apks" `
  --ks="<external-upload-keystore.jks>" --ks-key-alias="<alias>" `
  --ks-pass="pass:<secure-value>" --key-pass="pass:<secure-value>"

java -jar "<bundletool-all-1.18.3.jar>" install-apks `
  --apks="build/app/outputs/bundle/release/app-release-prod-vc2026083003.apks" `
  --device-id="<explicit-emulator-or-device-id>"
```

## Rollback and preservation

- Stable/main was not changed or merged. PR #83 remains open on `codex/production-candidate-20260901`.
- The original dirty launch-readiness checkout was not cleaned, reset, overwritten, or used as the build tree.
- Rollback is to close or leave PR #83 unmerged and uninstall the candidate package from disposable test devices. No production/store state was changed.
