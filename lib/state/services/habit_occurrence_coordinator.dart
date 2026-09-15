import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';

enum HabitOccurrenceMutation { applied, idempotent, conflict }

class HabitOccurrenceResult {
  const HabitOccurrenceResult({
    required this.mutation,
    required this.occurrence,
    this.learningPending = false,
  });

  final HabitOccurrenceMutation mutation;
  final HabitOccurrenceEntity occurrence;
  final bool learningPending;
}

/// Records Daily Rhythm outcomes without changing whether the rhythm is active.
class HabitOccurrenceCoordinator {
  HabitOccurrenceCoordinator({
    required this.scope,
    required this.habitRepository,
    required this.occurrenceRepository,
    required this.outcomeRepository,
    Future<bool> Function()? learningPaused,
    DateTime Function()? clock,
  }) : _learningPaused = learningPaused ?? _learningEnabled,
       _clock = clock ?? DateTime.now;

  final AccountStorageScope scope;
  final IHabitRepository habitRepository;
  final IHabitOccurrenceRepository occurrenceRepository;
  final IDecisionOutcomeRepository outcomeRepository;
  final Future<bool> Function() _learningPaused;
  final DateTime Function() _clock;
  Future<void> _tail = Future<void>.value();

  Future<HabitOccurrenceResult> complete(
    String habitId, {
    String? operationId,
  }) => _record(
    habitId,
    HabitOccurrenceOutcome.completed,
    operationId: operationId,
  );

  Future<HabitOccurrenceResult> completeAt(String habitId, DateTime period) =>
      _record(habitId, HabitOccurrenceOutcome.completed, recordedFor: period);

  Future<HabitOccurrenceResult> skip(String habitId, {String? operationId}) =>
      _record(
        habitId,
        HabitOccurrenceOutcome.skipped,
        operationId: operationId,
      );

  Future<HabitOccurrenceResult> skipAt(String habitId, DateTime period) =>
      _record(habitId, HabitOccurrenceOutcome.skipped, recordedFor: period);

  /// Corrects the current cadence-slot outcome while retaining an explicit
  /// correction receipt in learning history.
  Future<HabitOccurrenceResult> correct(
    String habitId,
    HabitOccurrenceOutcome outcome,
  ) {
    final Future<HabitOccurrenceResult> operation = _tail.then((_) async {
      if (!scope.isWritable || scope.v2Namespace == null) {
        throw StateError('Daily Rhythm corrections require an account.');
      }
      final habits = await habitRepository.getHabits();
      final habit = habits.where((value) => value.id == habitId).firstOrNull;
      if (habit == null) throw StateError('Daily Rhythm not found.');
      final DateTime now = _clock();
      final String key = occurrenceKeyFor(habit.cadence, now);
      final current = await occurrenceRepository.load();
      final index = current.indexWhere(
        (value) => value.habitId == habitId && value.occurrenceKey == key,
      );
      if (index < 0) {
        throw StateError('No current outcome is available to correct.');
      }
      final previous = current[index];
      if (previous.outcome == outcome) {
        return HabitOccurrenceResult(
          mutation: HabitOccurrenceMutation.idempotent,
          occurrence: previous,
        );
      }
      final corrected = HabitOccurrenceEntity(
        habitId: habitId,
        occurrenceKey: key,
        operationId:
            '${previous.operationId}:corrected:${now.toUtc().microsecondsSinceEpoch}',
        outcome: outcome,
        recordedAt: now.toUtc(),
      );
      final next = List<HabitOccurrenceEntity>.from(current)
        ..[index] = corrected;
      await occurrenceRepository.replaceSnapshot(next);
      bool learningPending = false;
      try {
        if (!await _learningPaused()) {
          await outcomeRepository.record(
            DecisionOutcomeEntity(
              decisionId: 'habit:$habitId:$key',
              kind: DecisionOutcomeKind.corrected,
              surface: 'daily-rhythm',
              recordedAt: now.toUtc(),
              modelVersion: 'domain-occurrence-v1',
              recommendationConfidence: 1,
              subjectId: habitId,
              correction: '${previous.outcome.name} -> ${outcome.name}',
              correctedOutcomeKind: outcome.name,
              recommendationHelped: null,
            ),
          );
        }
      } on Object {
        learningPending = true;
      }
      return HabitOccurrenceResult(
        mutation: HabitOccurrenceMutation.applied,
        occurrence: corrected,
        learningPending: learningPending,
      );
    });
    _tail = operation.then<void>((_) {}).catchError((Object _) {});
    return operation;
  }

