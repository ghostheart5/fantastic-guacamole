import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/award_xp.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by taskActionsProvider. Gated by TaskPolicy.canComplete; awards XP
/// via AwardXp.
class CompleteTask {
  CompleteTask(this.repository, {this.siRepo, this.progressionRepo});

  final ITaskRepository repository;
  final ISiRepository? siRepo;
  final IProgressionRepository? progressionRepo;

  Future<void> call(String id) async {
    final task = await repository.getTaskById(id);
    if (task == null) throw StateError('Task not found');
    if (!TaskPolicy.canComplete(task)) {
      throw StateError('Task already completed');
    }

    final now = DateTime.now();
    await repository.saveTask(
      task.copyWith(isCompleted: true, completedAt: now, updatedAt: now),
    );

    // If recurring, create the next occurrence
    if (task.recurrenceRule != RecurrenceRule.none) {
      final Duration offset = task.recurrenceRule == RecurrenceRule.daily
          ? const Duration(days: 1)
          : const Duration(days: 7);
      final next = task.copyWith(
        id: '${task.id}_${now.millisecondsSinceEpoch}',
        isCompleted: false,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
        scheduledFor: now.add(offset),
      );
      await repository.saveTask(next);
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
  }
}
