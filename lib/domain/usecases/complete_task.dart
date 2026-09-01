import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/policies/completion_side_effect_policy.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/award_xp.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by taskActionsProvider. Gated by TaskPolicy.canComplete; awards XP
/// via AwardXp.
typedef DurableCompleteMutation = Future<Object?> Function(String taskId);

class CompleteTask {
  CompleteTask(
    this.repository, {
    this.siRepo,
    this.progressionRepo,
    this.durableMutation,
  });

  final ITaskRepository repository;
  final ISiRepository? siRepo;
  final IProgressionRepository? progressionRepo;
  final DurableCompleteMutation? durableMutation;

  Future<CompletionSideEffectDecision> call(String id, {DateTime? now}) async {
    CompletionMutationOutcome outcome = CompletionMutationOutcome.applied;
    final DurableCompleteMutation? mutation = durableMutation;
    if (mutation != null) {
      outcome = _durableOutcome(await mutation(id));
      final CompletionSideEffectDecision decision =
          CompletionSideEffectPolicy.decide(outcome);
      if (!decision.shouldRunReward) return decision;
    } else {
      final task = await repository.getTaskById(id);
      if (task == null) throw StateError('Task not found');
      if (!TaskPolicy.canComplete(task)) {
        throw StateError('Task already completed');
      }
      if (task.recurrenceRule != RecurrenceRule.none) {
        throw StateError(
          'Recurring completion requires the durable occurrence authority.',
        );
      }
      final DateTime timestamp = now ?? DateTime.now();
      await repository.saveTask(
        task.copyWith(
          isCompleted: true,
          completedAt: timestamp,
          updatedAt: timestamp,
        ),
      );
    }

    // Award flat XP through the single canonical path so level stays in sync.
    final IProgressionRepository? prog = progressionRepo;
    if (prog != null) {
      await AwardXp(prog).call(ProgressionPolicy.taskXp);
    }

    // Update SI confidence
    final ISiRepository? si = siRepo;
    if (si != null) {
      final current = await si.getCurrentState();
      if (current != null) {
        await si.saveState(current.withConfidenceDelta(0.05));
      }
    }
    return CompletionSideEffectPolicy.decide(outcome);
  }

  CompletionMutationOutcome _durableOutcome(Object? raw) {
    if (raw is CompletionMutationOutcome) return raw;
    if (raw is bool) {
      return raw
          ? CompletionMutationOutcome.applied
          : CompletionMutationOutcome.conflict;
    }
    final String name = raw?.toString().split('.').last ?? '';
    for (final CompletionMutationOutcome outcome
        in CompletionMutationOutcome.values) {
      if (outcome.name == name) return outcome;
    }
    return CompletionMutationOutcome.blocked;
  }
}
