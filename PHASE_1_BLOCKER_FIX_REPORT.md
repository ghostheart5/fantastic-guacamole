# Phase 1 Blocker Fix Report

Scope: the four verified production blockers below only. No architecture cleanup, no renames, no
migration/config/auth changes. Nothing in this phase was committed; all changes remain in the
working tree pending explicit instruction to commit.

## Files changed

Production code:
- `lib/state/providers/domain_usecase_providers.dart` (Fix 1)
- `lib/features/si_console/ui/si_console_screen.dart` (Fix 2)
- `lib/domain/usecases/switch_theme.dart` (Fix 3)
- `lib/state/providers/theme_provider.dart` (Fix 3 — sole call site of `SwitchTheme`, updated only because its return type changed)
- `lib/features/plan/ui/plan_screen.dart` (Fix 4)

Tests:
- `test/state/providers/complete_task_use_case_provider_test.dart` (new — Fix 1)
- `test/features/si_console/si_console_screen_test.dart` (updated, one test appended — Fix 2)
- `test/domain/usecases/theme_identity_usecases_test.dart` (updated — Fix 3)
- `test/features/plan/plan_screen_date_filtering_test.dart` (new — Fix 4)

No other files were touched. The working tree also contains unrelated pre-existing modified/untracked
files from earlier phases of this engagement (e.g. audit reports, voice/STT controller work, Supabase
function/migration drafts) — none of those were read for or affected by this phase's fixes.

## Exact fixes made

### Fix 1 — CompleteTask canonical progression wiring
`completeTaskUseCaseProvider` previously constructed `CompleteTask` with only the task repository, so
its optional `progressionRepo`/`siRepo` dependencies were never supplied and `AwardXp`/SI-state side
effects silently never ran when a task was completed through the real provider graph.

```dart
// Before
final completeTaskUseCaseProvider = Provider<CompleteTask>((ref) {
  return CompleteTask(ref.read(domainTaskRepositoryProvider));
});

// After
final completeTaskUseCaseProvider = Provider<CompleteTask>((ref) {
  return CompleteTask(
    ref.read(domainTaskRepositoryProvider),
    progressionRepo: ref.read(domainProgressionRepositoryProvider),
    siRepo: ref.read(domainSiRepositoryProvider),
  );
});
```

`CompleteTask` itself, `ProfileController`, and `AwardXp` were not modified. Note: the real, user-visible
XP/level path (`ProfileController` via `TaskActions.completeTask()` → `addXP`) is a separate call path
from `IProgressionRepository`, so this fix does not create a double-XP-award risk.

### Fix 2 — SI crisis detection order
In `si_console_screen.dart`'s `_send()`, crisis detection ran after `_handleLocalCommand(text)`, so a
crisis phrase prefixed with a slash command (e.g. `/tasks i want to kill myself`) would be swallowed as
a local command and never checked for crisis content.

```dart
// Before
void _send() {
  final String text = _input.text.trim();
  if (text.isEmpty) return;

  if (_handleLocalCommand(text)) {
    _input.clear();
    return;
  }
  _input.clear();

  if (ref.read(siConsoleQueryControllerProvider).detectsCrisis(text)) {
    showCrisisDialog(context);
    return;
  }
  ...
}

// After
void _send() {
  final String text = _input.text.trim();
  if (text.isEmpty) return;

  if (ref.read(siConsoleQueryControllerProvider).detectsCrisis(text)) {
    showCrisisDialog(context);
    return;
  }

  if (_handleLocalCommand(text)) {
    _input.clear();
    return;
  }
  _input.clear();
  ...
}
```

The crisis-check call site (`ref.read(siConsoleQueryControllerProvider).detectsCrisis(text)`) and
`showCrisisDialog(context)` are unchanged — only their position moved — so this preserves
`check_architecture.ps1` conformance and existing crisis UI/message behavior.

### Fix 3 — SwitchTheme data-loss bug
`SwitchTheme.call()` previously fell back to `AppThemeEntity.defaultTheme()` and persisted it whenever
the requested id didn't match a known theme, overwriting the user's real saved theme with the default.

```dart
// Before
Future<AppThemeEntity> call(String id) async {
  final AppThemeEntity theme =
      await _repository.getThemeById(id) ?? AppThemeEntity.defaultTheme();
  await _repository.saveTheme(theme);
  return theme;
}

// After
Future<AppThemeEntity?> call(String id) async {
  final AppThemeEntity? theme = await _repository.getThemeById(id);
  if (theme == null) {
    return null;
  }
  await _repository.saveTheme(theme);
  return theme;
}
```

Unknown/stale ids are now a pure no-op: nothing is read or written beyond the failed lookup, and the
previously saved theme is left untouched. The return type changing to nullable required updating the
sole call site:

```dart
// lib/state/providers/theme_provider.dart — ThemeActions.switchTo()
Future<void> switchTo(String id) async {
  final AppThemeEntity? switched = await _ref.read(switchThemeUseCaseProvider).call(id);
  if (switched == null) {
    // Unknown/stale theme id: preserve the user's existing saved theme
    // rather than treating this as a successful switch.
    return;
  }
  _ref.invalidate(currentThemeProvider);
  _ref.invalidate(availableThemesProvider);
}
```

### Fix 4 — Smart Planner date filtering and past-block rendering
`PlanScreen` filtered blocks by weekday only (`block.start.weekday - 1 == _selectedDay`), so any
non-recurring task scheduled on the same weekday in a past or future week (e.g. last month) rendered as
if it belonged to the currently selected week.

