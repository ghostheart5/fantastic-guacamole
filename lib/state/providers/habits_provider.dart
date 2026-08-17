import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/domain/entities/habit_record.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<HabitRecord>>(
  HabitsNotifier.new,
);

final habitProvider = habitsProvider;

/// Orchestrates the habit use cases. Persistence and list rules live in the
/// domain layer; reminder syncing and analytics stay here because they are
/// side effects of the surface, not habit rules.
class HabitsNotifier extends AsyncNotifier<List<HabitRecord>> {
  @override
  Future<List<HabitRecord>> build() async {
    final List<HabitRecord> habits = await ref
        .read(getHabitsUseCaseProvider)
        .call();
    await _syncReminders(habits);
    return habits;
  }

  List<HabitRecord> _currentHabits() {
    return state is AsyncData<List<HabitRecord>>
        ? (state as AsyncData<List<HabitRecord>>).value
        : const <HabitRecord>[];
  }

  Future<void> _syncReminders(List<HabitRecord> habits) {
    return ref
        .read(reminderOrchestratorServiceProvider)
        .syncHabitReminders(habits);
  }

  Future<void> _apply(
    List<HabitRecord> previous,
    List<HabitRecord> next,
  ) async {
    if (identical(previous, next)) {
      return;
    }
    await _syncReminders(next);
    state = AsyncData(next);
  }

  Future<void> addHabit({required String title}) async {
    final List<HabitRecord> current = _currentHabits();
    final List<HabitRecord> next = await ref
        .read(createHabitUseCaseProvider)
        .call(current: current, title: title);
    await _apply(current, next);
  }

  Future<void> toggleHabit(String id) async {
    final List<HabitRecord> current = _currentHabits();
    HabitRecord? toggled;
    for (final HabitRecord item in current) {
      if (item.id == id) {
        toggled = item;
        break;
      }
    }

    final List<HabitRecord> next = await ref
        .read(toggleHabitUseCaseProvider)
        .call(current: current, id: id);

    if (toggled != null && toggled.active) {
      AppAnalytics.track(
        'habit_completed',
        params: <String, Object?>{'has_habit_id': toggled.id.isNotEmpty},
      );
    }
    await _apply(current, next);
  }

  Future<void> renameHabit(String id, String title) async {
    final List<HabitRecord> current = _currentHabits();
    final List<HabitRecord> next = await ref
        .read(updateHabitUseCaseProvider)
        .call(current: current, id: id, title: title);
    await _apply(current, next);
  }

  Future<void> removeHabit(String id) async {
    final List<HabitRecord> current = _currentHabits();
    final List<HabitRecord> next = await ref
        .read(deleteHabitUseCaseProvider)
        .call(current: current, id: id);
    await _apply(current, next);
  }
}
