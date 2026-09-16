# ChronoSpark whole-app human-use audit

Audit date: 2026-09-14, America/Chicago. Some evidence timestamps are 2026-09-15 UTC.

## Verdict

**Needs repairs before human-use sign-off.** ChronoSpark has working connected records, explicit creation confirmation, local planning, and useful evidence boundaries. Ordinary human requests and corrections still produce wrong recommendations; record retrieval and correction are incomplete; dates, notification status, durable consent receipts, and Spanish recovery flows need attention. Passing existing tests does not resolve the demonstrated failures.

This report covers the shipping app's user journeys and their source wiring, with a fresh Moto walkthrough. It is not a claim that every source line, account state, device, or backend branch was tested. It supplements the saved [SI Console and engine audit](2026-09-14-si-console-human-use-audit.md), whose individual SI findings remain open.

## Identity, preservation, and evidence

- Checkout: `C:/Users/keegan radetski/Documents/Codex/2026-09-01/t/ChronoSpark-app-only-priority2`.
- Reviewed source HEAD: `7fb06e7619f37a498e9a85324f2f83ae25aa759d`, branch `fix/aab-prebuild-cleanup-20260905`.
- Moto g stylus 5G 2022, Android 13, package `com.ghostheart5.chronospark`, installed version `4.1.0` / `2026083048`.
- Walkthrough used Android user **11, ChronoSpark-Review**, after explicit device-availability approval. Every captured UI action checked the Android user and foreground package. Main profile user 0 and the other connected device were not operated.
- The installed version was read from the device. This was not a fresh build/install, and this report does not establish a new binary-to-HEAD hash attestation.
- App/source code was not repaired, committed, rebuilt, or published. Existing dirty work was preserved. `test/features/paywall/paywall_page_test.dart` changed externally during the audit; it was not edited or run as part of the selected suite. This report does not assert a globally unchanged worktree.
- Evidence root: `test-results/app-human-use-audit-20260914/`. UI readbacks and images are in `device/`; `actions.jsonl` records submitted inputs and actions. The compact evidence index is `audit-evidence.json`.
- Read-only parallel reviewers covered lifecycle/navigation, Planner/Trajectory, Settings/auth/voice/privacy/billing, and nine fresh screenshots. Root performed the device walkthrough and executed the selected checks.

Evidence labels below: **Moto** means observed during this fresh walkthrough on the existing installation; **probe** means executed production logic with synthetic in-memory inputs; **source** means a traced code path, with the stated trigger not necessarily reproduced on a phone; **design** means a usability recommendation or missing capability, not an asserted crash.

## Executed validation

**194 test cases passed across 22 selected existing Flutter suites, zero skipped after the completed retry.** The initial run passed 176 cases but Settings failed in `setUpAll` because the golden/font harness required `FLUTTER_ROOT`. Setting `FLUTTER_ROOT=C:/src/flutter` and retrying only Settings yielded another 18 passes. That initial setup error is a harness issue, not an app defect. Exact suite names: `selected-tests.txt`; machine events: `selected-tests.jsonl` and `settings-test-retry.jsonl`.

The selected checks cover Creator forms/localization, Daily Rhythms, Notes, projected Timeline management, emotion/check-in lifecycle, Nexus vitals/decisions, habit occurrence coordination, deterministic Trajectory fixtures, Profile, Smart Planner widgets, Settings, local-profile auth, onboarding accessibility, paywall error states, playback cancellation/controls, and accessibility widgets. They are not the whole repository test suite, Maestro, an endurance run, live billing validation, or a full native accessibility pass.

One new pure-Dart probe executed the existing task filter with two synthetic stored commitments. Both were returned at fatigue `0.74`; the urgent difficult task disappeared at `0.75` while the easy task remained. See `fatigue_filter_probe.dart` and `fatigue-filter-output.json`.

The prior SI audit separately records 58 existing test passes, 24 actual engine responses, and five connected-engine probes. Those older checks are not added to the 194 count or represented as rerun here.