Added a getter resolving the selected day-chip to a real calendar date, anchored to the current Mon–Sun
week (`DaySelector` itself only carries a weekday index, so this had to live in `_PlanScreenState`):

```dart
DateTime get _selectedDate {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime monday = today.subtract(Duration(days: today.weekday - 1));
  return monday.add(Duration(days: _selectedDay));
}
```

And changed the filter from weekday-only to exact-date matching:

```dart
// Before
final List<TimeBlock> blocks = allBlocks
    .where((block) => (block.start.weekday - 1) == _selectedDay)
    .toList(growable: false);

// After
final List<TimeBlock> blocks = allBlocks
    .where((block) {
      final DateTime selected = _selectedDate;
      return block.start.year == selected.year &&
          block.start.month == selected.month &&
          block.start.day == selected.day;
    })
    .toList(growable: false);
```

No changes were made to `calendar_service.dart`, `day_selector.dart`, or the recurrence/occurrence
generation logic — `CalendarService`'s occurrence generation was already exact-date-based; only this
UI-layer comparison was buggy. Recurring daily/weekly tasks are unaffected since their generated
occurrences already fall on real dates within the current planning window.

## Tests added/updated

- **`test/state/providers/complete_task_use_case_provider_test.dart`** (new) — builds the real provider
  graph (task/progression/SI repos overridden with fakes), calls `completeTaskUseCaseProvider` through
  `CompleteTask`, and asserts the task is marked complete, XP is awarded (`progressionRepository.xp >
  0`), and the SI repository receives a saved state with the expected confidence delta (0.55 from a
  0.5 baseline + 0.05).
- **`test/features/si_console/si_console_screen_test.dart`** (appended) — new widget test sends
  `/tasks i want to kill myself`, asserts the crisis dialog (`"You're not alone"`) renders, the AI
  controller is never invoked (`calls == 0`), and the local-command response (`SI COMMAND GUIDE`) does
  not render.
- **`test/domain/usecases/theme_identity_usecases_test.dart`** (updated) — existing happy-path test
  updated for the now-nullable return type; new test switches to `'stale-theme-id'` after saving a
  `dark` theme and asserts the switch returns `null` while `GetCurrentTheme` still reports `dark`.
- **`test/features/plan/plan_screen_date_filtering_test.dart`** (new) — widget test with three tasks
  (one scheduled 35 days ago on the same weekday as today, one scheduled for today, one daily-recurring)
  asserts the stale task is absent, today's task renders, and the recurring task renders.
- `test/domain/usecases/complete_task_test.dart` already covers `CompleteTask` at the domain level given
  explicit repos — left unmodified, no update needed.
- `test/features/plan/plan_screen_states_test.dart` and `test/features/plan/plan_screen_completion_test.dart`
  were not modified and still pass unchanged after the Fix 4 filtering change.

## Commands run

All flutter invocations required explicit env vars to avoid a flutter-tool crash under this git-bash
environment:
```
env 'ProgramFiles(x86)=C:\Program Files (x86)' APPDATA='...\AppData\Roaming' LOCALAPPDATA='...\AppData\Local' flutter <command>
```

- `flutter analyze` — full project
- `flutter test test/state/providers/complete_task_use_case_provider_test.dart`
- `flutter test test/features/si_console/si_console_screen_test.dart`
- `flutter test test/domain/usecases/theme_identity_usecases_test.dart`
- `flutter test test/features/plan/`
- `flutter test` — full suite (final verification pass)

Integration tests exist under `integration_test/` and are declared in `pubspec.yaml`, but require a
device/emulator and were **not executed**. Listed for completeness only, no results claimed:
`agent_orchestrator_integration_test.dart`, `ai_controller_integration_test.dart`,
`ai_memory_selection_integration_test.dart`, `app_startup_test.dart`, `auth_flow_integration_test.dart`,
`offline_sync_roundtrip_integration_test.dart`, `paywall_gate_test.dart`, `persistence_recovery_test.dart`,
`si_console_flow_test.dart`, `si_engine_guardrails_integration_test.dart`, `task_lifecycle_test.dart`.

## Passing/failing results

- `flutter analyze`: **No issues found!** (one `prefer_const_constructors` lint was surfaced and fixed
  during development of the Fix 4 test, before this final clean run.)
- `flutter test` (full suite): **All tests passed!** — 600 tests, 0 failures.
- Every scoped run listed above passed individually during development, with no regressions in
  adjacent/pre-existing test files.

## Remaining risks

1. **SI confidence delta does not reach the user-visible `SIState.confidence` field.** `CompleteTask`
   computes an SI-state update via `withConfidenceDelta(0.05)` and this is verified at the domain
   repository contract by the new Fix 1 test. However, `_SiRepositoryAdapter.saveState()` (in
   `domain_usecase_providers.dart`) only forwards `energy`/`fatigue` into
   `SIStateController.replaceState()`, which has no `confidence` parameter — the confidence delta is
   silently dropped before it reaches the real, UI-visible SI state. This is a pre-existing
   domain/adapter contract gap, not introduced by Fix 1, and was intentionally left unfixed to stay
   within Fix 1's surgical scope ("do not rewrite SI Console architecture").
2. **Integration tests were not run** (see list above) — they need a device/emulator, which was not
   available in this environment. No pass/fail is claimed for them.
3. The working tree contains other uncommitted, unrelated work from earlier phases of this engagement
   (audit reports, voice/STT wiring, Supabase function/migration drafts, env/config changes). None of
   it was touched, read for context, or affected by these four fixes.

Per instructions, stopping here — no further architecture cleanup undertaken.
