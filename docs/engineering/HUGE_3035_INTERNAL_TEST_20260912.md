# ChronoSpark 3035 full internal test repeat

Campaign date: September 12, 2026 (Central; some evidence is dated September 13 UTC).

Subsequent checkpoint: the six findings now have [local source repairs and passing host regressions](REPAIRS_3035_FINDINGS_20260912.md). The original installed-build observations below remain the historical evidence; a rebuilt-device confirmation is still required.

**CAMPAIGN COMPLETE. Automated lanes passed; exploratory acceptance FAILED with six reproduced application findings open.** Passing automation does not override the live-use findings below. This report concerns internal testing, not Google Play production approval. Final device evidence verified at 01:19:23 UTC on September 13 (8:19 PM Central on September 12).

## Exact target and preservation

The installed Moto Android 13 package is `com.ghostheart5.chronospark`, version `4.1.0+2026083035`, delivered by `com.android.vending`. Its source is `3a2118ac2a4e523d1df962ee7290085d5e7ca310`; checkout HEAD `f4dd5cc2c7f43af73ff0776ff9a3c33cf9c0041b` adds two delivery documents only. Application and backend source are unchanged between these revisions.

Candidate build [34724793839](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34724793839) produced AAB SHA-256 `0c527ab4b1ebff2fb636b3678f48b079e0e735dd53e0383ab170f7cf37248fb7`. Test tooling is separately pinned to `4b21abe9033d8d1fa8bbe68a0b0074cecd16bca2`.

The existing authorized Moto profile was preserved. No app uninstall, storage clear, account reset, direct XP edit, owner-phone Monkey or production publication occurred. Hosted QA/native tests used disposable emulators. The live journey used synthetic household/bookkeeping data through ordinary app controls. It is agent-driven exploratory testing with UI evidence, not independent human-participant UAT.

## Fresh automated evidence

| Lane | Fresh result | Evidence |
| --- | --- | --- |
| Canonical CI | PASS: 2,946 Flutter tests; 15 QA configuration; 48 Windows visual/widget/golden; 17 launcher; 8 Linux app-root integration. Zero failures, errors or skips in independently parsed reports. Static policy job also passed. | [34724066811, attempt 2](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34724066811), `ci-independent-readback.json` |
| Coverage | 36,198 of 46,848 instrumented lines hit, 77.2669%. This is line coverage, not scenario completeness. | Downloaded `lcov.info`, `coverage-readback.json` |
| Backend | PASS: 350 SQL assertions in 13 files; 142 Edge Function tests, zero JUnit failures/errors. Schema lint and disposable backend cleanup passed. | [34726636983](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34726636983), raw backend log and JUnit |
| Windows full repeat | PASS: 2,949 full tests plus 15 QA configuration tests. These overlap canonical CI and are not additive unique coverage. | [34726678023](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34726678023), `windows-independent-readback.json` |
| Native integration | PASS: 15 cases across five distinct host boot IDs: startup 1, auth 6, persistence 1, Planner learning identity 1, second-size auth 6. Raw instrumentation counts, terminal success, report/manifest hashes and collector cleanup verified. | Same post-build run, `native-independent-readback.json` |
| Strict 16 KB | PASS: actual candidate AAB-derived APK, raw page size 16,384, compatibility disabled, strict linker mode, onboarding 1/1, no skips, owned-host cleanup. This does not prove Google Play billing. | Same post-build run, `16kb-independent-readback.json`, raw properties/JUnit |
| Decision-volume regression | PASS: 60 deterministic scenarios of 1,000 tasks each, valid decisions/blocks, finite confidence, stable repeat and unchanged inputs. | `decision-stress.jsonl`, successful process exit |
| Maestro and bounded Monkey | PASS on fresh attempt 2: 11/11 journeys in verified order, zero failures/errors/skips; five Monkey variants, 1,700 events, verified raw event counts and log hashes, successful new-process relaunches, zero configured fatal markers. | [34726628603](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34726628603), `maestro-independent-readback.json` |

Maestro/Monkey used the same exact-source QA APK, SHA-256 `95ABDD2DB4474CFDFC6150EB5BA4177A5039DBE5192F8617299D8422623FE2DB`, on a disposable Android 15/API 35 emulator. The eleven-case sequence includes account isolation, the learned lifecycle and immediate restart readback. Maestro's retained sanitized log and all five full Monkey logs were independently rescanned. Its complete raw log was scanned in CI before sanitization, per the capture receipt; it is not retained locally. Monkey variants were smoke 100, balanced 500, navigation 300, touch/motion 500 and lifecycle 300.

Attempt 1 failed before app tests because the disposable Google launcher ANRed during first boot. The strict readiness guard rejected that guest; no app journey or Monkey result exists for that attempt. Its failure, last-ANR and readiness evidence remain retained. The passing retry did not weaken assertions or change source.

All local campaign evidence names below are relative to ignored `test-results/huge-3035-20260912/`. Raw UI/account content remains local and is not included in this document.

## Reproduced application findings

