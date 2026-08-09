import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<HabitRecord>>(
  HabitsNotifier.new,
);

final habitProvider = habitsProvider;

class HabitsNotifier extends AsyncNotifier<List<HabitRecord>> {
  @override
  Future<List<HabitRecord>> build() async {
    final List<HabitRecord> habits = await _repository.getHabits();
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncHabitReminders(habits);
    return habits;
  }

  HabitRepository get _repository => ref.read(habitRepositoryProvider);

  List<HabitRecord> _currentHabits() {
    return state is AsyncData<List<HabitRecord>>
        ? (state as AsyncData<List<HabitRecord>>).value
        : const <HabitRecord>[];
  }

  Future<void> addHabit({required String title}) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    final HabitRecord habit = HabitRecord(
      id: now.microsecondsSinceEpoch.toString(),
      title: trimmed,
    );

    final List<HabitRecord> current = _currentHabits().toList(growable: true);
    current.insert(0, habit);

    await _repository.saveHabits(current);
    await ref
        .read(timelineActionsProvider)
        .connectHabit(
          HabitEntity(
            id: habit.id,
            title: habit.title,
            createdAt: now,
            status: habit.active ? HabitStatus.active : HabitStatus.paused,
          ),
        );
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncHabitReminders(current);
    state = AsyncData(current);
  }

  Future<void> toggleHabit(String id) async {
    final List<HabitRecord> current = _currentHabits().toList(growable: false);
    HabitRecord? toggled;
    for (final HabitRecord item in current) {
      if (item.id == id) {
        toggled = item;
        break;
      }
    }
    final List<HabitRecord> next = current
        .map(
          (HabitRecord item) => item.id == id
              ? item.copyWith(
                status: item.active
                  ? HabitStatus.paused
                  : HabitStatus.active,
                updatedAt: DateTime.now(),
                )
              : item,
        )
        .toList(growable: false);

    await _repository.saveHabits(next);
    if (toggled != null && toggled.active) {
      AppAnalytics.track(
        'habit_completed',
        params: <String, Object?>{'habit_id': toggled.id},
      );
    }
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncHabitReminders(next);
    state = AsyncData(next);
  }

  Future<void> removeHabit(String id) async {
    final List<HabitRecord> current = _currentHabits().toList(growable: false);
    final List<HabitRecord> next = current
        .where((HabitRecord item) => item.id != id)
        .toList(growable: false);
    await _repository.saveHabits(next);
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncHabitReminders(next);
    state = AsyncData(next);
  }
}
