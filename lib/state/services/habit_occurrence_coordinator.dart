import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';

enum HabitOccurrenceMutation { applied, idempotent, conflict }

class HabitOccurrenceResult {
  const HabitOccurrenceResult({
    required this.mutation,
    required this.occurrence,
  });

  final HabitOccurrenceMutation mutation;
  final HabitOccurrenceEntity occurrence;
}

/// Records Daily Rhythm outcomes without changing whether the rhythm is active.
class HabitOccurrenceCoordinator {
  HabitOccurrenceCoordinator({
    required this.scope,
    required this.habitRepository,
    required this.occurrenceRepository,
    required this.outcomeRepository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AccountStorageScope scope;
  final IHabitRepository habitRepository;
  final IHabitOccurrenceRepository occurrenceRepository;
  final IDecisionOutcomeRepository outcomeRepository;
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

  Future<HabitOccurrenceResult> skip(String habitId, {String? operationId}) =>
      _record(
        habitId,
        HabitOccurrenceOutcome.skipped,
        operationId: operationId,
      );

  Future<HabitOccurrenceResult> _record(
    String habitId,
    HabitOccurrenceOutcome outcome, {
    String? operationId,
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

      final DateTime now = _clock();
      final String occurrenceKey = _occurrenceKey(habit.cadence, now);
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
        return HabitOccurrenceResult(
          mutation: existing.outcome == outcome
              ? HabitOccurrenceMutation.idempotent
              : HabitOccurrenceMutation.conflict,
          occurrence: existing,
        );
      }

      await occurrenceRepository.save(candidate);
      await outcomeRepository.record(
        DecisionOutcomeEntity(
          decisionId: 'habit:$normalizedId:$occurrenceKey',
          kind: outcome == HabitOccurrenceOutcome.completed
              ? DecisionOutcomeKind.completed
              : DecisionOutcomeKind.skipped,
          surface: 'daily-rhythm',
          recordedAt: now.toUtc(),
          modelVersion: 'domain-occurrence-v1',
          recommendationConfidence: 1,
          subjectId: normalizedId,
          detail: outcome.name,
        ),
      );
      return HabitOccurrenceResult(
        mutation: HabitOccurrenceMutation.applied,
        occurrence: candidate,
      );
    });
    _tail = operation.then<void>((_) {}).catchError((Object _) {});
    return operation;
  }

  static String _occurrenceKey(HabitCadence cadence, DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    final DateTime slot = switch (cadence) {
      HabitCadence.daily => DateTime(local.year, local.month, local.day),
      HabitCadence.weekly => DateTime(
        local.year,
        local.month,
        local.day,
      ).subtract(Duration(days: local.weekday - DateTime.monday)),
      HabitCadence.monthly => DateTime(local.year, local.month),
    };
    final String month = slot.month.toString().padLeft(2, '0');
    if (cadence == HabitCadence.monthly) return '${slot.year}-$month';
    final String day = slot.day.toString().padLeft(2, '0');
    return '${slot.year}-$month-$day';
  }
}
