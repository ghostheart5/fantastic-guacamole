import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

class TaskFilter {
  const TaskFilter._();

  /// Active tasks only - not completed, skipped, or canceled.
  static List<TaskEntity> incomplete(List<TaskEntity> tasks, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    return tasks
        .where((TaskEntity task) => task.isActionableAt(reference))
        .toList(growable: false);
  }

  /// Tasks whose due date has passed.
  static List<TaskEntity> overdue(List<TaskEntity> tasks, {DateTime? now}) {
    final DateTime ref = now ?? DateTime.now();
    return tasks.where((t) {
      final DateTime? dueDate = t.dueDate;
      return t.isActionableAt(ref) && dueDate != null && dueDate.isBefore(ref);
    }).toList();
  }

  /// Tasks due within [within] from now.
  static List<TaskEntity> dueSoon(
    List<TaskEntity> tasks, {
    Duration within = const Duration(hours: 24),
    DateTime? now,
  }) {
    final DateTime ref = now ?? DateTime.now();
    final DateTime cutoff = ref.add(within);
    return tasks.where((t) {
      final DateTime? dueDate = t.dueDate;
      return t.isActionableAt(ref) &&
          dueDate != null &&
          !dueDate.isBefore(ref) &&
          dueDate.isBefore(cutoff);
    }).toList();
  }

  /// Tasks whose energy requirement fits [userEnergy] (0.0–1.0) within tolerance.
  static List<TaskEntity> forEnergy(
    List<TaskEntity> tasks,
    double userEnergy, {
    double tolerance = 0.3,
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    return tasks
        .where(
          (TaskEntity task) =>
              task.isActionableAt(reference) &&
              ((task.energyRequired / 5.0) - userEnergy).abs() <= tolerance,
        )
        .toList(growable: false);
  }

  /// Tasks with energyRequired / 5.0 <= [maxEnergy].
  static List<TaskEntity> byMaxEnergy(
    List<TaskEntity> tasks,
    double maxEnergy, {
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    return tasks
        .where(
          (TaskEntity task) =>
              task.isActionableAt(reference) &&
              task.energyRequired / 5.0 <= maxEnergy,
        )
        .toList(growable: false);
  }

  /// Tasks with difficulty in [min]..[max] (inclusive, 1–5 scale).
  static List<TaskEntity> byDifficultyRange(
    List<TaskEntity> tasks,
    int min,
    int max, {
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    return tasks
        .where(
          (TaskEntity task) =>
              task.isActionableAt(reference) &&
              task.difficulty >= min &&
              task.difficulty <= max,
        )
        .toList(growable: false);
  }

  /// Tasks scheduled on a specific calendar date.
  static List<TaskEntity> scheduled(List<TaskEntity> tasks, DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final DateTime endOfDay = day
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));
    return tasks
        .where((t) {
          final DateTime? d = t.scheduledFor;
          if (d == null) return false;
          return t.isActionableAt(endOfDay) &&
              DateTime(d.year, d.month, d.day) == day;
        })
        .toList(growable: false);
  }

  /// Tasks belonging to a specific goal.
  static List<TaskEntity> forGoal(
    List<TaskEntity> tasks,
    String goalId, {
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    return tasks
        .where(
          (TaskEntity task) =>
              task.isActionableAt(reference) && task.goalId == goalId,
        )
        .toList(growable: false);
  }

  /// SI-driven filter: when primaryInstinct is 'safety_first', returns only
  /// easy tasks (difficulty <= 2). Otherwise returns all incomplete tasks.
  static List<TaskEntity> bySiState(
    List<TaskEntity> tasks,
    SiStateEntity siState,
  ) {
    final List<TaskEntity> active = incomplete(tasks);
    if (siState.primaryInstinct == 'safety_first') {
      final List<TaskEntity> easy = active
          .where((t) => t.difficulty <= 2)
          .toList();
      return easy.isNotEmpty ? easy : active;
    }
    return active;
  }
}
