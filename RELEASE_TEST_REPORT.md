# ChronoSpark Production-Candidate Release Test Report

Updated: 2026-09-01T07:15:00-05:00

Verdict: **NOT VERIFIED**

This report will cover the exact signed AAB built from the final candidate commit. A build success, debug APK, mock service, source inspection, or unrelated earlier artifact does not count as release evidence.

## Candidate identity

| Field | Evidence |
| --- | --- |
| Repository | `ghostheart5/fantastic-guacamole` |
| Checkout | `C:\Users\keegan radetski\ChronoSpark-production-candidate-20260901` |
| Branch | `codex/production-candidate-20260901` |
| Green base | `33a7e39dd3de49b219c0de750bb1fdd31e9d8573` |
| Candidate checkpoint | PR #83 repair pending exact-head GitHub rerun; prior green checkpoint `26172823fb16322b7a844118563ccf03fdfda5a5`; no AAB yet |
| Final tested commit | NOT VERIFIED |
| versionName / versionCode | `4.1.0` / `2026083003` (source preflight; artifact not yet built) |
| AAB path | NOT BUILT |
| AAB SHA-256 | NOT VERIFIED |
| Upload certificate SHA-1 | `8A:24:D7:BA:AC:AB:52:F0:A3:77:7D:D0:47:C9:07:96:2E:82:FA:A5` (local-to-Play match) |
| Build timestamp / command | NOT RUN |

## Current preflight

| Gate | Result | Evidence boundary |
| --- | --- | --- |
| Exact-main GitHub suite | PASS | Run `33481507007` at base commit only |
| Candidate exact-head GitHub suite | REPAIR ATTEMPT 1 OF 3 | Run `33506628774` passed 1,968 tests and failed the one receipt test whose fixed fixture expired at `2026-09-01T10:00:00Z`; the single focused test passes after a test-only relative-time repair. Exact-head rerun pending. |
| Isolated clean candidate | PASS at creation | Must be rechecked before build |
| JDK / Flutter / Android SDK / ADB / bundletool / Maestro | PASS | Tool presence and versions inspected |
| Release signing identity | PASS | Local keystore SHA-1 matches Play Console upload key |
| Production endpoint shape | PASS after secret repair | Real reconciliation endpoint reached |
| Backend reconciliation response contract | LOCAL FOCUSED PASS; LIVE BLOCKED | Workflow parser, release contract, and both secret guards pass. Attempt 2 was rejected before execution by production-environment branch protection; no backend call occurred. |
| Dedicated real test account | PASS | One isolated, auto-confirmed production Auth user; Windows Credential Manager storage; real sign-in HTTP 200; verification session revoked |
| Minimum API 24 environment | PREFLIGHT PASS | Image installed; `ChronoSpark_API_24` boot complete on SDK 24 with network connectivity |
| Newest available API environment | AVAILABLE | API 37.1 16 KB-page-size image and `ChronoSpark_API_37_1` AVD created; runtime boot pending |
| Exact AAB validation/install/runtime | NOT VERIFIED | No AAB built yet |

## Runtime matrix

| Device/API | Exact AAB-derived install | Maestro | Integration | Monkey | Human journeys | Logs/soak |
| --- | --- | --- | --- | --- | --- | --- |
| Minimum supported API 24 | ENVIRONMENT BOOT PASS | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Newest available API 37.1 | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| Connected physical phone | NOT ATTACHED | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |

## Required final evidence

- bundletool validation and APKS generation from the exact AAB
- AAB/APKS full paths and SHA-256 checksums
- installed package/version/signing evidence
- clean install, available upgrade, onboarding, auth/session/storage, navigation, real AI/SI, validation inputs, permissions, offline/network loss, lifecycle/process recreation, accessibility, R8-only behavior, crash/ANR/logcat, and bounded soak results
- exact live AI/API call count (current: `0` AI calls; `2` production Auth API calls)
- known limitations, reproduction commands, rollback instructions, and stable-branch preservation proof
