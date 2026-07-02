import 'package:fantastic_guacamole/core/utils/math_utils.dart';
import 'package:fantastic_guacamole/core/utils/time_utils.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

/// ChronoSpark Task Behavior Engine
/// Defines how tasks *behave* inside the SI-powered multiverse.
/// Behaviors are NOT CRUD. They are state transitions + reactions.
class TaskBehavior {
  final ITaskRepository repo;

  TaskBehavior(this.repo);

  // ------------------------------------------------------------
  // COMPLETION BEHAVIOR
  // ------------------------------------------------------------

  /// Marks a task complete AND triggers its behavioral consequences.
  Future<TaskEntity?> complete(String id) async {
    final task = await repo.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(isCompleted: true, completedAt: DateTime.now());

    await repo.saveTask(updated);

    return updated;
  }

  /// Marks a task incomplete (undo) AND resets completion metadata.
  Future<TaskEntity?> uncomplete(String id) async {
    final task = await repo.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(isCompleted: false, completedAt: null);

    await repo.saveTask(updated);

    return updated;
  }

  // ------------------------------------------------------------
  // SCHEDULING BEHAVIOR
  // ------------------------------------------------------------

  /// Schedules a task at a specific time.
  Future<TaskEntity?> schedule(String id, DateTime time) async {
    final task = await repo.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(scheduledFor: time);

    await repo.saveTask(updated);

    return updated;
  }

  /// Unschedules a task.
  Future<TaskEntity?> unschedule(String id) async {
    final task = await repo.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(scheduledFor: null);

    await repo.saveTask(updated);

    return updated;
  }

  /// Defers a task by a duration.
  Future<TaskEntity?> defer(String id, Duration duration) async {
    final task = await repo.getTaskById(id);
    final DateTime? scheduledFor = task?.scheduledFor;
    if (task == null || scheduledFor == null) return null;

    final updated = task.copyWith(scheduledFor: scheduledFor.add(duration));

    await repo.saveTask(updated);

    return updated;
  }

  // ------------------------------------------------------------
  // PRIORITY BEHAVIOR
  // ------------------------------------------------------------

  /// Sets task priority.
  Future<TaskEntity?> setPriority(String id, int priority) async {
    final task = await repo.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(priority: priority);

    await repo.saveTask(updated);

    return updated;
  }

  // ------------------------------------------------------------
  // ENERGY MATCH BEHAVIOR (SI Engine)
  // ------------------------------------------------------------

  /// Computes how well a task matches the user's current energy level.
  /// Returns a score from 0.0 → 1.0.
  double energyMatch(TaskEntity task, double currentEnergy) {
    final required = task.energyRequired / 10.0;
    final diff = (currentEnergy - required).abs();

    // Perfect match = 1.0, worst match = 0.0
    return MathUtils.clamp(1.0 - diff, 0.0, 1.0).toDouble();
  }

  // ------------------------------------------------------------
  // URGENCY BEHAVIOR
  // ------------------------------------------------------------

  /// Computes urgency based on:
  /// - due date proximity
  /// - priority
  /// - completion status
  double urgency(TaskEntity task) {
    if (task.isCompleted) return 0.0;

    double score = 0.0;

    // Priority weight
    score += task.priority * 0.15;

    // Due date proximity
    final DateTime? dueDate = task.dueDate;
    if (dueDate != null) {
      final minutesLeft = TimeUtils.minutesBetween(DateTime.now(), dueDate);
      if (minutesLeft <= 0) {
        score += 1.0; // overdue = max urgency
      } else {
        final normalized = MathUtils.clamp(1.0 - (minutesLeft / 1440), 0.0, 1.0).toDouble();
        score += normalized;
      }
    }

    return MathUtils.clamp(score, 0.0, 1.0).toDouble();
  }

  // ------------------------------------------------------------
  // ATTENTION BEHAVIOR
  // ------------------------------------------------------------

  /// Determines if a task needs attention right now.
  bool needsAttention(TaskEntity task) {
    if (task.isCompleted) return false;

    final urgent = urgency(task);
    final DateTime? scheduledFor = task.scheduledFor;
    final scheduledSoon =
        scheduledFor != null && TimeUtils.minutesBetween(DateTime.now(), scheduledFor) <= 30;

    return urgent >= 0.7 || scheduledSoon;
  }

  // ------------------------------------------------------------
  // GOAL LINK BEHAVIOR
  // ------------------------------------------------------------

  /// Assigns a task to a goal.
  Future<TaskEntity?> assignToGoal(String id, String goalId) async {
    final task = await repo.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(goalId: goalId);

    await repo.saveTask(updated);

    return updated;
  }

  // ------------------------------------------------------------
  // CANCEL / RESTORE BEHAVIOR
  // ------------------------------------------------------------

  Future<TaskEntity?> cancel(String id) async {
    final task = await repo.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(isCanceled: true);

    await repo.saveTask(updated);

    return updated;
  }

  Future<TaskEntity?> restore(String id) async {
    final task = await repo.getTaskById(id);
    if (task == null) return null;

    final updated = task.copyWith(isCanceled: false);

    await repo.saveTask(updated);

    return updated;
  }
}
