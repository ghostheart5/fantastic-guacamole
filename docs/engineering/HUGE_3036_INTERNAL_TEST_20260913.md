# Build 3036 internal testing repeat — 2026-09-13

Status: **testing session concluded; six repaired findings pass their physical-device rechecks; two new application findings remain open.** Functional suites passed. The Monkey matrix is **FAIL/incomplete** after an Android SystemUI dialog prevented the fourth variant's focus-recovery check; the fifth variant was not run. Explicit microphone-stop timing is inconclusive. This is not an all-pass or production-readiness declaration.

## Exact delivery

- Source: `d09431b783593c504d9f9c7d15b47c6a5eea17d5`, branch `fix/aab-prebuild-cleanup-20260905`, version `4.1.0+2026083036`.
- Signed candidate run: [34744587828](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34744587828).
- AAB SHA-256: `e8b64ac7826e7bc1555f61019bca082bb11213021d8e6e6c001ab307e8cbc95f`.
- Google Play internal release 37, `2026083036 (4.1.0) - Planner and SI repairs`, independently read back as available to internal testers. No production publication.
- Moto Android 13, hardware `ZY22G665VG`, user 0: Play-installed version 2026083036 confirmed; installer `com.android.vending`, update 2026-09-13 02:46:08 Central. Update preserved the account and existing data.
- Raw local proof: `test-results/huge-3036-20260913/`; candidate verification: `test-results/release-3036/` and `artifacts/releases/4.1.0-2026083036-internal-billing-verified/`.

## Automated checks

Counts describe separate test lanes and overlap; do not add them as unique test cases.

| Lane | Result | Evidence |
| --- | --- | --- |
| Exact-source pre-build CI | PASS: 2,958 Flutter; 15 QA configuration; 8 Linux integration; 52 Windows golden/widget; 17 launcher checks; analysis, format and release controls | [34744053028](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34744053028), downloaded manifests in `test-results/release-3036/` |
| Post-build Windows suite | PASS: 2,961 full tests and 15 QA configuration, zero failures/skips | [34745859370](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34745859370), `windows-independent-readback.json` |
| Native matrix | PASS: 15 cases across five distinct hosted boots, exact source/candidate identity verified | Same post-build run; `native-independent-readback.json` |
| Strict 16 KB release runtime | PASS: AAB-derived onboarding, 16,384-byte pages, compatibility mode disabled | Same post-build run; `16kb-independent-readback.json` |
| Disposable backend tests | PASS: 350 SQL tests across 13 files; 142 Edge tests | [34745887372](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34745887372), `backend-independent-readback.json` |
| Exact-source Maestro journeys | PASS: 11/11, correct order, no failures/errors/skips | [34745886271](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34745886271), `maestro-first-independent-readback.json` |
| Additional combined journeys and bounded Monkey | Maestro PASS again, 11/11. Monkey: 3 variants PASS, fourth recovery FAIL, fifth NOT RUN; 1,400 actual events | [34748307770](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34748307770), `combined-independent-readback.json` |

Maestro covers Smart Planner, Creator, SI, Timeline, Progression, Settings, subscription containment, logout, account isolation, learned lifecycle and a separate lifecycle readback. This lane uses a QA emulator build from the exact source; it is distinct from the Play-signed build tested on the Moto. Raw JUnit, source identity, sequence hash and sanitized Android logs were independently parsed. Native instrumentation reports and strict-16-KB JUnit were also independently checked, not inferred from green workflow status alone.

The Monkey-only attempt [34746958284](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34746958284) failed **before any stress events**: an old seed-helper text assertion did not match the current flow. Fresh-guest readiness passed. Its logs remain in `monkey-first/` and `monkey-first-failed.log`; it is not an application crash. The subsequent combined run [34747529618](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34747529618) compiled successfully, then its fresh Android guest's Nexus Launcher reported an input-dispatch ANR before app tests. Raw `prepared-lastanr.txt` identifies `com.google.android.apps.nexuslauncher`; no Maestro cases or Monkey events ran. Its complete compact artifact was digest/CRC-verified and retained in `maestro-combined/`. One identical fresh-host retry ran to a terminal failure described below. Application source, readiness guards and test assertions remained unchanged.

