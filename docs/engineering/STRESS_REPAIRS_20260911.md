# Internal stress pass and replacement candidate 3028

September 11, 2026. Internal candidate 3028 was published and installed through Google Play. The repaired-source automated suites, installed repair checks and fresh Monkey retry passed their defined scenarios. Human testing found three additional usability issues (S9, S10, S11), so the app is **not production-ready**. Production publication is excluded.

## Baseline and confirmed findings

The Moto Play installation was `4.1.0+2026083027`, source `faa512ea2e35f229e02da6cdbbcb183f257031c1`. Tests used clearly labeled `STRESS3027` demo records while preserving the existing signed-in level-20 profile.

| Finding | Reproduction and repair |
|---|---|
| Short task duration | Creator offered no duration below 15 minutes. Added 5 and 10 minutes and corrected the singular hour label for 90 minutes. |
| Goal creation history | A confirmed Creator goal appeared in Goals but had no creation event in Timeline. Added idempotent goal creation/undo history without changing the canonical goal ID or awarding extra XP. History failures do not undo a successful goal save. |
| Stale selected-note focus | A retained bookkeeping note outweighed a new explicit family-budget request. Current matching task/goal terms now take precedence unless the person explicitly asks to use the selected note. Constraint words do not identify a task. |
| Requested step duration | A 10,000-task fixture selected the named target but ignored the duration in “Give me a five minute step.” Added request-verb-qualified short-step/session duration parsing; numeric and hyphenated wording are covered. |
| Home task action | “Open TASK” opened blank Creator even when a saved task was displayed. It now opens that task's editor, shared with Timeline; Cancel preserves the task. The Home save rejects account changes while the dialog is open. |
| Rhythm cadence copy | Creator displayed “3 times per weekly.” Labels now use day/week/month. |
| Account-transition runtime errors | All 11 hosted Maestro flows completed their assertions, but the strict log gate found 23 provider errors during logout/account switching. SI and prediction readers now report unavailable evidence before protected storage is ready and discard stale asynchronous account results. Genuine failures in a current account remain errors. |
| Saved capacity wording | Saved Person Context saying “five minutes” made Home claim a 25-minute cap. The shared parser now recognizes spelled and hyphenated minute values, and preserves positive limits below five minutes through the decision engine. |

## Evidence and boundaries

- Fresh baseline CI [34623980203](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34623980203), database [34623983121](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34623983121), and native/Windows/strict-16KB [34623986081](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34623986081) completed successfully. Artifact archives were independently SHA-256 checked. Linux Flutter evidence contains 2,888 passing cases; Windows full-suite evidence contains 2,891, with no skipped cases or reported test errors. These certify the baseline source, not this repair commit.
- Baseline Maestro [34623988287](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34623988287): 11/11 UI flows, zero JUnit failures/errors/skips, but **overall FAIL** due to the account-transition runtime errors. Do not reinterpret this as a passing release gate.
- Moto energy/fatigue endpoints and opposite combinations were saved and read back on Home and Trajectory, then cleared. Home and Trajectory retained the same values after recalculation.
- 100 targeted rapid navigation events completed, with endpoint checks and memory samples. This is not random Monkey coverage.
- A 1,152-character note was entered in checked chunks, previewed, saved, and undone. An earlier unpaced ADB text burst inserted only a prefix; this was an input-automation limitation, not established app data loss.
- A test rhythm was created with a weekly target of three, marked complete once, paused/resumed, and renamed. Duplicate completion was disabled. Existing rhythms were unchanged.
- One newly created test task was completed: profile changed from 36,137 XP / 1,445 completions to 36,162 XP / 1,446 completions; level 20 was preserved. Home selected another active task and showed updated learning feedback.
- SI selected the budget task from a real-life query. An adversarial request to delete goals and buy credits was rejected as unsupported; the wallet remained at 417 credits. Appearance and audio switches changed and were restored.
- Google Play showed the license-test disclosure and test payment methods. A monthly subscription attempt using the always-declines instrument was declined. Final entitlement readback and subsequent billing cases remain part of the ongoing device matrix.

Detailed local observations, regression output, hashes and runtime logs are under `test-results/stress-3027-20260911/`. The long Maestro artifact was retained under `C:/cs-evidence/stress-3027/` to avoid Windows path limits. Existing release artifacts remain preserved.

## Repaired-source validation and internal delivery