## Realistic journeys exercised on the Moto

| Journey | Observed result | Evidence in `device/` |
|---|---|---|
| Parent creates a school-paperwork goal and a linked five-minute task due today | Creation required confirmation and saved once. Task immediately appeared overdue at midnight on the same day: H02. | `task-preview-visual.png`, `task-timeline-visual.png` |
| Complete the task, inspect Timeline, goal, and XP | Completion appeared in history; linked goal reached 1/1 actions. Profile and Progression showed level 1, 37 XP, one completed task, one-day streak. | `task-completed.json`, `goal-progress-after-completion.json`, `profile-after-completion.json`, `progression-spanish.json` |
| Edit a task after circumstances change | Title, goal, estimate, and deadline can be edited. No schedule, priority, or description control in the standard editor: H11. Dialog was cancelled without altering the task. | `task-edit-visual.png` |
| Worker has 90 seconds before a meeting, wants a message draft only | One-minute step fits that initial window; draft-only restriction preserved. | `planner-90-seconds-submitted.json` |
| Worker corrects to a video meeting, already at desk, only 30 seconds left | Still permits one minute and asks when to leave: H03/H04. | `planner-correction-result.json`, `planner-correction-visual.png` |
| Spanish parent records pickup instructions, links note to goal, consents it to local planning | Note body saved/read back and goal link saved. Explicit two-hour local-context consent appeared; note could be removed from context. | `note-detail-spanish.json`, `note-link-saved.json`, `note-planning-handoff.json`, `note-context-cleared.json` |
| Use ten minutes to prepare for Thursday's pickup from the selected note | Planner recommends the pickup itself at 16:30, drops Thursday, and says to fit it into ten minutes: H05. No message sent or date changed. | `note-planner-question.json`, `note-planner-answer.json` |
| Create a nightly school-bag Daily Rhythm, record today's target, then pause | Creation, completion, and pause worked. Completed-period buttons disabled; no correction path. Manager remains English in Spanish locale. | `rhythm-saved-manager.json`, `rhythm-completed.json`, `rhythm-paused.json` |
| Check in with energy 60% and fatigue 40%, open Momentum | Home displayed Energy 60%, estimated Clarity 60%, and Momentum Learning. Trajectory required two more task outcomes instead of inventing a personal forecast. | `energy-saved.json`, `clarity-saved.json`, `trajectory-from-momentum.json` |
| Tap SI's own Spanish welcome question | “¿Qué debería hacer después?” received an English unsupported-question answer despite saved task/goal evidence: H01/H18. | `si-spanish-suggestion-result.json`, `si-spanish-suggestion-visual.png` |
| Inspect Profile, Progression, Settings, notification inbox, and active review/test paywall | Screens opened; account was explicitly labelled review/license-test. Notifications showed future schedules as unread and English text. Paid purchase/restore buttons were not exercised. | `progression-spanish.json`, `read-settings.json`, `notifications-spanish.json`, `paywall-inspect.json`, `paywall-lower.json` |

The visible 37 XP reconciles in source as goal creation **12** (`goals_provider.dart:91-110,242-254`) plus task completion **25** (`task_provider.dart:303-319`). There was no intermediate Profile capture after goal creation, so these individual increments are source-reconciled; the final total is device-observed. Completing the Daily Rhythm did not increase the displayed task-completion count. No level-20 run was performed.

## Findings requiring repair

### H01 — SI still fails human intent/answer alignment [P1; prior probes, fresh Moto confirmation]

The saved SI report contains the independent findings: excluded tasks recommended, inverted priority interpretation, overdue queries misrouted, the wrong goal/milestone answered, ignored delay/budget constraints, misleading overlap assurance, Spanish requests refused, and typed validation accepting semantic mistakes. Do not collapse those into a localization-only repair.