| ID | Severity and trigger | Observed result and consequence | Evidence |
| --- | --- | --- | --- |
| F01 | Medium: ordinary SI questions about saved data | `What are my current goals?`, `What tasks do I have?`, `What milestones do I have?`, and a natural school-pickup/five-minute question are rejected as unsupported. Matching saved records exist. The control next-action question and a more specific bookkeeping paraphrase work. This is one query-understanding defect with multiple manifestations. | `si-school-answer`, `si-control-answer`, `si-goals-answer`, `si-tasks-answer`, `si-milestones-answer`, `si-next-answer` XML/PNG |
| F02 | Medium: Planner request explicitly includes any break within five minutes total | Minimum option proposes five minutes of setup plus a five-minute break while claiming all options fit the five-minute limit. A parent following it would exceed the stated pickup constraint. No proposal was saved. | `planner-five-input`, `planner-five-answer`, `planner-smaller` |
| F03 | Low: Creator Daily Rhythm target control | The increase button is a solid cyan circle with no visible plus icon. It works and exposes an accessibility label; the decrease button has a visible minus. Confirmed in two separate rendered screenshots. | `rhythm-form.png`, `rhythm-target-two-final.png`; `dynamic_form.dart` filled increase icon |
| F04 | Medium: selected note linked to an active task and a rhythm skipped this week | Planner fixates on the skipped rhythm and repeatedly asks for another commitment even after the user explicitly names the active task and says to leave the rhythm unchanged. Removing only the rhythm link resolves the loop: the same request plans the correct task and cites the note's seven-minute limit. | `note-links-save`, `note-guidance`, `note-followup-answer`, `note-explicit-task-answer`, `note-workaround-guidance` |
| F05 | High task-integrity concern: Energy 0% changes Nexus guidance to recovery | Recommendation says to take a recovery break, while enabled Complete remains bound to the original bookkeeping task, which is absent from the displayed recommendation. Source callback confirms it invokes that task's completion. The unrelated task was deliberately not completed. | `energy-zero-home`, `vitals-0-0-home`; `lib/features/nexus/ui/nexus_screen.widgets.dart` callback around line 560 |
| F06 | Medium evidence/wording defect: no saved milestones | Progression's top section correctly says no milestones are recorded, but the lower progress review says milestones are on-track with 100% health. The advisor branch uses health/overdue without a recorded-milestone count. Empty evidence should remain unmeasured rather than imply demonstrated progress. | `progression-live`, `progression-bottom`; `lib/state/providers/advisor_provider.dart` around lines 187–212 |

No application repair was made during this test campaign. These findings require correction and targeted regressions before accepting a repaired build.

Repair priority: first make the Nexus completion action agree with the actual displayed decision (F05). Then cover SI paraphrases (F01), aggregate work-plus-break limits (F02), explicit active-task selection despite a linked skipped rhythm (F04), and empty milestone evidence (F06). Finally correct the filled increase icon contrast (F03). Each repair needs the exact failing scenario repeated on the next installed build as well as a focused regression where appropriate.

## Realistic live journeys

Created exactly once through Creator preview/confirmation:

- Goal: **Finish my weekend bookkeeping catch-up**, target September 13, with short study/receipt steps before Sunday dinner.
- Task: five-minute receipt sorting, linked to that goal. Canceling a draft edit preserved the original. Saving the title **Sort grocery receipts and record the total** updated Home immediately. This new task was completed once through its explicitly named action.
- Note: **Weekend bookkeeping time limits**, with seven minutes after lunch, school pickup at three, paper receipts, one worked example, and no late-night session. Body and links persisted on reopen. Its task/goal links remain; the rhythm link was removed only to establish the F04 control. Temporary Planner sharing was then revoked.
- Daily Rhythm: **Check grocery receipts after lunch**, weekly target two. Daily/monthly/weekly target wording, increase/decrease, pause/resume and weekly skip were exercised. After skipping, both outcome buttons were disabled, preventing a duplicate weekly result. It remains active and skipped this week.

Timeline found exactly one creation event for the note. The goal appeared as the upcoming dated priority. Home reflected the edited task and Planner feedback. Forecast simulations did not award XP; the actual new task completion did. After force-stop and normal launch, the signed-in profile retained level 20, XP **36,237** (from 36,212), completed tasks **1,449** (from 1,448), and streak **3 days** (from 2).

### Planning, SI, vitals and voice

- SI next-action control returned saved bookkeeping evidence; unsupported weather correctly refused without appending an unrelated task. Goal-attention response reported a tie rather than inventing a higher priority. F01 captures failed ordinary paraphrases.
- Smart Planner used school-pickup/time constraints, smaller/different-approach feedback, explanations, evidence and a temporarily selected note. The note workaround correctly cited the seven-minute limit. F02 and F04 capture output failures.
- All nine emotion states were selected/read back, then cleared. Global emotion-sharing consent stayed off and cross-surface sharing stayed disabled; evidence correctly excluded emotion. Enabled sharing was not exercised.
- Energy/fatigue/Clarity pairs passed: (0,0,100), (100,100,0), (10,90,10), (90,10,90). Home's Clarity calculation and Energy readbacks were checked. Trajectory's Energy matched; it did not expose a separate Clarity value in the observed screen. F05 concerns the recovery action, not the percentages.
- Home and Trajectory Momentum agreed at 7, 30 and 90 days. Original seven-day horizon restored. Both Energy and Clarity were cleared back to unmeasured/not checked.
- Forecast model previews exposed conditional assumptions and withheld capacity/date claims without availability. Review adjustment opened Planner without saving a schedule.
- Speak exposed Stop speaking; Stop removed the speaking state; repeat speech did not ask for app approval again; leaving the route cleared speech state. These are UI-state observations, not independent audio recordings.
- Microphone while-in-use permission was granted. A later press started recognition without repeating that permission. Recognized text stayed editable and unsent and was discarded. No controlled dictation accuracy or audio-output quality claim is made.

