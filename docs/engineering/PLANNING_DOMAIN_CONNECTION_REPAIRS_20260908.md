# Planning domain connection repairs — 2026-09-08

Scope: the seven findings from the goals, tasks, Daily Rhythm, notes, and emotional-state planning audit. Changes are local to `fix/aab-prebuild-cleanup-20260905`, based on `ba625d47576b1ab2a4e682dd59292e7d92d72302`.

## Repaired behavior

| Finding | Result | Regression evidence |
| --- | --- | --- |
| Urgency overrode an emotion-driven Minimum recommendation | Urgency no longer promotes Minimum to Best Fit. Anxious, fatigued, scattered, and negative check-ins retain a small reversible start. The shared decision engine also limits its first execution step to at most five minutes, while retaining the actual saved schedule and task duration. Explanations describe the adaptation that actually occurred. | Planner controller cases for all four states with an urgent saved task; decision-engine cases assert the bound, unchanged schedule, and unchanged reported energy/fatigue. |
| Emotional state had inconsistent local/shared scope and expiry | A current check-in stays local to Smart Planner unless the person explicitly shares that check-in with SI/Nexus. Sharing requires the existing emotion consent. The check-in expires after two hours and clears on account or consent changes. Clear and sharing controls are exposed. Displayed responses and in-flight UI results are invalidated when the underlying check-in changes. Consent is checked again after asynchronous evidence reads. | Provider lifecycle test exercises local-only, explicit sharing, expiry, account change, and consent withdrawal; existing consent-boundary and Smart Planner widget tests. |
| Daily Rhythms were only counted | Planning now reads the current daily/weekly/monthly period outcome. Completed, skipped, and paused periods are excluded from outstanding targets. A matched resolved rhythm prompts for a different commitment instead of proposing duplicate work. Unrecorded targets support a proposed remaining session with an explicit statement that individual repetitions and session duration are unknown. SI uses the count of current targets without recorded outcomes. | Pure cadence/outcome tests, all four planner status branches, and existing occurrence coordinator and Daily Rhythm widget tests. |
| Note relationships/use cases were not reachable or usable in planning | Note detail exposes edit/link, archive, and explicit temporary planning attachment. Goal/task/rhythm links are validated against existing entities; incompatible goal/task links and stale edits are rejected. Selection uses the latest unarchived note, clears across accounts, and expires after two hours. Selected note text can constrain a local plan; other notes are not retrieved for that request. No emotion is inferred from note text. | Repository/provider link and archive tests; account-generation race; English/Spanish edit and planning-confirmation flows; selected-note grounding and English/Spanish numeric capacity constraints. |
| Goal percentages counted skipped/canceled tasks and unbounded recurring work | The ratio covers finite one-time actions. Skipped/canceled actions are excluded and reported separately; recurring completions are shown separately from the finite denominator. Recurring history remains stored. | Goal progress model case with completed, skipped, canceled, and recurring actions; goal provider lifecycle and UI progress recovery tests. |
| Historical skips were labeled an avoidance pattern | Only distinct task-skip events within the last seven days count. Future-dated records are excluded. The warning reports at least two recent skips and says their reasons are unknown. | Window, future-date, duplicate-ID, and decision-output wording tests. |
| Unavailable goals/progress were rendered as empty/zero | Corrupt or unavailable goal reads propagate an explicit unavailable state. Goals display a recoverable error and disable Add while the read is failed. SI source health marks the goal source as failed. Planner receipts distinguish unreadable evidence from an empty account. Progress has separate loading/error states and Retry; sharing is disabled until progress is available. | Existing corruption quarantine tests, unavailable-goal planner test, and English/Spanish goal read/progress loading-error-recovery widget cases. |

## Data and behavior boundaries

- These changes do not migrate stored entities or recalculate XP. Goal completion remains a user action; a ratio does not auto-complete a goal.
- Rhythm outcomes still describe the whole cadence period. The app does not claim to know a partial repetition count or measured remaining duration.
- Planning reads canonical rhythms without starting the Daily Rhythm UI's reminder work. Rhythm mutations and Creator saves invalidate the planning read, while period and account changes also refresh it. Supplementary rhythm/note reads have a two-second bound each and explicitly report unavailable evidence on failure.
- Notes are attached through an explicit, temporary choice. Selecting a note invokes local planning, not a remote AI request. The existing separately quoted optional AI explanation flow remains subject to its own confirmation and credit controls.
- Note writes capture the account repositories/use case before waiting, and reject stale account generations before publishing the result into active state/history. Existing repository account fences continue to govern storage writes.
- Emotion sharing is a per-check-in choice, not a new durable emotional profile. Previously selected check-ins do not become shared automatically.
- Existing release reports, build artifacts, and unrelated working-tree edits were preserved.

## Validation

Evidence folder: `test-results/planning-connections-20260908/`.

- Static analysis: `analyze-complete.txt` — no issues found on the final repaired source.
- Focused domain, provider, widget, and source-contract run: `focused-final-manifest.json`. This intermediate run found two test-selector errors and a text-encoding regression; those were repaired.
- Follow-up goal/Planner UI run: `ui-recheck-manifest.json` — 34 passed, zero failed.
- First full diagnostic run: `full-suite-manifest.json` — 2,625 passed, four failed assertions, one timeout. It exposed the screen file-size limit, product terminology, LF-sensitive source contract, cold rhythm/reminder dependency, and an SI source-health fixture missing the new read state. These failures were repaired rather than weakening the gates.
- Final repair recheck: `repair-recheck-manifest.json` — 143 passed, zero failed/errors/skips. Covers all five failures, cold read-only rhythm loading, bounded unavailable rhythm evidence, stale pending/visible Planner results, notes, goals, consent, Creator, and account fencing.
- `repair-source-hashes.json` records the source/test file hashes used for the final full run. That run starts after the repairs and rechecks, and source is held unchanged while it runs.
- Final full suite: `full-suite-final-manifest.json` — **2,632 passed, zero failed, zero errors, zero skipped**, terminal success and process exit 0. This supersedes the intermediate diagnostic failures above.
- Coverage: `coverage-guard.txt` — repository **ratchet gate passed**, 73.7% overall and 91.5% across critical files. The guard still reports advisory gaps against higher targets for domain use cases, paywall, backup, and auth; it counts 29 uninstrumented production files as zero. A passing ratchet is not a claim of 100% coverage or satisfaction of every higher target.
- Final integrity: `final-integrity.json` — all 41 repaired source/test hashes match the frozen run; `git diff --check` passed. Formatting was checked with zero changes before the final run.

All seven requested repairs are implemented and locally validated. Changes remain uncommitted; no AAB rebuild or installation was performed during this repair task.

This is source and local automated-test evidence. It does not certify a newly built AAB, a deployed backend, Google Play, billing purchases, or a fresh physical-device journey. No build, upload, monkey run, or level-20 endurance run is part of this repair validation.