  Future<HabitOccurrenceResult> _record(
    String habitId,
    HabitOccurrenceOutcome outcome, {
    String? operationId,
    DateTime? recordedFor,
  }) {
    final Future<HabitOccurrenceResult> operation = _tail.then((_) async {
      if (!scope.isWritable || scope.v2Namespace == null) {
        throw StateError(
          'Daily Rhythm outcomes are unavailable during account transition.',
        );
      }
      final String normalizedId = habitId.trim();
      if (normalizedId.isEmpty) {
        throw ArgumentError.value(habitId, 'habitId', 'Must not be empty.');
      }
      final List<HabitEntity> habits = await habitRepository.getHabits();
      final HabitEntity habit = habits.firstWhere(
        (HabitEntity value) => value.id == normalizedId,
        orElse: () => throw StateError('Daily Rhythm not found.'),
      );
      if (!habit.active) {
        throw StateError('Paused Daily Rhythms cannot record outcomes.');
      }

      final DateTime now = recordedFor ?? _clock();
      final String occurrenceKey = occurrenceKeyFor(habit.cadence, now);
      final String resolvedOperationId = operationId?.trim().isNotEmpty == true
          ? operationId!.trim()
          : 'habit:$normalizedId:$occurrenceKey:${outcome.name}';
      final HabitOccurrenceEntity candidate = HabitOccurrenceEntity(
        habitId: normalizedId,
        occurrenceKey: occurrenceKey,
        operationId: resolvedOperationId,
        outcome: outcome,
        recordedAt: now.toUtc(),
      );
      final List<HabitOccurrenceEntity> current = await occurrenceRepository
          .load();
      HabitOccurrenceEntity? existing;
      for (final HabitOccurrenceEntity value in current) {
        if (value.id == candidate.id) {
          existing = value;
          break;
        }
      }
      if (existing != null) {
        final bool sameOutcome = existing.outcome == outcome;
        bool learningPending = false;
        if (sameOutcome) {
          try {
            await _ensureLearningOutcome(existing);
          } on Object {
            learningPending = true;
          }
        }
        return HabitOccurrenceResult(
          mutation: sameOutcome
              ? HabitOccurrenceMutation.idempotent
              : HabitOccurrenceMutation.conflict,
          occurrence: existing,
          learningPending: learningPending,
        );
      }

      await occurrenceRepository.save(candidate);
      bool learningPending = false;
      try {
        await _ensureLearningOutcome(candidate);
      } on Object {
        // The canonical outcome is already durable. Surface this as pending
        // supporting work instead of falsely reporting that recording failed.
        learningPending = true;
      }
      return HabitOccurrenceResult(
        mutation: HabitOccurrenceMutation.applied,
        occurrence: candidate,
        learningPending: learningPending,
      );
    });
    _tail = operation.then<void>((_) {}).catchError((Object _) {});
    return operation;
  }

  Future<void> _ensureLearningOutcome(HabitOccurrenceEntity occurrence) async {
    if (await _learningPaused()) return;
    final DecisionOutcomeEntity candidate = DecisionOutcomeEntity(
      decisionId: 'habit:${occurrence.habitId}:${occurrence.occurrenceKey}',
      kind: occurrence.outcome == HabitOccurrenceOutcome.completed
          ? DecisionOutcomeKind.completed
          : DecisionOutcomeKind.skipped,
      surface: 'daily-rhythm',
      situation: 'daily rhythm occurrence',
      recordedAt: occurrence.recordedAt.toUtc(),
      modelVersion: 'domain-occurrence-v1',
      recommendationConfidence: 1,
      subjectId: occurrence.habitId,
      detail: occurrence.outcome.name,
      completionResult: occurrence.outcome.name,
      recommendationHelped:
          occurrence.outcome == HabitOccurrenceOutcome.completed,
    );
    final List<DecisionOutcomeEntity> recorded = await outcomeRepository.load();
    if (recorded.any(
      (DecisionOutcomeEntity value) => value.id == candidate.id,
    )) {
      return;
    }
    await outcomeRepository.record(candidate);
  }

  /// Shared cadence identity for recording and displaying the current period.
  static String occurrenceKeyFor(HabitCadence cadence, DateTime timestamp) =>
      RhythmPlanningContext.periodKey(cadence, timestamp);
}

Future<bool> _learningEnabled() async => false;
