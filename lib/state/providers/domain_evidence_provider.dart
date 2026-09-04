import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/domain_evidence_entry.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/services/domain_evidence_index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final domainEvidenceProvider = FutureProvider<DomainEvidenceSnapshot>((
  Ref ref,
) async {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) {
    return const DomainEvidenceSnapshot(
      entries: <DomainEvidenceEntry>[],
      unavailableSources: <DomainEvidenceSource>{
        DomainEvidenceSource.tasks,
        DomainEvidenceSource.goals,
        DomainEvidenceSource.dailyRhythms,
        DomainEvidenceSource.notes,
        DomainEvidenceSource.taskOccurrences,
        DomainEvidenceSource.dailyRhythmOccurrences,
        DomainEvidenceSource.outcomes,
      },
    );
  }

  final Set<DomainEvidenceSource> unavailable = <DomainEvidenceSource>{};
  final List<TaskEntity> tasks = await _readOrEmpty(
    () => ref.read(domainTaskRepositoryProvider).getAllTasks(),
    DomainEvidenceSource.tasks,
    unavailable,
  );
  final List<GoalEntity> goals = await _readOrEmpty(
    () async => ref.read(domainGoalRepositoryProvider).getGoals(),
    DomainEvidenceSource.goals,
    unavailable,
  );
  final List<HabitEntity> habits = await _readOrEmpty(
    () => ref.read(domainHabitRepositoryProvider).getHabits(),
    DomainEvidenceSource.dailyRhythms,
    unavailable,
  );
  final List<NoteEntity> notes = await _readOrEmpty(
    () => ref.read(domainNoteRepositoryProvider).getNotes(),
    DomainEvidenceSource.notes,
    unavailable,
  );
  final List<TaskOccurrence> taskOccurrences = await _readOrEmpty(
    () => ref.read(taskOccurrenceRepositoryProvider).listOccurrences(),
    DomainEvidenceSource.taskOccurrences,
    unavailable,
  );
  final List<HabitOccurrenceEntity> habitOccurrences = await _readOrEmpty(
    () async {
      final repository = ref.read(habitOccurrenceRepositoryProvider);
      return repository == null
          ? const <HabitOccurrenceEntity>[]
          : repository.load();
    },
    DomainEvidenceSource.dailyRhythmOccurrences,
    unavailable,
  );
  final List<DecisionOutcomeEntity> outcomes = await _readOrEmpty(
    () async {
      final repository = ref.read(decisionOutcomeRepositoryProvider);
      return repository == null
          ? const <DecisionOutcomeEntity>[]
          : repository.load();
    },
    DomainEvidenceSource.outcomes,
    unavailable,
  );

  return DomainEvidenceSnapshot(
    entries: DomainEvidenceIndex.build(
      tasks: tasks,
      goals: goals,
      habits: habits,
      notes: notes,
      taskOccurrences: taskOccurrences,
      habitOccurrences: habitOccurrences,
      outcomes: outcomes,
    ),
    unavailableSources: Set<DomainEvidenceSource>.unmodifiable(unavailable),
  );
});

Future<List<T>> _readOrEmpty<T>(
  Future<List<T>> Function() reader,
  DomainEvidenceSource source,
  Set<DomainEvidenceSource> unavailable,
) async {
  try {
    return await reader();
  } on Object {
    unavailable.add(source);
    return <T>[];
  }
}