Fresh Moto confirmation: tapping SI's own Spanish question “¿Qué debería hacer después?” produced “SI cannot answer that question…” in English. This is a normal supplied entry point, not an obscure adversarial prompt. The prior report contains exact files, repro inputs, and repair order. Acceptance requires semantic assertions about the selected records, constraints, and answer meaning, not just response structure.

### H02 — A task due today is immediately treated as overdue [P2; Moto + source]

Creator's date-only picker stores local midnight (`lib/features/creator/widgets/dynamic_form.dart:366-373,760-762`; handshake `lib/state/providers/creator_handshake_provider.dart:589,750-762`). Timeline compares that instant against now (`lib/features/timeline/logic/timeline_projection.dart:17-30`). A task created with Today's due date therefore says “Task deadline missed. Re-plan this task immediately” during the same day. The confirmation exposes the raw midnight timestamp. Task editing also strips an existing time when a date is chosen (`lib/features/tasks/widgets/task_edit_dialog.dart:165-173`). Goals use inconsistent date-only/instant comparisons between their card and Timeline.

Acceptance: define date-only deadline semantics separately from timed deadlines; a task due today must remain due today until its agreed local-day boundary. Verify Creator → persisted record → Timeline → editor round-trip, including timezone boundaries, rather than testing the picker alone.

### H03 — A revised 30-second limit still permits one minute [P2; Moto + source]

After a valid one-minute draft for an initial 90-second window, the user says “I have only 30 seconds now.” The answer still says “Allow up to 1 minute.” `lib/state/controllers/smart_planner_query_controller.support.dart:275-308` recognizes minutes/hours; fractional values below one minute are discarded at `:325-328`. The controller consequently retains the old estimate (`smart_planner_query_controller.dart:548-562`).

Acceptance: the latest explicit limit overrides the previous one. Offer a step bounded by 30 seconds or clearly explain that no useful step fits; never silently enlarge the available window. The initial 90-second answer is not itself a failure.

### H04 — Corrected meeting context does not remove a travel assumption [P2; Moto + source]

“It is a video meeting and I am already at my desk” still receives “When do you need to leave to get there on time?” Prior objective and correction are combined (`smart_planner_query_controller.support.dart:119-122`), while departure detection lacks remote/already-there exceptions (`smart_planner_query_controller.intent.dart:1015-1073`, especially `:1066-1069`).

Acceptance: represent corrected facts as replacements for contradicted assumptions. Do not ask again about travel explicitly removed by the user. Draft-only remained respected in this same response.

### H05 — Preparing for a future pickup becomes performing the pickup [P2; Moto + source]

Note: “El jueves debo recoger a Lucia a las 16:30. Llevar el formulario firmado y confirmar el contacto con la escuela…” Request: “Tengo 10 minutos. Usa la nota para ayudarme a preparar la recogida de Lucia. No envies ningun mensaje.” Answer: “Recoge a Lucia a las 16:30” and “Mantén este único paso dentro de los 10 minutos disponibles.” The requested preparation and Thursday qualifier are lost.

`smart_planner_query_controller.intent.dart:703-717,728-745` rejects the ordinary prefix “Usa la nota para ayudarme a” before `preparar`; note fallback at `:64-76` extracts the verb onward, dropping “El jueves debo.” `Llevar`, `confirmar`, and `avisar` are absent from the action vocabulary at `:700-701`. “La nota” also misses the explicit-selected-note grammar at `:375-379`, although shared terms retain note relevance (`support.dart:435-452`).

Acceptance: preserve **prepare now**, **pickup Thursday at 16:30**, and **do not send**. Produce a useful preparation step or focused clarification. This is not evidence that the app rescheduled the pickup or sent a message.

### H06 — Fatigue filtering can hide real commitments from Timeline [P2; executed probe + source wiring]

At fatigue 0.75, `lib/state/providers/task_provider.dart:61-68` selects safety-first filtering; `lib/engine/tasks/task_filter.dart:129-134` removes tasks above difficulty 2 when an easier task exists. Timeline consumes that filtered provider (`lib/features/timeline/ui/timeline_screen.dart:93-101,126,150-154`). The probe retained a nonurgent easy task and omitted a priority-5 overdue assignment. Both remained in the canonical input.

This requires mixed task difficulties; Creator currently defaults new tasks to difficulty 3, so the probe is not a claim that the one new Moto task vanished. Acceptance: recommendation ranking may adapt to fatigue, but the management view must preserve all commitments and explain any intentional filter. Add the mixed-difficulty Timeline integration case.

### H07 — A changed privacy preference can appear saved without durable persistence [P2; conditional source path]

`lib/state/providers/personalization_provider.dart:142-161` publishes new consent before awaiting storage, without rollback. `lib/data/storage/shared_prefs_service.dart:83-98` returns normally when preferences are unavailable and ignores `setString`'s false result. Settings then announces success (`lib/features/settings/ui/settings_screen.planning_sections.dart:307-315`). Revoking future-guidance/emotion/external-context permission can therefore look successful until reload restores the previous saved setting.

Acceptance: storage failure must prevent a durable-success receipt, expose a retry/error state, and preserve fail-closed consent semantics. Test both throwing writes and false-returning writes followed by provider recreation. No live external request after revocation was demonstrated here.

### H08 — A recorded outcome can be reported as a failed save [P2; source + existing coordinator test]

Habit completion saves the canonical occurrence, then awaits learning (`lib/state/services/habit_occurrence_coordinator.dart:116-117`). A later failure can propagate before UI invalidation; Daily Rhythms says it could not save. The existing coordinator test at `test/state/services/habit_occurrence_coordinator_test.dart:99-139` explicitly covers a throwing first attempt with one durable occurrence and repair on retry. Task completion/skip similarly awaits supporting work before final UI invalidation (`lib/state/providers/task_provider.dart:285-287,317-326,365-366,440-444,478-499,515-516`).

Acceptance: distinguish recorded outcome from pending ancillary learning/history work; show canonical state promptly and make retries idempotent. The normal Moto completion paths succeeded; no device storage/network failure was injected.

### H09 — Corrupt governed memory looks empty and cannot be specifically cleared [P2; conditional source path]

`lib/data/repositories/memory_repository.dart:38-76` catches malformed-container decoding and returns an empty list while retaining the payload. Settings shows “No durable memories” (`settings_screen.governance_sections.dart:131-138`), and its delete-all handler exits at zero visible items (`:194`). Repository deletion could remove the account key without decoding it (`memory_repository.dart:175-177`).

Acceptance: expose unreadable retained data and permit confirmed deletion of that account's memory key while preserving unrelated data. This concerns governed-memory receipts, not Person Context, whose corruption UI is separate and tested. No real user data was corrupted during this audit.

### H10 — Corrupt notes can silently disappear from the readable collection [P2; conditional source path]

`lib/data/repositories/note_repository.dart:108-126` returns a valid subset or empty list while keeping `lastReadCorrupted`; the notes provider does not surface that state. A person cannot distinguish no notes from unreadable notes. This is not proof that original bytes were deleted.

Acceptance: show a read-health warning/recovery path while preserving readable records and original data. Verify malformed and partially valid containers, not only malformed individual records.

### H11 — Existing task details cannot be fully adjusted through the normal editor [P2; Moto + source]

The task editor exposes title, estimate, deadline, and goal (`lib/features/tasks/widgets/task_edit_dialog.dart:194-201`). Nexus and Timeline both use it. Initial schedule, priority, and description have no corresponding controls; no shipping feature caller of `TaskOccurrenceCoordinator.reschedule` was found. A person changing an appointment or correcting a priority cannot maintain the same task through this editor.

Acceptance: expose supported adjustments with occurrence-safe schedule changes and preserved history; verify both Nexus and Timeline callers. Do not require deleting/recreating the commitment as the ordinary correction workflow.

### H12 — “Move tomorrow” on an overdue projected goal does not update the goal [P2; source-only aged-record case]

