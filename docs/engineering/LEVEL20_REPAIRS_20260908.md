# Level-20 findings: repairs and screenshot preparation

The eight findings from `LEVEL20_ENDURANCE_20260908.md` have corresponding source repairs and host regression coverage. The final full Flutter run passes 2,587 tests. Repaired Android runtime verification is pending the next build; the installed Moto still runs Play build 4.1.0+2026083018. In particular, DEMO-05's original intermittent tap symptom has not been isolated to a single cause and must be rechecked on the repaired build.

Checkout: `ChronoSpark-app-only-priority2`, branch `fix/aab-prebuild-cleanup-20260905`, base commit `bacf2aa739fd44fd1e1c357bed959984abb7b089`. The subsequent authorized commit/rebuild selects `4.1.0+2026083019` and the existing private-cohort internal billing configuration. Build provenance will be recorded with the resulting AAB. These host results do not establish installation or Play delivery of the repaired version.

## Repair mapping

| Finding | Source repair | Regression evidence |
|---|---|---|
| DEMO-01: unnamed Creator inputs | Title, description, and note-body fields expose persistent semantic labels while retaining normal editable-field semantics and keyboard behavior. | `dynamic_form_test.dart`: labels remain available after typing; existing four-mode and narrow-width form tests pass. |
| DEMO-02: technical confirmation details | Removed account binding, domain revision, diff digest, confirmation token, and result revision from normal Creator cards. The result says `CREATION SAVED` and reports a readable change count. Exact before/after review, expiry, confirmation safety, idempotency, and Undo remain. | `creator_handshake_screen_test.dart`: sensitive/technical labels absent, exact review remains, confirmation saves once, Undo works. The matching Maestro receipt assertion now uses `CREATION SAVED`. |
| DEMO-03: stale SI header | The SI evidence snapshot now watches task, goal, milestone, and Timeline state, so domain changes invalidate the cached header within the current account session. The read-only gateway remains the source of evidence. | `si_v2_snapshot_refresh_test.dart`: a newly saved goal appears without restart and all four source invalidations trigger fresh reads; existing SI and account-boundary tests pass. |
| DEMO-04: inaccessible goal details | Each goal card has an explicit semantic container and child nodes; Share and Expand/Collapse controls name their goal. | `goals_screen_test.dart`: goal title is exposed in semantics and controls carry the correct title. |
| DEMO-05: guidance tap with no immediate response | Planner marks the request busy synchronously before the first async safety check, unfocuses input, ignores repeat dispatch, checks mounted state after the safety route, and releases the busy state on cancellation or error. | `smart_planner_screen_test.dart`: two same-frame dispatches cause one request, the button is disabled during that request, and the result renders after one completion. Existing failure, timeout, emotional-safety, and retry tests pass. Original Android tap intermittency still requires rebuilt-device verification. |
| DEMO-06: saved note opens blank Creator | Nexus passes the selected saved note ID to a dedicated note reader. The reader resolves current account state, displays title/body, handles missing/loading/error states, and never creates a duplicate. Empty-note navigation still opens Creator. | Nexus routing widget test opens exact saved content; `note_detail_screen_test.dart` verifies selected title/body and removes them when the account's note list changes. |
| DEMO-07: old receipt above new Planner draft | `Use this plan` clears the previous handshake result before staging the new draft. Creator also suppresses an old result whenever a Planner draft is present. | Creator widget test confirms a new unsaved draft has no prior receipt/Undo controls and performs no extra save; existing Planner-to-Creator and handshake tests pass. |
| DEMO-08: initial-state identity copy at level 20 | When identity patterns are unavailable in this version, Profile shows `Progress recorded`, the actual completed-task count, and the level/XP boundary. It no longer promises that more task completions will enable an unavailable feature. Unobserved percentages remain hidden. | Profile tests cover fresh and established accounts, recorded completion counts, and absence of the misleading completion prompt. |

## Validation

Evidence logs are in `test-results/level20-endurance-20260908/`.

| Command/check | Result | Evidence |
|---|---|---|
| Focused affected-screen/provider tests, followed by corrections and reruns | Pass for all affected cases. Initial failures included new-test semantic-handle cleanup and an outdated source expectation; these were corrected. | `repair-focused-tests-rerun.log`, `repair-nexus-final.log`, `repair-failure-rerun.log` |
| `flutter test --no-pub --concurrency=2 --reporter expanded` | PASS, 2,587 tests, exit 0 | `repair-full-flutter-final.log` |
| `flutter analyze --no-pub --fatal-infos` | PASS on repaired source; final readback recorded separately | `repair-analyze-final.log`, `repair-analyze-readback.log` |
| `dart run tool/validate_maestro_flows.dart` | PASS, 28 Maestro files | Tool output; updated receipt selector included |
| `powershell -NoProfile -ExecutionPolicy Bypass -File check_architecture.ps1` | PASS, 750 Dart files, no architecture contract violations | Tool output |
| `git diff --check` | PASS; Git reports only normal Windows line-ending normalization advice | Tool output |
| Screenshot file checks | PASS, eight 1080x1920 RGB JPEGs, 4,492,780 bytes total at packaging time | `artifacts/google-play/level20-20260908/manifest.json` |

The initial broad run had 2,583 passes and four failures: two expectations updated for the new behavior and two Windows fixture timing failures under concurrent load. All four passed a serial rerun; the final lower-concurrency full run passed without failures. Host tests for the monkey-runner guard exercise fake probes only; no monkey events were sent to the phone. Expected simulated failures in negative tests must not be confused with failing test results.

The first Nexus golden differed because the newly inserted navigation test warmed its background image cache before a historical first-render comparison. Keeping the existing golden tests first preserved the reviewed baselines; all three golden widths pass without updating image masters.

## Google Play screenshot package

Review gallery: `artifacts/google-play/level20-20260908/index.html`.

The eight raw captures cover Profile, Nexus, Smart Planner, SI Console, Creator, Goals, Timeline, and Progression. They are direct, high-quality JPEG captures from Android UIAutomator, with matching hierarchy snapshots, capture times, build numbers, and hashes. No app UI or XP was generated or composited. The futuristic treatment is the actual ChronoSpark interface; the gallery adds presentation around the original files only.

The Moto was temporarily set to a 1080x1920 display for true 9:16 rendering, and notification icons were hidden using its existing System UI demo facility. Physical 1080x2460 size and notification visibility were restored afterward. Actual device time was not changed.

The profile remains level 20 / 36,100 XP with 1,444 prior completion events. One synthetic task, `Plan the next creative milestone`, was created through the normal confirmation flow, with a 25-minute estimate, priority 4, and a creative-project description. It remains active for repeatable screenshots and does not award XP. SI recommended that task; Planner answered a 25-minute request with a 20-minute best-fit option. Original goals/history were retained.

These are **installed-3018 previews**, not repaired-release marketing proof. Recapture the final set after the next Play update and runtime checks, especially the changed Profile and Creator surfaces. Do not upload these previews as proof that the repairs are already installed. Phone screenshots do not establish tablet, Chromebook, TV, Wear, or XR behavior; additional device-specific assets require the corresponding supported layout/device.

Reference checked September 8, 2026: [Google Play preview-asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en). Google allows up to eight screenshots per supported device type and recommends high-resolution 9:16 portrait screenshots for phone promotion. The package uses RGB JPEGs and the actual app experience.

## Next-build checks

1. Update the existing Play installation without resetting this level-20 profile. Verify the installed version before calling any device result repaired-build evidence.
2. Check Creator input labels with Android accessibility, exact confirmation/Undo, and absence of technical identifiers.
3. Create and complete a bounded synthetic task; check SI header counts without restarting. Open the saved note and confirm its content.
4. Enter Planner with both closed and open keyboard states, request guidance once, exercise slow/error/retry paths, and check a new draft after a prior Creator confirmation.
5. Verify goal titles/actions in Android semantics and accurate Profile progress copy at level 20. Check persistence after cold reopening.
6. Recapture and visually review the final screenshot set from that verified build. Preserve this level-20 profile when arranging another fresh progression endurance run.

No claim of an error-free future endurance run is made from host tests or the old installed build.