Source `6e1f7470b95c2d9925e0d78cdcff58d479ae5d8e` is committed and pushed. Tooling identity is separately `a529a415b1201aef2c0da687098d0e612200d8d9`.

| Gate | Independently read evidence |
|---|---|
| [CI 34630337604](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34630337604) | 2,908 Flutter tests, 15 QA configuration tests, 48 Windows visual/widget tests, 17 Windows launcher tests, and eight Linux integration outer groups passed. |
| [Database 34630339934](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34630339934) | 142 edge-function tests passed; zero failures/errors. |
| [Post-build 34633530522](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34633530522) | 2,911 Windows full-suite tests plus 15 configuration tests; native matrix 15/15 across five independent hosts and two viewports; no failures/errors/skips. |
| Strict 16 KB runtime, same post-build run | Actual 16,384-byte guest pages, compatibility mode disabled; AAB-derived APK cold launch and complete onboarding-to-login handoff passed, with no configured fatal markers. Disposable signer: this is not Play-signing or billing proof. |
| [Maestro 34630362723](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34630362723) | All 11 journeys passed, zero failures/errors/skips and zero fatal markers. Account-transition fatal errors from the baseline were absent. Overall workflow failed in the subsequent Monkey phase; do not label the whole run passed. |
| [Fresh emulator retry 34635175059](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34635175059) | Five smoke flows and all five Monkey variants passed: smoke100, balanced500, navigation300, touch-motion500, lifecycle300; 1,700/1,700 events, zero fatal markers, all cold relaunch checks passed. Original failure retained. Artifact SHA-256 `307e512c7207632e1bab963e0d4c0135d6c823c5663ad9c8f32d5b597e826657`. |
| Bounded decision-engine exploration | 60 deterministic randomized scenarios, each with 1,000 tasks, passed active-task selection, valid duration, finite confidence, deterministic output and no input mutation checks. Separate from canonical test counts. |

Artifact archives were checked against GitHub SHA-256 digests before reading the raw evidence. Index: `test-results/stress-3027-20260911/repaired-artifact-readback.json`. Windows full archive digest: `32ad60ef4127697091250d6c055d03ea21a9cbb4fdbd82442d0e25160ac994da`. Native matrix digest: `f902222d2b93547b9e7b1309fb8af04007e5d836a60f19f66bac228676b71129`.

[Signed build 34631847466](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34631847466) produced version `4.1.0+2026083028`, package `com.ghostheart5.chronospark`, target SDK 36. AAB SHA-256: `9c55a8e993ac83e8d0bd29f3d740f562d4bad44489e2828b2a8bc842e0ad5c45`. Independent bundle/signing/native-alignment/legal-notice inspection passed. Play accepted the mapping file and native debug symbols. Full symbols remain unavailable for the three vendor DataStore libraries, as recorded by the inspector.

Play Console internal release **30** read back as **Available to internal testers**, latest version **2026083028**, September 11 at 1:51 PM. The Moto subsequently read back version **2026083028**, installer **com.android.vending**, update time **13:55:27**. No uninstall or local-data reset was used. Production was not published.

## Additional human and billing evidence