Goal projections use synthetic IDs (`timeline_projection.dart:84`), but the action eligibility excludes only projected tasks (`timeline_screen.widgets.dart:350-370`). The handler sends the synthetic goal item through the Timeline-record update path (`:653-655`); `lib/data/repositories/timeline_repository.dart:107-116` returns null for the nonexistent record, and the provider accepts that quietly. The source goal date remains unchanged.

Acceptance: update the underlying goal through a supported action or do not offer this action. Test a naturally aged saved goal or synthetic stored fixture. The live goal picker disallowed past dates; that expected restriction prevented a fresh UI reproduction and is not a failure.

### H13 — Goals' on-screen Back opens Planner after entering from Nexus [P2; Moto + source]

Nexus → Open Goal → on-screen Back navigates to Smart Planner, not the screen used to enter. `lib/features/goals/ui/goals_screen.dart:52` hardcodes `AppView.smartPlanner`. Android Back returned to Nexus in the walkthrough.

Acceptance: preserve origin/route-stack behavior consistently. Evidence: `goal-progress-back-before.json` and `goal-progress-back.json`.

### H14 — Opening a suggestion is stored as evidence that it helped [P2; source]

Nexus “Review suggestion” records accepted plus `recommendationHelped: true` before opening Planner (`lib/features/nexus/ui/nexus_screen.dart:339-364`). Outcome persistence feeds learning (`lib/state/providers/decision_outcome_provider.dart:193-198`; `lib/domain/usecases/apply_learning_feedback.dart:189-190`). Planner's “Use this plan” also records helpfulness before Creator confirmation (`lib/features/home/ui/smart_planner_screen.dart:627-636`). Review/acceptance may be measurable, but helpfulness is not established by navigation or a still-unsaved draft.

The helpfulness calculation treats both explicit `recommendationHelped: true` and an accepted event as positive (`lib/domain/learning/learning_ledger.dart:192-203`). Acceptance: separate viewed, accepted, committed, completed, and explicitly helpful outcomes. Do not train helpfulness from opening a screen. This audit did not tap the preexisting demo task's suggestion to induce feedback.

### H15 — Progression can turn unavailable Profile data into believable zero values [P2; conditional source path]

Profile state distinguishes loading/ready/unavailable (`lib/state/controllers/profile_controller.dart:21-63,186-195,247-255`). `lib/state/providers/progression_provider.dart:10-14` and `lib/state/services/progression_service.dart:8-15` discard that distinction, while Progression renders/shares the values (`lib/features/progression/ui/progression_screen.dart:64-74,207-209,344-351`). Profile itself has a proper retry/unavailable presentation.

Acceptance: retain source readiness through Progression and sharing; never turn a failed load into a real zero-history receipt. The Moto's healthy state showed the correct 37 XP; this unavailable case was not injected.

### H16 — “Correct assumptions” excludes a forecast rather than editing its assumptions [P2; source]

The visible action (`lib/features/trajectory_engine/ui/trajectory_engine_screen.widgets.dart:435-445`) immediately marks a receipt (`trajectory_engine_screen.dart:306-327`). The receipt keeps assumptions and projected values and adds `assumptionsCorrectedAt` (`lib/domain/trajectory/trajectory_forecast_receipt.dart:149-170`); calibration excludes it (`:302-310`). There is no actual correction form/recalculation in that action.

Acceptance: either label the real effect clearly (exclude from monitoring), or provide an actual edit/recompute workflow with a preserved original receipt. The Moto's sparse-history gate prevented this detailed forecast journey; it is not device-verified here.

### H17 — Trajectory's displayed XP projection differs from the completion award [P2; prior executed probe + source]

The prior SI audit's ENG-01 probe demonstrated a task projection of 18 XP versus the ordinary completion base of 25. The fresh device's final total reconciled to goal creation plus the 25-point task award; it does not validate the 18-point forecast. Acceptance: use the canonical award policy or clearly identify a different modeled quantity; add a projection-to-recorded-outcome comparison. Exact probe/source evidence is retained in the SI report.

