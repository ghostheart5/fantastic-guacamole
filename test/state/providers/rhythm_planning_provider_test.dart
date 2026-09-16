import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/rhythm_planning_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cold planning reads canonical rhythms without starting UI reminder work',
    () async {
      final repository = _Habits();
      final container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('owner'),
          ),
          planningPeriodClockProvider.overrideWithValue(DateTime(2026, 9, 8)),
          domainHabitRepositoryProvider.overrideWithValue(repository),
          habitOccurrencesProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(rhythmPlanningProvider.future);
      expect(result.single.habit.id, 'walk');
      expect(result.single.needsAttention, isTrue);
      expect(container.exists(habitsProvider), isFalse);
      expect(repository.writes, 0);
    },
  );
}

class _Habits implements IHabitRepository {
  int writes = 0;
  @override
  Future<List<HabitEntity>> getHabits() async => [
    HabitEntity(
      id: 'walk',
      title: 'Morning walk',
      createdAt: DateTime(2026, 9, 8),
    ),
  ];
  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    writes++;
  }
}