### Navigation and commerce

The pre-spend server wallet remained 514 credits after the local SI/Planner journeys: included 17, purchased 497, lifetime spent 67. The short quote explicitly cost 3 credits. Confirming returned a real provider reply and changed the wallet to 511, included 14, purchased 497, lifetime spent 70. Retrying the same request returned an already-completed message with no second debit. A scoped live backend aggregate independently confirmed exactly one AI transaction totaling -3 for the campaign.

The longer quote cost 4 credits and was not confirmed. Turning external-AI consent off removed the quote and disabled quote/retry actions. Original consent was restored to on, with the old quote still absent. Emotion and saved-preference consent remained off. Receipts: `credit-quote-short`, `credit-spend-result`, `credit-retry`, `credit-long-quote`, `credit-consent-disabled-check`, `credit-consent-restored`, `commerce-before.json`, `commerce-after.json`.

The paywall loaded monthly $7.99 and annual $69.99 plans, each displaying a monthly 300-credit allowance. Show all plans exposed the optional 100-credit $2.99 nonrecurring product. The monthly native Play sheet displayed **Test card, always approves**, explicitly said no charge, and showed accelerated five-minute renewal terms. Back canceled the purchase; the app explicitly reported unchanged access. Restore reported no active purchases, consistent with the expired accelerated annual subscription and Free server tier. Final UI wallet remained 511. No subscription or credit-pack purchase was confirmed in this campaign.

Progression's level, completed count and streak matched Profile after restart. It displayed conditional history and elevated pressure; F06 records its contradictory empty-milestone summary. Share/export to another person, account deletion and owner sign-out were not performed.

The final navigation endurance run **passed 100 targeted actions and 100 route readbacks**: 25 complete Nexus/Trajectory/Timeline/Profile cycles. All Profile observations preserved the expected XP. Three PSS samples were 232,062, 235,484 and 231,344 KB; this bounded sample shows no monotonic growth and is not a lifetime leak test. Receipts: `navigation-final-*`, `navigation-results.json`, `device-final-readback.json`.

One earlier attempt stopped after 34 successful route readbacks when a system Home/Recents gesture occurred before the next automated tap. Android events record `userLeaving=true`; the same app PID remained alive, no new app exit was recorded, and reopening brought the existing Trajectory task forward. A second attempt stopped after nine successful readbacks when wireless ADB went offline. Both interrupted segments are retained and are not reported as uninterrupted passes. The successful final run used new evidence names. An initial helper assertion also expected the wrong Trajectory heading; correcting that observed-label assumption changed no app code or product assertion.

## Evidence closeout and limits

The phone was left on Nexus with the original bookkeeping task intact, level 20, Energy unmeasured, Clarity not checked, Momentum BUILDING, and no observed speech/recording state. Final Profile, Home, package and Android exit history were retained. The original collector exited at the wireless interruption. Replacement collector PID 84808 was stopped only after verifying its executable, selected Moto serial and logcat command; independent process readback found it absent. No other device, ADB server or unrelated process was stopped.

The two retained filtered runtime logs contain 3,235 lines and 300,557 bytes. Independent scans found zero configured app-fatal, Flutter/framework/provider-error, ANR or overflow markers. There is a capture gap from 20:02:32 local to collector restart at 20:05:05. These are bounded captured-log results, not uninterrupted whole-campaign proof. The final navigation run was covered by the resumed collector.

Log SHA-256 values:

- `runtime.log`: `4eb1b76639a2f7fc157077494e10f4063989fd3f54d02b8a39bdcdf4284a7a0b`
- `runtime-resumed.log`: `9a2139e35bc0085c621ecf628082929a9466858521566f1254d187468e6143ec`

Source/backend files were not edited, committed, rebuilt for distribution or published during this campaign. Existing unrelated listing work was preserved. The six application findings prevent an all-pass result despite the completed automated lanes.

The full Google Play renewal/grace/hold/recovery/pause/pending-instrument and cross-account ownership lifecycle was not freshly rerun here. The installed-device commerce scope was catalog/sheet/cancellation/empty restore, actual credits, idempotent retry and consent withdrawal. Historical lifecycle results are not recounted as current-build passes. Enabled emotion sharing, independent audio-quality measurement, destructive account deletion, every accessibility service/device, offline multi-device conflict recovery and independent participant UAT also remain outside this bounded repeat. QA account-isolation and native auth tests do not replace those deployed-account journeys.