### Stress outcome and runner blocker

The fresh-host retry passed all 11 Maestro flows with zero failures/errors/skips and no fatal diagnostic matches, then ran these variants on the same exact-source QA APK:

| Variant | Injected events | Result |
| --- | ---: | --- |
| Smoke | 100 | PASS, including new-process relaunch and stable app focus |
| Balanced | 500 | PASS, including new-process relaunch and stable app focus |
| Navigation | 300 | PASS, including new-process relaunch and stable app focus |
| Touch/motion | 500 | FAIL at relaunch focus readiness; all events completed and no fatal markers recorded |
| Fifth variant | 0 | NOT RUN because the matrix stops at its first failed variant |

Total: **1,400 of the planned 1,700 events**, with three fully passing variants. After the touch/motion run, the runner collapsed the notification shade, stopped the old app process and successfully launched a new process (PID 9717). However, repeated probes found `SystemUIDialog` in the foreground through the 30-second readiness deadline. Final window evidence assigns that dialog to `com.android.systemui`; system logs show `bluetooth_tile_dialog` activity. The dialog's exact visible content was not captured. Final guest diagnostics report no ANR since boot, and independent scans of both the variant logs and the final system log found no application fatal/error/overflow matches.

This supports a **runner recovery gap around a system dialog**, not a confirmed ChronoSpark crash. It does not establish a successful fourth-variant recovery. Repair the runner's system-dialog diagnosis/recovery and obsolete Monkey-only seed preparation, then rerun the complete matrix without weakening the app-readiness or fatal-error checks. Failed attempts remain in the evidence set; there was no additional identical retry after this concrete recovery failure.

The downloaded retry archive's SHA-256 and CRC were verified, as were source identity, precompiled/Maestro/Monkey APK identity, Maestro sequence hash, JUnit case results, each executed event count and each full variant-log hash. Proof: `combined-retry-download-receipt.json`, `combined-independent-readback.json`, `maestro-combined-retry/`. These are separate checks of evidence validity; the matrix result remains FAIL.

## Six repair rechecks on the Play-installed Moto

| Finding | Result and observed behavior |
| --- | --- |
| F01: ordinary SI questions | PASS. Goals, tasks, milestones and the five-minute school-pickup question use relevant saved data; unsupported weather request is declined. |
| F02: recovery duration | PASS. Setup, work and breaks together fit both five-minute and one-minute limits. Singular-minute wording remains a separate new finding below. |
| F03: Daily Rhythm plus | PASS. Plus is visibly legible on the filled circle; target increments 1 → 2 and decrements 2 → 1. Draft was discarded. |
| F04: note, task and skipped rhythm | PASS. Planner selects the active receipt task, uses the linked note's seven-minute limit and leaves the existing receipt rhythm skipped this week. |
| F05: recovery completion control | PASS. Zero-energy recovery guidance exposes no unrelated task-completion button; real task guidance names the task it completes. |
| F06: empty milestone health | PASS. No recorded milestones produces an unavailable-health explanation, without a 100% milestone-health claim. |

Individual captures and results are indexed in `repair-rechecks.json`.

## Realistic physical-device journey

The agent operated the actual UI with synthetic everyday bookkeeping and school-pickup constraints. This was agent-driven exploration, not a claim that an independent human participant ran the session.