### H18 — Spanish support breaks in essential management and recovery paths [P2; Moto + source]

Fresh Moto: Daily Rhythms management, Note detail headings, Settings sections, notification inbox, Trajectory headings, and SI's answer remain wholly or partly English. The paywall mixes English license-test text with Spanish plan text. Auth validation/error/verification recovery also uses fixed English (`lib/features/auth/screens/auth_gate.dart:35-84,653-678,1000-1020`). Settings consent/governance strings remain English (`settings_screen.planning_sections.dart:401-432`; `settings_screen.governance_sections.dart:133-138,199-220`).

Acceptance: cover English and Spanish across dynamic responses, errors, disabled/empty states, consent, recurrence outcomes, notifications, and accessibility labels. Static translated happy-path forms do not establish bilingual completion. Keep user-entered note/task text exactly as entered.

### H19 — Spoken Spanish is routed through an English-initialized voice [P2; source, native audio unverified]

Planner/SI pass displayed text to voice, but `lib/system/voice/voice_service.dart:203-211` initializes `en-US`; `setLanguage` has no selecting caller in `lib`. Android initialization sets `Locale.US` (`android/app/src/main/kotlin/com/ghostheart5/chronospark/MainActivity.kt:253`). This matters when the voice/cloud feature is enabled.

Acceptance: select the app/content locale before native speech and verify pronunciation on supported engines. No actual audio was played/heard in this audit, and engine-specific automatic language detection was not established. Existing fake-voice tests establish text/cancellation, not native pronunciation.

### H20 — Notification schedules and in-app activity have misleading shared status [P2; Moto + source/design]

An Oct14 goal immediately adds an Oct13 “Target date is near” entry to the unread inbox. That is a saved future schedule, not a delivery receipt: goal save → reminder orchestration (`goals_provider.dart:168-175`; `reminder_orchestrator_service.dart:103-113,206-210`) → default unread notification → repository save before OS scheduling (`lib/data/repositories/notifications_repository.dart:130-147`). The screen counts/renders every stored unread record without a due filter (`lib/features/notifications/ui/notification_screen.dart:17-18,40-46,82-86`).

Decision/completion feedback is intentionally in-app-only (`isEnabled: false`) but labelled “Disabled.” Scheduler false returns do not become a distinct failed-scheduling row. Acceptance: distinguish scheduled reminders, in-app activity, and scheduling failure; use accurate unread semantics and never imply delivery without evidence. No early Android delivery was observed; system notification permission was denied.

### H21 — Notification dates can display the UTC day instead of the user's local day [P2; source; Moto observation consistent]

`lib/data/models/notification_record.dart:79` stores UTC; `:48-58` parses without local conversion. The tile calls `scheduledAt.short` (`notification_screen.dart:235`), whose implementation prints month/day without `.toLocal()` (`lib/core/extensions/date_extensions.dart:4`). Sep14 evening Chicago becomes Sep15 UTC, so a reloaded local action can show 9/15. The walkthrough showed 9/15 decision/completion rows, but no private persisted timestamp was extracted to prove those exact instants.

Acceptance: localized local-time display after serialization/readback; test an evening timestamp crossing the UTC date boundary independently from date-only deadline handling.

## Missing capabilities and comprehension improvements

These are explicit product/UX work items, separate from claims of crashes or data loss.

