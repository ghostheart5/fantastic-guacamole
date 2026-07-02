import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

class TaskFilter {
  const TaskFilter._();

  /// Active tasks only — not completed and not canceled.
  static List<TaskEntity> incomplete(List<TaskEntity> tasks) =>
      tasks.where((t) => !t.isCompleted && !t.isCanceled).toList();

  /// Tasks whose due date has passed.
  static List<TaskEntity> overdue(List<TaskEntity> tasks, {DateTime? now}) {
    final DateTime ref = now ?? DateTime.now();
    return tasks.where((t) {
      final DateTime? dueDate = t.dueDate;
      return !t.isCompleted && dueDate != null && dueDate.isBefore(ref);
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
      return !t.isCompleted &&
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
  }) => tasks.where((t) => ((t.energyRequired / 5.0) - userEnergy).abs() <= tolerance).toList();

  /// Tasks with energyRequired / 5.0 <= [maxEnergy].
  static List<TaskEntity> byMaxEnergy(List<TaskEntity> tasks, double maxEnergy) =>
      tasks.where((t) => t.energyRequired / 5.0 <= maxEnergy).toList();

  /// Tasks with difficulty in [min]..[max] (inclusive, 1–5 scale).
  static List<TaskEntity> byDifficultyRange(List<TaskEntity> tasks, int min, int max) =>
      tasks.where((t) => t.difficulty >= min && t.difficulty <= max).toList();

  /// Tasks scheduled on a specific calendar date.
  static List<TaskEntity> scheduled(List<TaskEntity> tasks, DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    return tasks.where((t) {
      final DateTime? d = t.scheduledFor;
      if (d == null) return false;
      return DateTime(d.year, d.month, d.day) == day;
    }).toList();
  }

  /// Tasks belonging to a specific goal.
  static List<TaskEntity> forGoal(List<TaskEntity> tasks, String goalId) =>
      tasks.where((t) => t.goalId == goalId).toList();
}
