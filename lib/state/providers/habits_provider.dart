import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/rhythm_planning_provider.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<HabitEntity>>(
  HabitsNotifier.new,
);

final habitProvider = habitsProvider;

/// Orchestrates the habit use cases. Persistence and list rules live in the
/// domain layer; reminder syncing and analytics stay here because they are
/// side effects of the surface, not habit rules.
class HabitsNotifier extends AsyncNotifier<List<HabitEntity>> {
  @override
  Future<List<HabitEntity>> build() async {
    final owner = AccountOperation.capture(ref);
    return runAccountStorageMutation(() async {
      owner.check();
      final List<HabitEntity> habits = await ref
          .read(getHabitsUseCaseProvider)
          .call();
      owner.check();
      try {
        await _syncReminders(habits);
      } on Object catch (error, stack) {
        Logger.errorCategory(
          'RhythmReminderSync',
          'Rhythms loaded; reminder update needs retry.',
          error,
          stack,
        );
      }
      owner.check();
      return habits;
    });
  }

  Future<void> _syncReminders(List<HabitEntity> habits) {
    return ref
        .read(reminderOrchestratorServiceProvider)
        .syncHabitReminders(habits);
  }

  Future<void> _mutate(
    Future<List<HabitEntity>> Function(List<HabitEntity> current) change,
  ) async {
    final owner = AccountOperation.capture(ref);
    try {
      await runAccountStorageMutation(() async {
        owner.check();
        // Screen, Creator and restore writers share this lock. UI snapshots
        // are never authoritative inputs for a later replacement write.
        final current = await owner.wait(
          ref.read(domainHabitRepositoryProvider).getHabits(),
        );
        final next = await owner.wait(change(current));
        state = AsyncData(next);
        if (identical(current, next)) return;
        ref.invalidate(rhythmPlanningProvider);
        try {
          await _syncReminders(next);
        } on Object catch (error, stack) {
          owner.check();
          Logger.errorCategory(
            'RhythmReminderSync',
            'Rhythm saved; reminder update needs retry.',
            error,
            stack,
          );
          throw RhythmReminderSyncException();
        }
      });
    } on StaleAccountOperation {
      // A captured repository can finish its own account's write, but must
      // not update another account's screen or reminders.
      return;
    }
  }

  Future<void> retryReminders() async {
    final owner = AccountOperation.capture(ref);
    await runAccountStorageMutation(() async {
      owner.check();
      final habits = await owner.wait(
        ref.read(domainHabitRepositoryProvider).getHabits(),
      );
      await owner.wait(_syncReminders(habits));
    });
  }

  Future<void> addHabit({required String title}) => _mutate(
    (current) => ref
        .read(createHabitUseCaseProvider)
        .call(current: current, title: title),
  );

  Future<void> toggleHabit(String id) => _mutate((current) async {
    final toggled = current.where((habit) => habit.id == id).firstOrNull;
    final next = await ref
        .read(toggleHabitUseCaseProvider)
        .call(current: current, id: id);
    if (toggled != null) {
      AppAnalytics.track(
        'habit_status_changed',
        params: <String, Object?>{
          'has_habit_id': toggled.id.isNotEmpty,
          'paused': toggled.active,
        },
      );
    }
    return next;
  });

  Future<HabitOccurrenceResult> completeHabit(String id) async {
    final HabitOccurrenceCoordinator? coordinator = ref.read(
      habitOccurrenceCoordinatorProvider,
    );
    if (coordinator == null) {
      throw StateError('Daily Rhythm outcomes require a verified account.');
    }
    final HabitOccurrenceResult result = await coordinator.complete(id);
    ref.invalidate(habitOccurrencesProvider);
    ref.invalidate(decisionOutcomesProvider);
    await ref.read(decisionOutcomeActionsProvider).reconcileRetention();
    if (result.mutation == HabitOccurrenceMutation.applied) {
      AppAnalytics.track(
        'habit_completed',
        params: <String, Object?>{'has_habit_id': id.trim().isNotEmpty},
      );
    }
    return result;
  }

  Future<HabitOccurrenceResult> skipHabit(String id) async {
    final HabitOccurrenceCoordinator? coordinator = ref.read(
      habitOccurrenceCoordinatorProvider,
    );
    if (coordinator == null) {
      throw StateError('Daily Rhythm outcomes require a verified account.');
    }
    final HabitOccurrenceResult result = await coordinator.skip(id);
    ref.invalidate(habitOccurrencesProvider);
    ref.invalidate(decisionOutcomesProvider);
    await ref.read(decisionOutcomeActionsProvider).reconcileRetention();
    return result;
  }

  Future<void> renameHabit(String id, String title) => _mutate(
    (current) => ref
        .read(updateHabitUseCaseProvider)
        .call(current: current, id: id, title: title),
  );

  Future<void> removeHabit(String id) => _mutate(
    (current) =>
        ref.read(deleteHabitUseCaseProvider).call(current: current, id: id),
  );
}

/// The data save succeeded; retrying it would misrepresent the result.
class RhythmReminderSyncException extends StateError {
  RhythmReminderSyncException()
    : super('Your change was saved, but reminders could not update.');
}