| ID | Human consequence and evidence | Concrete recommendation / acceptance |
|---|---|---|
| G01 — Retrieve everything created | No reachable all-task or all-note library/archive was found. `/tasks` redirects to Creator (`app_route_registry.dart:138-142,312-315`; `app_router.dart:298-300,341-344`). Nexus exposes one selected note (`nexus_screen.dart:193-202`, `nexus_screen.timeline_widgets.dart:793-812`); Timeline omits undated tasks. Archive retains a note but no archive browser/unarchive path was found. | Add discoverable collection/search and active/completed/archived filters. Demonstrate finding the second unscheduled task and an older/archived note without creating another record. The created audit note was not archived. |
| G02 — Correct normal human mistakes | Goals complete through a swipe (`goals_screen.dart:550-557`) without an ordinary edit/delete/reopen/completed-goal manager. Daily Rhythm outcomes become final for the period; the Moto correctly disabled both outcomes after completion but offers no correction/backfill. Nonrecurring task Skip is terminal rather than defer/resume. | Define safe undo/correction and distinguish skip from postpone. Explain 100% linked actions versus an active goal; do not silently treat those as the same state. Preserve outcome history. |
| G03 — Dictation over an existing draft | Planner and SI replace composer text on recognition (`smart_planner_screen.dart:1533-1535`; `si_console_screen.widgets.dart:946-953`). No append/replace choice or recovery snapshot found. | Decide/document dictation semantics and preserve a recoverable draft. Test a nonempty composer, partial recognition, cancel, and retry. No native microphone test performed here. |
| G04 — Subscription management destination | “Manage plan” opens the paywall; active subscription actions are disabled, and no direct Play subscription-management link was found. This was observed on the review/license-test paywall; live cancellation was not attempted. | Provide a clear manage-in-Play destination when applicable and distinguish free reviewer access from test subscription/catalog information. Validate on the actual intended billing account, without real charges. |
| G05 — Confirmation language | Creator repeats “Not present →” for a new item and exposes raw timestamps; single creation says “CONFIRM SELECTED.” | Show a compact ordinary-language summary with distinct scheduled time/due date and a consequence-specific action such as Create task. Retain explicit unsaved state, Edit draft, and Cancel. |
| G06 — Evidence and identity presentation | Profile gives Discipline/Growth/Execution artwork more prominence than its unavailable-pattern explanation. SI exposes a revision hash and two similarly named Advanced sections, but gives no concrete supported follow-up when refusing its own question. | Put the evidence boundary alongside claims/artwork; move revision diagnostics out of the main answer; offer a useful supported question. No claim of an actually computed personality trait is made. |
| G07 — Competing notification recovery actions | Denied permission shows both Activate notifications and Open settings in adjacent cards. | Display one state-specific recovery action. The screenshot establishes competing affordances, not whether either native permission action fails. |
| G08 — Timeline findability and meaning | Week starts today and filters the date range before status, so Overdue does not automatically mean all historical overdue work. A task scheduled today but due Friday projects only the deadline. Counts/controls consume much of the first screen. | Decide and explain range versus all-overdue semantics and schedule versus deadline events without double-counting. Reduce repeated counts; test scroll reachability. Screenshot position alone does not establish inaccessible controls. |
| G09 — Evidence references and destination labels | SI evidence references and Planner evidence are plain Text, not item navigation. Trajectory “Review on Timeline” can route to Planner for Maintain Current Course (`trajectory_engine_screen.dart:330-339`, widgets `:426-430`). | Make displayed destinations truthful; link supported item references or label them as identifiers. Missing milestone management cannot be replaced by a text URI. |

## Open verification risks, not confirmed additional failures

- Planner copies energy into screen state (`smart_planner_screen.dart:95-104`) while the shared check-in can expire after two hours. The source suggests a stale-copy risk if Planner remains open, but no two-hour fake-clock or device reproduction was executed. Verify expiration at submission and clearly separate current self-report from retained session values.
- “Clear short-lived assistant context” was not reported broken merely because an old clear-handler call was found: normal Settings navigation can dispose screen-local Planner state. A proper live retained-route test is needed before that claim.
- Account deletion, cloud sync interruption, restore on a different account, live purchase/renewal/credit spending, native notification delivery, permission-settings round-trips, voice pronunciation, large text, TalkBack traversal, tablets/landscape, offline relaunch, and long-term growth remain outside this fresh walkthrough.
- Trajectory correctly withheld a personal forecast with one recorded task outcome; the later-stage forecast interaction was reviewed in source, not unlocked by manufacturing the user's progress.
- No crash was demonstrated in this successful Appium walkthrough. That does not prove crash freedom. The earlier SI audit's transport failure remains a separate historical attempt, not a failure in this run.

