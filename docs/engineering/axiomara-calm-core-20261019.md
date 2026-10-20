# Axiomara: simpler daily flow, preserved intelligence

This candidate implements the owner's October 19, 2026 request to reduce overload while preserving Axiomara's core: create a goal, task, or habit; complete and track it; understand patterns; use AI/SI chat, predictions, and future outcomes.

## Source and scope

- Base: `832d972e50eeaffdd03ce61d16655fdf57806527`, the exact base declared by the supplied plain-language candidate ZIP.
- Worktree: `C:/jtmp/axiomara-calm-core-20261019`.
- Branch: `codex/axiomara-calm-core-20261019`.
- The supplied candidate patch is included, followed by the behavioral changes described here. This is a combined candidate, not a patch against an unknown installed version.
- The older, dirty public-release checkout was not edited. No production account, signing credentials, database, billing behavior, or AI model configuration was changed.

## Everyday experience

1. **Today** replaces the dense default dashboard. It shows up to three current tasks, direct completion controls, goal and habit entry points, and clear links to chat and insights. Unscheduled tasks remain eligible. A deadline due today remains eligible even if its planned work time is later.
2. **My plan** lists all active tasks, including undated tasks, plus separate completed tasks and notes. Goals, habits, and the actual schedule are directly reachable. Task completion stays visible; edit, skip, and removal sit in an overflow menu. All saved items remain reachable from the archive icon, including canceled records. The header scrolls in limited height, including a landscape keyboard.
3. **Insights** retains the existing trajectory, prediction, scenario comparison, custom what-if, tracking, calibration, and evidence systems. Patterns/progress have an explicit entry point. Task predictions have a named disclosure instead of being buried inside model-source details.
4. **Chat** is a primary tab and retains the AI/SI implementation and its existing consent, credit-price, account, safety, and source-inspection controls.
5. The previous dense Home remains available as an optional detailed daily review. It is no longer the default landing screen.

## Creation and completion

- A task or goal starts with a title. Descriptions, scheduling, dates, estimates, priority, recurrence, and goal links remain available through optional controls. Habits retain visible cadence and target controls; notes retain their body field.
- Explicit manual item choices pause the active first-task exercise so a chosen goal or habit cannot silently become a scheduled task tutorial. Lessons remain available from Settings.
- Ordinary manually entered items use one visible Save action, through the existing staged, token-bound confirmation transaction. This is not a new direct repository write path.
- AI planner drafts, guided setup, and items carrying bound Person Context evidence still require review before confirmation.
- The saved result exposes undo and readback. The form is hidden after saving; New item starts with a blank form.
- Existing task actions and habit controls continue to record outcomes and feed tracking/intelligence. Pending completion cannot be tapped twice, write failures do not announce success, and account changes suppress the old account's result.

## Navigation compatibility

The primary tabs are Today, My plan, Insights, and Chat. Existing canonical paths, aliases, access classes, stored entities, and package identifiers remain. The `/timeline` primary destination now presents My plan; the actual schedule is opened from My plan or the saved-result schedule action. Guided Timeline review continues to mount its real schedule targets. Numeric legacy tab preferences retain their previous meanings; newer selections also save the named destination. Profile remains available through Tools.

## Validation boundaries

Machine-readable runs, the rendered Today preview, source hashes, and the build outcome are delivered alongside the candidate. Inspect those receipts for exact counts and exit status; early failed attempts are preserved separately from the final verification.

Windows visual snapshots for the optional detailed review were inspected and refreshed for intentional changes from the supplied plain-language patch. Linux snapshots were not refreshed: the local Docker Linux engine is unavailable. Linux golden reconciliation remains required before cross-platform CI/release acceptance. No passing Windows test is presented as proof of a Play-installed build or a human usability result.

The Android QA artifact, when built successfully, uses the existing local QA configuration and separate `.qa` package. It is for interface/local-flow review; it does not establish that paid external AI or live cloud recovery was exercised. This candidate is not a Google Play submission or publication.

## October 20 follow-up

Today uses an honest empty state for its active-task feed and points to My plan for history. Runtime review established that this provider excludes completed tasks, so the final copy does not try to infer completed history from that feed. Future scheduled tasks retain their separate message. English, Spanish, and the actual empty active-list case are checked in the focused Today regression.

The connected Moto was read-only inspected. Its active Android user was 0 (personal); available Axiomara test profiles were 10, 11, and 13. No app was installed, launched, cleared, or uninstalled, and no profile was switched automatically. Device validation awaits an unlocked test profile selected by the owner. These observations do not establish a device pass.

Remaining habit rename, pause/resume, removal, and failure messages now consistently use habit instead of Daily Rhythm in English and Spanish. The 10 existing habit behavior checks passed after the wording change. The 16 focused Today checks also passed. Static analysis reported no issues.

## Emulator-driven corrections on October 20

The owner selected a computer emulator instead of the physical Moto. A fresh Android 15 (API 35), x86-64, 360 x 640 dp emulator was created as `axiomara_calm_core_20261020`, serial `emulator-5580`. Only the separate local QA package was installed. Physical-device profiles were not modified.

Actual UI review exposed three additional daily-flow problems: optional setup hid its skip action below the first viewport; pausing one guide step allowed the next step to interrupt ordinary creation; and a second Add action could reopen an earlier saved receipt. Setup now exposes Go to Today at the top, opting out pauses all three core steps until an explicit guide restart, and explicit manual creation opens a fresh form for the chosen kind. In-flight save and undo protections remain in the existing transaction controller.

Saved-result actions now open the matching habits, goals, or notes screen. Dated tasks retain Open schedule; undated tasks retain Browse saved tasks. Habit maintenance actions sit under Habit options, with completion, skipping, and correction kept directly reachable. Ordinary creation copy now describes the one-step Save behavior accurately.

The affected regression run passed 148 checks. Full analysis found only two redundant imports; both were removed and the focused fatal-info recheck passed. The earlier failing layout and initial helper attempts remain in the receipts. Emulator UI evidence and final runtime coverage are recorded separately from host checks in the delivery verification folder.

## Runtime evidence and final copy follow-up

On the v3/v4 emulator builds, actual UI checks verified local profile entry; visible setup exit; a task saved with its exact typed title and reopened after process restart; completion in My plan; preserved task and habit outcomes after emulator restart and an APK update; goal save and direct readback; a fresh task form after saving a goal; a goal-linked task; the forecast insufficient-history state; the unlocked conditional forecast after three synthetic task outcomes; a 7-to-30-day horizon switch; a modeled path for an active task; a local SI answer using that saved task; and the habit receipt's direct Habits destination. These are synthetic emulator observations, not human acceptance or a live cloud/paid-AI test.

The final v5 app-code change from v4 is limited to accurate Today empty-state wording. Its 16 focused Today checks passed. The prior empty-state fixture included completed tasks, while the shipping feed excludes them; the final test also covers the actual empty active list. Earlier failed helper attempts and regression receipts are retained. One habit readback helper assertion was issued after scrolling the new habit title offscreen; the preceding archived UI tree contains the correct habit readback. This is not recorded as a new app failure or hidden as an all-green automation session.

The reminder service reported a saved-change/reminder-update warning in the emulator. Saved habit outcomes were verified separately; native reminder delivery was not verified. Linux goldens and live production/paid-provider behavior remain outside this candidate's acceptance evidence.
