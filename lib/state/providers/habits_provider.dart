import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
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
    final List<HabitRecord> next = current
        .map(
          (HabitRecord item) => item.id == id
              ? item.copyWith(
                  status: item.active ? HabitStatus.paused : HabitStatus.active,
                  updatedAt: DateTime.now(),
                )
              : item,
        )
        .toList(growable: false);

    await _repository.saveHabits(next);
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncHabitReminders(next);
    state = AsyncData(next);
  }

  Future<HabitOccurrenceMutation> completeHabitOccurrence(
    String habitId, {
    DateTime? at,
    int? ordinal,
  }) => _recordOccurrence(
    habitId,
    HabitOccurrenceStatus.completed,
    at: at,
    ordinal: ordinal,
  );

  Future<HabitOccurrenceMutation> skipHabitOccurrence(
    String habitId, {
    DateTime? at,
    int? ordinal,
  }) => _recordOccurrence(
    habitId,
    HabitOccurrenceStatus.skipped,
    at: at,
    ordinal: ordinal,
  );

  Future<HabitOccurrenceMutation> _recordOccurrence(
    String habitId,
    HabitOccurrenceStatus status, {
    DateTime? at,
    int? ordinal,
  }) async {
    final HabitRecord habit = _currentHabits().firstWhere(
      (HabitRecord item) => item.id == habitId && item.active,
      orElse: () => throw StateError('Active habit "$habitId" is unavailable.'),
    );
    final DateTime timestamp = at ?? DateTime.now();
    final String periodKey = HabitOccurrencePeriodKey.forDate(
      habit.cadence,
      timestamp,
    );
    final HabitOccurrenceRepository repository = ref.read(
      habitOccurrenceRepositoryProvider,
    );
    final List<HabitOccurrence> existing = await repository
        .listOccurrencesForPeriod(habitId, periodKey);
    final int selectedOrdinal =
        ordinal ?? _nextOrdinal(existing, habit.targetCount);
    final HabitOccurrenceMutation result =
        status == HabitOccurrenceStatus.completed
        ? await repository.completeOccurrence(
            habitId: habitId,
            periodKey: periodKey,
            ordinal: selectedOrdinal,
            targetCount: habit.targetCount,
            at: timestamp,
          )
        : await repository.skipOccurrence(
            habitId: habitId,
            periodKey: periodKey,
            ordinal: selectedOrdinal,
            targetCount: habit.targetCount,
            at: timestamp,
          );
    if (result == HabitOccurrenceMutation.inserted ||
        result == HabitOccurrenceMutation.idempotent) {
      final HabitOccurrence persisted = (await repository.getOccurrence(
        habitId,
        periodKey,
        selectedOrdinal,
      ))!;
      await ref.read(habitOccurrenceTimelineAdapterProvider).record(persisted);
      await ref.read(habitOccurrenceSyncAdapterProvider).enqueue(persisted);
      await ref
          .read(habitOccurrenceReminderAdapterProvider)
          .reconcile(persisted);
    }
    if (result == HabitOccurrenceMutation.inserted &&
        status == HabitOccurrenceStatus.completed) {
      AppAnalytics.track(
        'habit_completed',
        params: <String, Object?>{
          'habit_id': habitId,
          'period_key': periodKey,
          'ordinal': selectedOrdinal,
        },
      );
    }
    return result;
  }

  int _nextOrdinal(List<HabitOccurrence> existing, int targetCount) {
    final Set<int> used = existing
        .map((HabitOccurrence item) => item.ordinal)
        .toSet();
    for (int ordinal = 1; ordinal <= targetCount.clamp(1, 365); ordinal++) {
      if (!used.contains(ordinal)) return ordinal;
    }
    return targetCount.clamp(1, 365);
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