## Protections and behavior to preserve

- Typed Creator preview, explicit confirmation, save-once receipt, and short-window creation undo.
- Linked task completion updates goal progress and ordinary Profile/Progression values coherently in the observed journey.
- Notes remain user-controlled context; the two-hour local-use explanation explicitly separates selection from external AI and emotion inference. Removing the selected note worked.
- Energy is explicitly a self-report; Clarity explains its fatigue-based estimate. Clearing both restored unmeasured/unchecked values. Sparse-history Momentum/Trajectory did not fabricate a personalized forecast.
- Daily Rhythms supports a real manager, period completion, pause/resume, rename, and remove; successful completion does not create duplicate outcomes on the tested path.
- Voice has generation invalidation, serialized cleanup, global stop controls, and navigation/background cancellation. The unused controller stub does not establish that the visible Stop control is broken; selected cancellation/control tests passed.
- Auth/onboarding and public-route guards, bounded return routes, explicit dictation consent/review-before-send, billing request coalescing, and ownership checks exist. Those source protections are not substitutes for the unexecuted live branches.
- The visual system is cohesive; cards separate text from decoration and key save/cancel controls were generally identifiable. Contrast, scaling, and TalkBack were not quantitatively certified.

## Repair order and re-audit criteria

1. **Truth and persistence first:** H02, H06-H10, H14-H17, H20-H21. Add narrow state/readback/failure-path tests showing truthful receipts, retained commitments, and coherent dates/XP.
2. **Human comprehension:** all saved SI findings plus H03-H05. Build an English/Spanish semantic scenario table covering requests, corrections, negation, named entities, available time, and note temporal context; judge the actual displayed answer and resulting draft.
3. **Everyday maintenance:** H11-H13 and G01-G02/G09. Walk create → retrieve → correct → complete/skip/postpone → reopen/archive/history, including multiple records and old dates.
4. **Bilingual and voice completion:** H18-H19 and G03. Test dynamic text, failures, consent, native speech locale, draft preservation, and navigation cancellation.
5. **Presentation and billing navigation:** G04-G08, then large text/TalkBack/layout and the applicable licensed Play account journey.
6. Rerun the 22 selected suites plus regressions for the repairs, then repeat the exact Moto prompts and entity journey with fresh prefixed records. Preserve separate results for host tests, device behavior, backend/billing, and later endurance. Do not claim 100% app correctness from suite success.

## Device changes and cleanup receipt

Four synthetic records were created only in ChronoSpark-Review: goal **HUA: School trip paperwork ready** (Oct14 target), completed task **HUA: Send school permission form**, note **HUA: Recogida de Lucia** linked to that goal, and Daily Rhythm **HUA: Preparar mochila escolar** (today completed, then paused). These records and resulting history/XP remain for review. The preexisting bookkeeping demo task was preserved.

The goal's future date was retained after the live picker rejected the attempted past-day fixture; no past-goal device reproduction is claimed. Audit inputs describe fictional school/work situations; completion means the test record was completed in the app, not that real-world paperwork or messages were sent.

The selected note was removed from short-lived Planner context; temporary energy/fatigue reports were cleared; app locale was restored from Spanish to its original empty override `[]`. Final Nexus showed Energy unmeasured, Clarity not checked, Momentum Learning. The owned Appium session was closed and its server PID stopped after executable/start-time verification; the other existing Appium server was untouched. See `device/note-context-cleared.json`, `final-nexus-restored.json`, `locale-restored.json`, `session-closed.json`, and `server-stopped.json`.

No repair, commit, build, upload, production publication, external model call, real purchase, account deletion, or level-20 run was performed in this audit.
