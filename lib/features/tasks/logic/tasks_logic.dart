import 'package:fantastic_guacamole/features/tasks/models/tasks_models.dart';

class TasksLogic {
  const TasksLogic();

  List<TaskModel> filterByStatus(List<TaskModel> tasks, TaskStatus status) {
    return tasks.where((TaskModel t) => t.status == status).toList();
  }

  List<TaskModel> filterPending(List<TaskModel> tasks) {
    return tasks.where((TaskModel t) {
      return t.status == TaskStatus.pending || t.status == TaskStatus.inProgress;
    }).toList();
  }

  List<TaskModel> filterForDate(List<TaskModel> tasks, DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    return tasks.where((TaskModel t) {
      final DateTime? scheduledFor = t.scheduledFor;
      if (scheduledFor == null) {
        return false;
      }
      final DateTime scheduled = DateTime(scheduledFor.year, scheduledFor.month, scheduledFor.day);
      return scheduled == day;
    }).toList();
  }

  List<TaskModel> filterOverdue(List<TaskModel> tasks) {
    final DateTime now = DateTime.now();
    return tasks.where((TaskModel t) {
      final DateTime? scheduledFor = t.scheduledFor;
      if (scheduledFor == null) {
        return false;
      }
      return scheduledFor.isBefore(now) &&
          t.status != TaskStatus.completed &&
          t.status != TaskStatus.skipped;
    }).toList();
  }

  List<TaskModel> sortBySchedule(List<TaskModel> tasks) {
    final List<TaskModel> copy = List<TaskModel>.from(tasks);
    copy.sort((TaskModel a, TaskModel b) {
      final DateTime? aScheduled = a.scheduledFor;
      final DateTime? bScheduled = b.scheduledFor;
      if (aScheduled == null && bScheduled == null) {
        return 0;
      }
      if (aScheduled == null) {
        return 1;
      }
      if (bScheduled == null) {
        return -1;
      }
      return aScheduled.compareTo(bScheduled);
    });
    return copy;
  }

  List<TaskModel> sortByReliability(List<TaskModel> tasks) {
    final List<TaskModel> copy = List<TaskModel>.from(tasks);
    copy.sort((TaskModel a, TaskModel b) {
      final double scoreA = _reliabilityScore(a);
      final double scoreB = _reliabilityScore(b);
      return scoreB.compareTo(scoreA);
    });
    return copy;
  }

  List<TaskModel> recommend(List<TaskModel> tasks, {int limit = 3}) {
    final List<TaskModel> pending = filterPending(tasks);
    final List<TaskModel> overdue = filterOverdue(pending);

    final List<TaskModel> prioritised = <TaskModel>[
      ...overdue,
      ...sortBySchedule(pending.where((TaskModel t) => !overdue.contains(t)).toList()),
    ];

    return prioritised.take(limit).toList();
  }

  double _reliabilityScore(TaskModel task) {
    final int total = task.completionCount + task.skipCount + task.delayCount;
    if (total == 0) {
      return 0.5;
    }
    return task.completionCount / total;
  }
}
