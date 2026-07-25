# ChronoSpark Master Audit + Release Checklist (Detailed)

Date: 2026-07-24
Release: 
Auditor: 
Build/Commit: 

## 2. Baseline Backup + Environment Audit
Before fixing anything, prove the project state, Flutter state, and recoverability.

- [ ] Git status captured before edits.
- [ ] Current branch name recorded.
- [ ] Local backup or zip snapshot created before bulk changes.
- [ ] flutter --version captured.
- [ ] dart --version captured.
- [ ] flutter doctor -v reviewed.
- [ ] Connected emulator/physical device confirmed.
- [ ] Known issue log created for current blockers.
- [ ] No terminal is running a long command before starting next audit.
- [ ] Last known good commit/tag recorded.

### Suggested first commands
Use one command at a time. Do not paste separators or sample output into PowerShell.

| Purpose | Command |
|---|---|
| Confirm project folder | pwd |
| Check git status | git status --short |
| Check Flutter install | flutter --version |
| Check Dart install | dart --version |
| Check doctor output | flutter doctor -v |
| Check devices | flutter devices |
| Branch name | git branch --show-current |
| Last good commit/tag candidates | git log --oneline -n 20; git tag --sort=-creatordate | Select-Object -First 20 |

## 3. Analyze / Test / Build Gate
This gate answers: does the codebase pass the basic machine checks before claiming features are healthy?

- [ ] flutter pub get succeeds.
- [ ] flutter analyze returns 0 issues.
- [ ] flutter test runs existing tests without failures.
- [ ] Debug launch succeeds on emulator.
- [ ] Debug launch succeeds on physical Android device if available.
- [ ] Release build command is documented.
- [ ] Android build does not fail from Gradle/Kotlin/plugin mismatch.
- [ ] No generated or stale file creates analyzer noise.
- [ ] Critical warnings are treated as future release blockers, even if not errors.

### Actual test types you should have
| Test type | What it proves | ChronoSpark examples |
|---|---|---|
| Unit tests | Pure logic works without UI. | SI ranking, trial counters, task lifecycle, persistence serializers. |
| Widget tests | Screen/component renders and responds to taps. | Nexus cards, Smart Coach back button, settings toggles, paywall cards. |
| Integration tests | Whole app flow works on device/emulator. | Launch, add task, complete task, restart, verify persisted state. |
| Patrol/Maestro E2E | Human-like tapping/typing/native dialogs. | Open every tab, type task, back out of Smart Coach, permission prompts. |
| Golden/visual tests | Screens do not visually regress. | Nexus, Plan, Reflect, Settings in dark theme and small screen. |
| Performance tests | Flow timing and jank remain acceptable. | Startup hydration, SI recompute, log list scrolling, animation smoothness. |

## 4. Dead Code + Disconnected Wiring Audit
Your project has had many files flagged as dead even though some are expected to be connected. This audit separates real dead code from missing wiring.

### Decision rules
- [ ] If a file is a real feature screen, it is reachable from navigation or linked from parent feature.
- [ ] If a file is a provider/controller/repository, at least one UI or service layer reads it.
- [ ] If a file is future-only, move it to a documented archive/future folder, not active release code.
- [ ] If a file duplicates another implementation, choose one source of truth before writing tests.
- [ ] Never delete first. Mark as CONNECT, ARCHIVE, MERGE, or CUT FROM V1.

### Wiring checklist
- [ ] Screen imported by route/navigation shell or parent screen.
- [ ] Controller/provider imported by screen.
- [ ] Provider connected to repository/service.
- [ ] Repository connected to storage/API/mock source.
- [ ] State changes trigger UI refresh.
- [ ] Errors surface as safe UI state, not crashes.
- [ ] Feature has at least one smoke test after wiring.

## 5. Provider / Controller / Repository Audit
ChronoSpark should feel engineered, not random. UI should not own business logic; providers/controllers should coordinate state; repositories/services should own persistence or external calls.

- [ ] Every feature has a clear owner: UI, controller/provider, repository/service, model/entity.
- [ ] No screen directly mutates unrelated global state without a provider/controller boundary.
- [ ] Async providers expose loading, data, and error states.
- [ ] Critical providers are not auto-disposed if state must survive tab switch.
- [ ] Provider invalidation is intentional and logged during debugging.
- [ ] No circular dependency between providers.
- [ ] Mock and production services are separated cleanly.
- [ ] Test doubles exist or can be injected for billing, persistence, notifications, and SI engine.

### Provider flow target
UI Screen -> Feature Controller/Notifier -> Repository/Service -> Storage/API/Engine -> Result State -> UI renders data/error/empty/loading.

## 6. Navigation + Back Button Release Blocker Audit
This is critical because your recent crash path was Smart Coach -> Back -> Nexus. Any crash from a normal back press is a release blocker.