- Preserved owner profile: level 20, 36,162 XP and 1,446 task completions. Offline cold restart retained that profile and Timeline history; the absence of a default network was verified, then original connectivity was restored. See `offline-restart-result-v3.json`; two earlier infrastructure attempts are retained and are not app failures.
- Monthly always-declines license instrument was rejected without granting access. Always-approves purchase was acknowledged and activated access. Restore did not duplicate the initial allowance.
- Synthetic 3-credit and 4-credit requests completed. Retrying each charged zero additional credits. Disabling external-AI consent invalidated the quote and disabled confirmation; the original enabled consent was restored before a new quote.
- A pending 100-credit slow-decline purchase granted nothing, including after restart. A new pending 100-credit slow-approve purchase granted exactly 100 only after completion. Restore did not duplicate it. The wallet then held **790 = 293 included + 497 purchased**. No real payment instrument was used.
- **Renewal observation subsequently passed:** six `rtdn_renewal` allowance grants, notification type 2, were recorded from 19:08:54 through 19:11:47 UTC. The first reset 293 included credits to 300 (delta 7); the next five reset to 300 with delta zero. They did not accumulate another 300 credits per notification. Subsequent expiration processed at 19:11:58 UTC. Server and app both showed expired access and **517 = 20 free included + 497 purchased**, with lifetime spending unchanged at 58. Earlier missing-renewal observations were real at that time; later evidence closes the runtime observation gap. It does not establish why Google generated the test events later than initially expected.
- Notifications changed unread count from two to one after opening an unread item. Progress-sharing preview showed the correct level and XP; sharing was canceled. Privacy, terms and native license content opened. Support mail was reviewed and discarded without sending.
- Installed 3028 checks: saved spelled-minute context reports a five-minute cap on Home and Trajectory; Home Open TASK opens the existing named task editor, and Cancel returns without changing the task. All four energy/fatigue pairs passed again and were cleared. Momentum remained BUILDING across Home, Trajectory and recalculation.
- A five-minute grocery task was saved and linked to the test family-budget goal. Planner selected it for the explicit grocery query, returned a five-minute step, and cited the saved context. The older bookkeeping note was then explicitly selected; a new grocery request still selected the grocery task and respected five minutes. Emotion consent was disabled, so the selected anxious chip was correctly excluded from planning evidence; no consent setting was changed.
- Goal creation and immediate undo both appeared in Timeline. A separate late undo correctly reported expiry and preserved its goal. The weekly rhythm draft read `3 times per week`. The test capacity item was withdrawn and deleted; review returned zero context items and Home removed the capacity explanation.
- Completing the new grocery task on 3028 added exactly 25 XP and one completion: final profile **level 20, 36,187 XP, 1,447 completed tasks, two-day streak**. Its learned fit changed from 50% to 60%, and Home selected another active task. A final cold restart retained the new progress. Another 100 targeted rapid navigation events passed in 29.55 seconds. The temporary selected note and emotional check-in cleared on cold restart; original records and consent settings were preserved.
- The complete owned filtered runtime log and the separately marked 3028 interval contained zero configured fatal exception, app ANR, unhandled exception, RenderFlex overflow or categorized-error markers. Log SHA-256 `1c7f052573074d293d9a0eba632655099219ae9e2485efa76e0335343488a416`; 278,773 bytes. This is a filtered collector, not proof that every Android log category was clean. The collector was stopped after verifying its exact PID/ADB command ownership. Hosted emulators stopped in workflow cleanup.

## Open findings and remaining acceptance work

1. **B1 — resolved observation gap:** automatic renewal/refill and expiration were subsequently observed, as detailed above. Keep the initial gap and final successful readback together; do not present the earlier interim state as current.
2. **S9 — paywall scroll:** background authority refresh unmounts the plan list and returns lower-plan inspection to the top. The Show-all selection persists. Reproduced on 3027; unchanged code remains in 3028.
3. **S10 — support mail encoding:** Gmail renders spaces as plus signs in the generated subject/body. Both support and account-deletion mail builders use the same `Uri.queryParameters` construction. Only support was opened; its draft was discarded. Unchanged in 3028.
4. **T1 — retry passed, original failure retained:** smoke 100, balanced 500 and navigation 300 events passed in the first run. Touch-motion injected all 500 events with zero fatal markers, but the restarted app could not regain focus from `SystemUIDialog` within 30 seconds; the fifth variant did not run. The fresh-emulator retry passed all five variants and all relaunches, as detailed above. This does not erase the first run or establish that the system-dialog interruption can never recur.
5. **S11 — SI context disclosure/relevance review:** the header claims one relevant Person Context item is cited, while the expanded response reports `USER-REPORTED CONTEXT: None identified` and does not explain the five-minute constraint. An ambiguous family-budget/before-school-pickup query ranked the older bookkeeping task; explicitly naming grocery totals selected the grocery task. The ranking difference is a quality observation, not evidence of an unauthorized mutation. The contradictory context disclosure needs repair/review. Evidence: `repaired-si-answer.json`, `repaired-si-evidence-lower.json`, `repaired-si-evidence-sources.json`, `repaired-si-explicit-answer.json`.

The three open findings need focused repairs and regression/device checks before a new clean candidate is accepted. Live annual/grace/hold/pause/chargeback and induced backend-outage scenarios are not all freshly demonstrated by this pass. Destructive account/reset tests run in isolated fixtures; the owner profile was preserved. No claim covers every possible input, device, service failure or future execution. Machine-readable summary: `docs/engineering/STRESS_REPAIR_RESULTS_20260911.json`.

Qualified external review, reviewer-device access and the separate public-paid/store declarations remain governed by the existing release-gate record; an internal build does not close those production gates.
