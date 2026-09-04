import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/ports/i_adaptive_plan_generator.dart';
import 'package:fantastic_guacamole/domain/planning/adaptive_plan_policy.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';

export 'package:fantastic_guacamole/domain/planning/adaptive_plan_policy.dart';

/// Compatibility planning helper. Production decision surfaces consume the
/// canonical `DecisionEngine` plan instead of an alternate planning screen.
///
/// The persisted path remains a schedule-storage mechanism, not a second
/// recommendation authority.
class CalendarService implements IAdaptivePlanGenerator {
  final Map<String, CalendarEntryEntity> _entries =
      <String, CalendarEntryEntity>{};
  final Map<String, List<TimeBlock>> _timeBlocksByDay =
      <String, List<TimeBlock>>{};
  final Map<String, List<Task>> _tasksByDay = <String, List<Task>>{};

  /// Generate an adaptive day plan using a simple energy-aware ranking.
  @override
  List<TimeBlock> generateAdaptivePlan({
    required List<PlannerInput> inputs,
    required double energy,
    DateTime? startTime,
    AdaptivePlanPolicy policy = const AdaptivePlanPolicy(),
  }) {
    final double normalizedEnergy = energy.clamp(0.0, 1.0);
    final DateTime now = startTime ?? DateTime.now();

    final List<PlannerInput> ranked = List<PlannerInput>.from(inputs)
      ..sort((PlannerInput a, PlannerInput b) {
        final double aScore = _adaptiveTaskScore(
          a,
          normalizedEnergy,
          now,
          policy,
        );
        final double bScore = _adaptiveTaskScore(
          b,
          normalizedEnergy,
          now,
          policy,
        );
        return bScore.compareTo(aScore);
      });

    final List<TimeBlock> blocks = <TimeBlock>[];
    final Map<String, DateTime> cursorsByDay = <String, DateTime>{};
    final Set<String> plannedTaskDayKeys = <String>{};

    for (final PlannerInput task in ranked) {
      final List<DateTime> occurrences = _planningOccurrences(task, now);
      for (final DateTime occurrence in occurrences) {
        final DateTime dayStart = _startForPlanningDay(occurrence, now);
        final String dayKey = _keyFor(dayStart);
        final String taskDayKey = '${task.id}@$dayKey';
        if (plannedTaskDayKeys.contains(taskDayKey)) {
          continue;
        }
        final DateTime cursor = cursorsByDay[dayKey] ?? dayStart;
        final Duration duration = _estimateAdaptiveDuration(
          task,
          normalizedEnergy,
          adaptToEnergy: policy.adaptDurationToEnergy,
        );
        final DateTime end = cursor.add(duration);

        blocks.add(
          TimeBlock(
            id: '${task.id}-${occurrence.millisecondsSinceEpoch}-${cursor.millisecondsSinceEpoch}',
            taskId: task.id,
            title: task.title,
            start: cursor,
            end: end,
          ),
        );

        plannedTaskDayKeys.add(taskDayKey);
        cursorsByDay[dayKey] = end.add(
          policy.fixedBreakMinutes == null
              ? _adaptiveBreak(normalizedEnergy)
              : Duration(minutes: policy.fixedBreakMinutes!),
        );
      }
    }

    return blocks;
  }

  /// Generate a simple day plan from tasks.
  List<TimeBlock> generateDayPlan({
    required List<Task> tasks,
    DateTime? startTime,
  }) {
    final DateTime now = startTime ?? DateTime.now();

    // Sort tasks by priority (high first) while avoiding in-place mutation.
    final List<Task> sortedTasks = List<Task>.from(tasks)
      ..sort((Task a, Task b) => b.priority.compareTo(a.priority));

    final List<TimeBlock> blocks = <TimeBlock>[];
    DateTime cursor = now;

    for (final Task task in sortedTasks) {
      final Duration duration = _estimateDuration(task);
      final DateTime end = cursor.add(duration);

      blocks.add(
        TimeBlock(
          id: '${task.id}-${cursor.millisecondsSinceEpoch}',
          taskId: task.id,
          title: task.title,
          start: cursor,
          end: end,
        ),
      );

      // Move pointer forward with a short break between tasks.
      cursor = end.add(const Duration(minutes: 10));
    }

    return blocks;
  }

  CalendarEntryEntity getDay(DateTime date) {
    final String key = _keyFor(date);
    return _entries[key] ?? _defaultEntry(date, key);
  }

  void addTimeBlock(DateTime date, TimeBlock block) {
    if (!block.start.isBefore(block.end)) {
      throw ArgumentError('TimeBlock start must be before end.');
    }

    final String key = _keyFor(date);
    final List<TimeBlock> blocks = _timeBlocksByDay.putIfAbsent(
      key,
      () => <TimeBlock>[],
    );
    final bool hasConflict = blocks.any(
      (TimeBlock existing) =>
          block.start.isBefore(existing.end) &&
          block.end.isAfter(existing.start),
    );

    if (hasConflict) {
      throw StateError('TimeBlock overlaps with an existing block.');
    }

    blocks.add(block);
    blocks.sort((TimeBlock a, TimeBlock b) => a.start.compareTo(b.start));

    _entries[key] = _summaryEntryForDay(date, key);
  }

  void addTask(DateTime date, Task task) {
    final String key = _keyFor(date);
    final List<Task> tasks = _tasksByDay.putIfAbsent(key, () => <Task>[]);
    tasks.add(task);

    _entries[key] = _summaryEntryForDay(date, key);
  }

  void completeTask(DateTime date, String taskId) {
    final String key = _keyFor(date);
    final List<Task> tasks = _tasksByDay.putIfAbsent(key, () => <Task>[]);
    final int index = tasks.indexWhere((Task task) => task.id == taskId);
    if (index == -1) {
      return;
    }

    final Task original = tasks[index];
    tasks[index] = Task(
      id: original.id,
      title: original.title,
      priority: original.priority,
      difficulty: original.difficulty,
      energyRequired: original.energyRequired,
    );

    _entries[key] = _summaryEntryForDay(date, key);
  }