- [ ] Every bottom nav tab opens without crash.
- [ ] Every feature entry opens without crash.
- [ ] Every screen has a defined back behavior.
- [ ] Back from Smart Coach returns to Nexus without losing state.
- [ ] Back from modal/overlay closes overlay first.
- [ ] Back from nested route returns to parent route.
- [ ] Back at root does not crash or leave app in corrupt state.
- [ ] No setState/use-after-dispose errors on back.
- [ ] No provider read after disposed state on route pop.
- [ ] Route arguments validated before screen build.
- [ ] Deep links either work or are disabled for v1.

### Minimum navigation smoke tests
| Flow | Expected result |
|---|---|
| Launch -> Nexus | Nexus visible, no crash. |
| Nexus -> Smart Coach -> Back | Returns to Nexus, no lost connection. |
| Nexus -> Add -> Back | Returns to Nexus or previous tab safely. |
| Open all bottom tabs | Each renders with loading/empty/error states safely. |
| Settings -> Paywall -> Back | Returns to Settings without trial counter corruption. |

## 7. Core Feature Flow Audit
| Flow | Audit target |
|---|---|
| Launch + hydrate | App starts, reads local snapshot, handles empty/malformed snapshot, shows Nexus. |
| Create task | User taps Add, enters title/details, saves, sees task in list, SI recomputes. |
| Complete task | User completes task, log entry created, adaptive learning updates, notification safe. |
| Skip/delay task | User can postpone without duplicate/corrupted state. |
| Plan / Temporal Ops | Time blocks render, overlaps prevented, premium trial quota enforced. |
| SI Console | Command parser handles valid/invalid input, response appears, action logged. |
| Reflect / ChronoLogs | Logs load, filters/search safe, empty state readable. |
| Settings | Preferences save, subscription tier visible, privacy/support links present. |
| Smart Coach | Advice renders from existing state, back navigation safe, no null crash. |

## 8. Persistence + Data Integrity Audit
- [ ] Fresh install creates default safe state.
- [ ] Existing snapshot loads correctly.
- [ ] Malformed snapshot does not crash app.
- [ ] Schema version is stored.
- [ ] Migration path exists for future fields.
- [ ] Task create/complete/skip/delay persists across restart.
- [ ] Trial counters persist across restart.
- [ ] Subscription status persists or re-checks safely.
- [ ] Logs persist but do not store private secrets unnecessarily.
- [ ] Export/import path is planned or intentionally cut from v1.
- [ ] Clear/reset data option exists or is planned for privacy compliance.
- [ ] Data deletion/account deletion behavior documented if accounts/cloud sync exist.

### Persistence test cases
| Case | Expected result |
|---|---|
| No saved data | Default app loads. |
| Valid saved data | Exact tasks/settings/logs return. |
| Unknown fields | Ignored or migrated safely. |
| Missing fields | Defaults applied. |
| Corrupt JSON | Error handled, recovery offered, no crash. |
| Large log history | List remains smooth and memory safe. |

## 9. Actual Test Suite You Should Build
Start small. The first goal is not huge coverage; it is release protection for the flows most likely to break.

### Recommended folder structure
| Folder/file | Purpose |
|---|---|
| test/unit/app_state_test.dart | Task lifecycle, trial counters, decision updates. |
| test/unit/si_engine_test.dart | Energy/workload/deadline ranking logic. |
| test/unit/persistence_test.dart | Snapshot encode/decode/migration/corruption handling. |
| test/widget/nexus_screen_test.dart | Nexus renders core cards and empty states. |
| test/widget/smart_coach_screen_test.dart | Smart Coach opens and back behavior at widget level. |
| test/widget/settings_test.dart | Settings, paywall, subscription state UI. |
| integration_test/launch_flow_test.dart | Launch, hydrate, open Nexus. |
| integration_test/task_lifecycle_test.dart | Create task -> complete -> restart -> verify. |
| integration_test/navigation_smoke_test.dart | Open tabs, back out of Smart Coach and Settings. |
| e2e/maestro/*.yaml or patrol_test/*.dart | Human-like tapping, typing, scrolling, native dialogs. |

### Minimum first 20 tests
- [ ] AppState creates a task.
- [ ] AppState completes a task.
- [ ] AppState skips a task.
- [ ] AppState delays a task.
- [ ] Trial counter increments for Temporal Ops.
- [ ] Trial counter blocks after quota.
- [ ] Premium bypasses trial quota.
- [ ] Downgrade preserves data.
- [ ] SI Engine returns a non-null recommendation.
- [ ] SI Engine handles empty task list.
- [ ] Adaptive learning records completion.
- [ ] RuntimePersistence saves snapshot.
- [ ] RuntimePersistence loads snapshot.
- [ ] RuntimePersistence handles missing fields.
- [ ] RuntimePersistence handles corrupt data.
- [ ] Nexus renders with empty state.
- [ ] Settings renders subscription cards.
- [ ] Smart Coach renders without crashing.
- [ ] Integration launch test passes.
- [ ] Navigation back from Smart Coach passes.

## Execution Log
- Date/Time:
- Auditor:
- Commands run:
- Key failures:
- Linked issue IDs:
- Retest result:
