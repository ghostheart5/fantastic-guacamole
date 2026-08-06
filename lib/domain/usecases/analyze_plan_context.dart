import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';

/// Read model describing the shape of a generated plan.
class PlanContext {
  const PlanContext({
    required this.blockCount,
    required this.plannedMinutes,
    required this.plannedDayCount,
    required this.unplannedTaskCount,
    required this.energyBand,
    required this.isOverloaded,
    this.firstBlockStart,
    this.lastBlockEnd,
  });

  final int blockCount;
  final int plannedMinutes;
  final int plannedDayCount;

  /// Tasks that produced no block in the plan.
  final int unplannedTaskCount;

  /// `low` / `steady` / `high`, using the same thresholds the planner itself
  /// applies when it stretches or compresses durations.
  final String energyBand;

  /// True when a single planned day exceeds [overloadedMinutesPerDay].
  final bool isOverloaded;

  final DateTime? firstBlockStart;
  final DateTime? lastBlockEnd;

  bool get isEmpty => blockCount == 0;
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner
///
/// Summarises a generated plan so callers can reason about load without
/// re-deriving block maths. Pure: it reads an existing plan rather than
/// producing one, so it cannot drift from [GenerateAdaptivePlan].
class AnalyzePlanContext {
  const AnalyzePlanContext();

  /// A planned day past this many minutes counts as overloaded.
  static const int overloadedMinutesPerDay = 480;

  /// Matches `CalendarService` duration banding.
  static const double lowEnergyThreshold = 0.35;
  static const double highEnergyThreshold = 0.75;

  PlanContext call({
    required List<TimeBlock> blocks,
    required List<Task> tasks,
    required double energy,
  }) {
    final double normalizedEnergy = energy.clamp(0.0, 1.0);
    final String band = normalizedEnergy >= highEnergyThreshold
        ? 'high'
        : normalizedEnergy <= lowEnergyThreshold
        ? 'low'
        : 'steady';

    if (blocks.isEmpty) {
      return PlanContext(
        blockCount: 0,
        plannedMinutes: 0,
        plannedDayCount: 0,
        unplannedTaskCount: tasks.length,
        energyBand: band,
        isOverloaded: false,
      );
    }

    final Map<String, int> minutesByDay = <String, int>{};
    final Set<String> plannedTaskIds = <String>{};
    int plannedMinutes = 0;
    DateTime firstStart = blocks.first.start;
    DateTime lastEnd = blocks.first.end;

    for (final TimeBlock block in blocks) {
      final int minutes = block.end.difference(block.start).inMinutes;
      plannedMinutes += minutes;
      plannedTaskIds.add(block.taskId);

      final String dayKey =
          '${block.start.year}-${block.start.month}-${block.start.day}';
      minutesByDay[dayKey] = (minutesByDay[dayKey] ?? 0) + minutes;

      if (block.start.isBefore(firstStart)) {
        firstStart = block.start;
      }
      if (block.end.isAfter(lastEnd)) {
        lastEnd = block.end;
      }
    }

    final bool overloaded = minutesByDay.values.any(
      (int minutes) => minutes > overloadedMinutesPerDay,
    );
    final int unplanned = tasks
        .where((Task task) => !plannedTaskIds.contains(task.id))
        .length;

    return PlanContext(
      blockCount: blocks.length,
      plannedMinutes: plannedMinutes,
      plannedDayCount: minutesByDay.length,
      unplannedTaskCount: unplanned,
      energyBand: band,
      isOverloaded: overloaded,
      firstBlockStart: firstStart,
      lastBlockEnd: lastEnd,
    );
  }
}