- Created a five-minute task, **Check one grocery receipt before Sunday lunch**, linked to the existing **Finish my weekend bookkeeping catch-up** goal.
- Created **Sunday lunch bookkeeping limits**, with seven minutes before lunch and explicit instructions to preserve the skipped weekly receipt rhythm. Linked it to the task, goal and existing rhythm, then deliberately shared it with Planner through the visible consent control.
- Verified Planner's selected task and evidence, removed temporary note sharing and cleared temporary emotional context. The existing rhythm remained skipped.
- Completed that one task through its named Home control: XP **36,237 → 36,262**, completed tasks **1,449 → 1,450**. Force-stop/relaunch retained the result. Existing unrelated tasks remained active. No direct XP or database edits.
- Checked Energy/Clarity boundaries `(0,0)`, `(100,100)`, `(10,90)`, `(90,10)` for energy/fatigue; Clarity correctly read `100,0,10,90`. Home and Trajectory agreed. Momentum remained BUILDING across 7-, 30- and 90-day views. Restored 7-day horizon and the original unmeasured Energy/unchecked Clarity state.
- Selected and read back all nine emotional states; cleared the temporary check-in afterward. Emotion sharing remained off.
- Finished 25 cycles through Nexus, Trajectory, Timeline and Profile: **100 actions and 100 verified route readbacks**. No account or data reset. Three PSS samples were 231,702 / 228,657 / 229,503 KB; these samples show no upward trend during this bounded run, not proof against every possible memory leak.
- Captured 3,374 runtime log lines from the owned collector. Independent scans found zero crash, ANR, Flutter fatal/provider-error or overflow matches in the collected tags. Final Android exit history for user 0 showed the expected installation and deliberate persistence-test force stops during this campaign, not an unexpected crash. Historical older exits are retained and not attributed to this build.
- Stopped only this campaign's verified log collector. Left ChronoSpark open on Home; other connected devices were untouched.

## Credit, billing and voice checks

**Credit spending passed through the app's server-backed test UI.** Quoted and confirmed a three-credit request using the fixed fictional prompt. Balance changed **511 → 508**, with a returned answer. Retry of the same request returned the completed result without a second charge. A subsequent unconfirmed four-credit quote was invalidated when external-AI consent was disabled, and stayed invalid after consent was restored. Final displayed balance: **11 included + 497 purchased = 508**. This is UI and server-response evidence; this campaign did not independently query the production credit ledger.

**Play purchase-sheet and cancellation smoke passed.** Monthly `$7.99`, annual `$69.99`, and 100-credit `$2.99` sheets displayed Google's approving test card and no-charge test wording. Canceled all three before purchase confirmation; access remained unchanged. Restore reported no active purchases. No real money was spent. This campaign did not repeat fresh confirmed purchases, pending instruments, renewal, grace, hold, pause/recovery or cross-account purchase ownership transitions, and does not upgrade older evidence to a fresh pass.

**Speech UI checks passed:** Speak exposes Stop, Stop clears speaking state, repeated playback does not repeat approval, and leaving the route clears speaking state. Audio waveform cessation was not independently recorded. **Microphone start and silent timeout passed**, with no automatic query submission. Explicit microphone-stop timing remains **INCONCLUSIVE** because silent-recognition timeout raced with the UI snapshot/tap. Dictation accuracy was not measured. Final microphone state was idle.

## New application findings — open

1. **N02, medium: date-only goals become overdue at the beginning of their target day.** At 02:57 on September 13, a goal targeting September 13 was labeled overdue and needing recovery while also due today. `lib/features/timeline/logic/timeline_projection.dart:71` uses `target.isBefore(now)` for a date-only target. Evidence: `note-open-timeline.{json,xml,png}`. Use calendar-day semantics and check today/yesterday/tomorrow boundaries before closing this finding.
2. **N01, low: singular-minute recovery wording.** One-minute options say “Use 1 minutes” and “Within 1 minutes total.” Timing arithmetic passes. Evidence: `planner-five-answer.json`, `planner-one-answer.json`. Repair singular/plural formatting and recheck one- and multi-minute output.

No application or backend source was modified during this testing campaign. Unrelated listing work remains preserved. The two app findings, incomplete stress matrix and microphone measurement gap prevent an honest “everything passed 100%” claim. All hosted runs launched for this campaign have reached terminal results; the owned local log collector is stopped.
