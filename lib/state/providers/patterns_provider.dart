import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/patterns/patterns_engine.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
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

/// Patterns for the signed-in account: saved tasks (the full history, not only
/// open ones), habits and habit check-ins. Empty when storage is not writable
/// and when the account changes while it is being read. Not kept alive: it is
/// read again each time the screen opens, so a task finished elsewhere shows.
final patternsProvider = FutureProvider.autoDispose<PatternsResult>((
  Ref ref,
) async {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final int rangeDays = ref.watch(patternsRangeDaysProvider);
  final DateTime now = ref.watch(patternsClockProvider)();
  if (!scope.isWritable) {
    return PatternsResult.empty(now: now, rangeDays: rangeDays);
  }
  final AccountOperation owner = AccountOperation.capture(ref);
  try {
    final List<TaskEntity> tasks = await owner.wait(
      ref.watch(getTasksUseCaseProvider).call(),
    );
    // Read from the account-scoped store, not from habitsProvider: that one
    // keeps its list until the account fence invalidates it, so right after
    // an account change it could still hold the previous account's habits.
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
