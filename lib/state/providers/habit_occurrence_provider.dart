import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final habitOccurrenceRepositoryProvider = Provider<HabitOccurrenceRepository?>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) return null;
  return HabitOccurrenceRepository(ref.read(sharedPrefsStoreProvider), scope);
});

final habitOccurrencesProvider = FutureProvider<List<HabitOccurrenceEntity>>((
  Ref ref,
) async {
  final HabitOccurrenceRepository? repository = ref.watch(
    habitOccurrenceRepositoryProvider,
  );
  return repository == null
      ? const <HabitOccurrenceEntity>[]
      : repository.load();
});

final habitOccurrenceCoordinatorProvider =
    Provider<HabitOccurrenceCoordinator?>((Ref ref) {
      final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
      final HabitOccurrenceRepository? occurrences = ref.watch(
        habitOccurrenceRepositoryProvider,
      );
      final DecisionOutcomeRepository? outcomes = ref.watch(
        decisionOutcomeRepositoryProvider,
      );
      if (!scope.isWritable || occurrences == null || outcomes == null) {
        return null;
      }
      return HabitOccurrenceCoordinator(
        scope: scope,
        habitRepository: ref.read(domainHabitRepositoryProvider),
        occurrenceRepository: occurrences,
        outcomeRepository: outcomes,
      );
    });
