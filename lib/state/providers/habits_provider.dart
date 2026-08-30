import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
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
    final List<HabitEntity> habits = await ref
        .read(getHabitsUseCaseProvider)
        .call();
    await _syncReminders(habits);
    return habits;
  }

  List<HabitEntity> _currentHabits() {
    return state is AsyncData<List<HabitEntity>>
        ? (state as AsyncData<List<HabitEntity>>).value
        : const <HabitEntity>[];
  }

  Future<void> _syncReminders(List<HabitEntity> habits) {
    return ref
        .read(reminderOrchestratorServiceProvider)
        .syncHabitReminders(habits);
  }

  Future<void> _apply(
    List<HabitEntity> previous,
    List<HabitEntity> next,
  ) async {
    if (identical(previous, next)) {
      return;
    }
    await _syncReminders(next);
    state = AsyncData(next);
  }

  Future<void> addHabit({required String title}) async {
    final List<HabitEntity> current = _currentHabits();
    final List<HabitEntity> next = await ref
        .read(createHabitUseCaseProvider)
        .call(current: current, title: title);
    await _apply(current, next);
  }

  Future<void> toggleHabit(String id) async {
    final List<HabitEntity> current = _currentHabits();
    HabitEntity? toggled;
    for (final HabitEntity item in current) {
      if (item.id == id) {
        toggled = item;
        break;
      }
    }

    final List<HabitEntity> next = await ref
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
    await _apply(current, next);
  }

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
    return result;
  }

  Future<void> renameHabit(String id, String title) async {
    final List<HabitEntity> current = _currentHabits();
    final List<HabitEntity> next = await ref
        .read(updateHabitUseCaseProvider)
        .call(current: current, id: id, title: title);
    await _apply(current, next);
  }

  Future<void> removeHabit(String id) async {
    final List<HabitEntity> current = _currentHabits();
    final List<HabitEntity> next = await ref
        .read(deleteHabitUseCaseProvider)
        .call(current: current, id: id);
    await _apply(current, next);
  }
}
