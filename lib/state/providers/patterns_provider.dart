import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/patterns/patterns_engine.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The range the Patterns screen shows: 7 or 30 days. Starts at 7.
final patternsRangeDaysProvider =
    NotifierProvider<PatternsRangeDaysNotifier, int>(
      PatternsRangeDaysNotifier.new,
    );

class PatternsRangeDaysNotifier extends Notifier<int> {
  @override
  int build() => PatternsEngine.ranges.first;

  /// Only 7 or 30; anything else is refused and the range stays as it was.
  void set(int days) {
    if (!PatternsEngine.ranges.contains(days)) {
      throw ArgumentError.value(days, 'days', 'must be 7 or 30');
    }
    state = days;
  }
}

/// The moment Patterns is worked out for. Tests replace it.
final patternsClockProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
);

/// How long until the local day changes after [now]: until the next local
/// midnight plus one second. Calendar fields, so a clock change cannot skew it.
Duration patternsDayRolloverDelay(DateTime now) {
  final DateTime local = now.toLocal();
  final DateTime nextMidnight = DateTime(
    local.year,
    local.month,
    local.day + 1,
  );
  return nextMidnight.difference(local) + const Duration(seconds: 1);
}

/// Patterns for the signed-in account: saved tasks (the full history, not only
/// open ones), habits and habit check-ins. Empty when storage is not writable
/// and when the account changes while it is being read.
///
/// Live while it stays alive (the tabs stay mounted): it is worked out again
/// when a task is saved, when the habit list changes, when a check-in is
/// recorded and when the local day changes. The task and habit providers are
/// only change triggers; the data is read from the account-scoped stores under
/// an account lease, so nothing of another account can be shown.
final patternsProvider = FutureProvider<PatternsResult>((Ref ref) async {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final int rangeDays = ref.watch(patternsRangeDaysProvider);
  final DateTime now = ref.watch(patternsClockProvider)();
  if (!scope.isWritable) {
    return PatternsResult.empty(now: now, rangeDays: rangeDays);
  }
  // Change triggers, never awaited. The first load of each is skipped: this
  // provider reads the stores itself.
  void refreshOnChange<T>(AsyncValue<T>? previous, AsyncValue<T> next) {
    if (next.isLoading || previous == null || !previous.hasValue) return;
    ref.invalidateSelf();
  }

  ref.listen(allTasksProvider, refreshOnChange<List<Task>>);
  ref.listen(habitsProvider, refreshOnChange<List<HabitEntity>>);
  final Timer rollover = Timer(patternsDayRolloverDelay(now), () {
    ref.invalidateSelf();
  });
  ref.onDispose(rollover.cancel);

  final AccountOperation owner = AccountOperation.capture(ref);
  try {
    final List<TaskEntity> tasks = await owner.wait(
      ref.watch(getTasksUseCaseProvider).call(),
    );
    // Read from the account-scoped store under the lease, so the list is
    // always the current account's; habitsProvider only triggers a refresh.
    final List<HabitEntity> habits = await owner.wait(
      ref.watch(getHabitsUseCaseProvider).call(),
    );
    final List<HabitOccurrenceEntity> occurrences = await owner.wait(
      ref.watch(habitOccurrencesProvider.future),
    );
    return PatternsEngine.compute(
      tasks: tasks,
      habits: habits,
      occurrences: occurrences,
      now: now,
      rangeDays: rangeDays,
    );
  } on StaleAccountOperation {
    // The account changed under this read: show nothing of it. The provider
    // rebuilds for the new account.
    return PatternsResult.empty(now: now, rangeDays: rangeDays);
  }
});