  String _keyFor(DateTime date) {
    final DateTime normalized = _normalizedDate(date);
    final String month = normalized.month.toString().padLeft(2, '0');
    final String day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  DateTime _normalizedDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  CalendarEntryEntity _defaultEntry(DateTime date, String key) {
    final DateTime start = DateTime(date.year, date.month, date.day);
    return CalendarEntryEntity(
      id: key,
      title: 'Day Plan',
      start: start,
      end: start.add(const Duration(hours: 24)),
    );
  }

  CalendarEntryEntity _summaryEntryForDay(DateTime date, String key) {
    final List<TimeBlock> blocks = _timeBlocksByDay[key] ?? <TimeBlock>[];
    final DateTime start = DateTime(date.year, date.month, date.day);
    return CalendarEntryEntity(
      id: key,
      title: blocks.isEmpty
          ? 'Day Plan'
          : '${blocks.length} block${blocks.length == 1 ? '' : 's'}',
      start: start,
      end: start.add(const Duration(hours: 24)),
    );
  }

  /// Basic duration estimation.
  Duration _estimateDuration(Task task) {
    switch (task.difficulty) {
      case 1:
        return const Duration(minutes: 15);
      case 2:
        return const Duration(minutes: 25);
      case 3:
        return const Duration(minutes: 45);
      case 4:
        return const Duration(minutes: 60);
      case 5:
        return const Duration(minutes: 90);
      default:
        return const Duration(minutes: 30);
    }
  }

  double _adaptiveTaskScore(
    PlannerInput task,
    double energy,
    DateTime now,
    AdaptivePlanPolicy policy,
  ) {
    final double priorityWeight = task.priority * 10.0 * policy.priorityWeight;
    final double normalizedRequirement = task.energyRequired / 5.0;
    final double effortFit =
        (1 - (normalizedRequirement - energy).abs()).clamp(0.0, 1.0) *
        30 *
        policy.energyWeight;
    final Duration duration = task.estimateOrDefault;
    final double quickWinFit = duration.inMinutes <= 15
        ? 1
        : duration.inMinutes <= 30
        ? .65
        : duration.inMinutes <= 60
        ? .25
        : 0;
    final double goalContribution = (task.goalId?.trim().isNotEmpty ?? false)
        ? policy.goalBonus
        : 0;
    final DateTime? due = task.dueDate;
    final double deadlineContribution = due == null
        ? 0
        : due.isBefore(now)
        ? 18 * policy.deadlineWeight
        : due.difference(now) <= const Duration(hours: 24)
        ? 14 * policy.deadlineWeight
        : due.difference(now) <= const Duration(days: 3)
        ? 7 * policy.deadlineWeight
        : 0;
    return priorityWeight +
        effortFit +
        goalContribution +
        (quickWinFit * policy.quickWinBonus) +
        deadlineContribution;
  }

  DateTime _startForPlanningDay(DateTime scheduled, DateTime now) {
    final bool isToday =
        scheduled.year == now.year &&
        scheduled.month == now.month &&
        scheduled.day == now.day;
    if (isToday) return now;
    if (scheduled.hour != 0 || scheduled.minute != 0) return scheduled;
    return DateTime(scheduled.year, scheduled.month, scheduled.day, 9);
  }

  Duration _estimateAdaptiveDuration(
    PlannerInput task,
    double energy, {
    required bool adaptToEnergy,
  }) {
    final Duration base =
        task.estimatedDuration ??
        switch (task.difficulty) {
          1 => const Duration(minutes: 15),
          2 => const Duration(minutes: 25),
          3 => const Duration(minutes: 45),
          4 => const Duration(minutes: 60),
          5 => const Duration(minutes: 90),
          _ => const Duration(minutes: 30),
        };
    if (!adaptToEnergy) return base;
    if (energy >= 0.75) {
      return Duration(minutes: (base.inMinutes * 0.9).round());
    }
    if (energy <= 0.35) {
      return Duration(minutes: (base.inMinutes * 1.2).round());
    }
    return base;
  }

  Duration _adaptiveBreak(double energy) {
    if (energy >= 0.75) {
      return const Duration(minutes: 8);
    }
    if (energy <= 0.35) {
      return const Duration(minutes: 15);
    }
    return const Duration(minutes: 10);
  }

  List<DateTime> _planningOccurrences(PlannerInput task, DateTime now) {
    final DateTime scheduled = task.scheduledFor ?? now;
    switch (task.recurrenceRule) {
      case RecurrenceRule.daily:
        final DateTime today = DateTime(now.year, now.month, now.day);
        final DateTime scheduledDate = DateTime(
          scheduled.year,
          scheduled.month,
          scheduled.day,
        );
        final DateTime startDate = scheduledDate.isAfter(today)
            ? scheduledDate
            : today;
        final int hour = (scheduled.hour == 0 && scheduled.minute == 0)
            ? now.hour
            : scheduled.hour;
        final int minute = (scheduled.hour == 0 && scheduled.minute == 0)
            ? now.minute
            : scheduled.minute;
        return List<DateTime>.generate(
          7,
          (int index) => DateTime(
            startDate.year,
            startDate.month,
            startDate.day + index,
            hour,
            minute,
          ),
        );
      case RecurrenceRule.weekly:
        final DateTime today = DateTime(now.year, now.month, now.day);
        final DateTime scheduledDate = DateTime(
          scheduled.year,
          scheduled.month,
          scheduled.day,
        );
        final DateTime firstEligibleDate = scheduledDate.isAfter(today)
            ? scheduledDate
            : today;
        DateTime candidate = DateTime(
          firstEligibleDate.year,
          firstEligibleDate.month,
          firstEligibleDate.day,
          scheduled.hour,
          scheduled.minute,
        );
        final int targetWeekday = scheduled.weekday;
        while (candidate.weekday != targetWeekday) {
          candidate = candidate.add(const Duration(days: 1));
        }
        if (candidate.isBefore(now)) {
          candidate = candidate.add(const Duration(days: 7));
        }
        return <DateTime>[candidate];
      case RecurrenceRule.none:
        return <DateTime>[scheduled];
    }
  }
}
