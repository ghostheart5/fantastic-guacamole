import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';

enum PlanIssueType {
  dependencyBlocked,
  overdue,
  capacityExceeded,
  noWorkWindow,
  conflict,
  invalidInput,
}

class PlanIssue {
  const PlanIssue({
    required this.type,
    required this.taskId,
    required this.message,
  });

  final PlanIssueType type;
  final String taskId;
  final String message;
}

class PlanningProblem {
  PlanningProblem({
    List<PlannerInput>? inputs,
    List<TaskEntity>? tasks,
    required this.workWindows,
    required this.existingBlocks,
    required this.energy,
    required this.now,
    this.windowOrigin = PredictiveEvidenceOrigin.observed,
    this.blockOrigin = PredictiveEvidenceOrigin.observed,
    this.assumptions = const <String>[],
  }) : inputs =
           inputs ??
           PlannerInputAdapter.fromTaskEntities(tasks ?? const <TaskEntity>[]);

  final List<PlannerInput> inputs;
  final List<WorkWindowEntity> workWindows;
  final List<TimeBlock> existingBlocks;
  final double energy;
  final DateTime now;
  final PredictiveEvidenceOrigin windowOrigin;
  final PredictiveEvidenceOrigin blockOrigin;
  final List<String> assumptions;
}

class FeasiblePlan {
  const FeasiblePlan({
    required this.blocks,
    required this.unscheduledTaskIds,
    required this.issues,
    required this.capacity,
  });

  final List<TimeBlock> blocks;
  final List<String> unscheduledTaskIds;
  final List<PlanIssue> issues;
  final PlanningCapacityAssessment capacity;

  bool get isFeasible => unscheduledTaskIds.isEmpty;
}

/// Deterministic, availability-bound scheduling. It never creates blocks
/// outside a work window or silently hides work that cannot fit.
class FeasiblePlanner {
  const FeasiblePlanner();

  FeasiblePlan plan(PlanningProblem problem) {
    final List<PlanIssue> issues = <PlanIssue>[];
    final List<PlannerInput> active = <PlannerInput>[];
    for (final PlannerInput task in problem.inputs) {
      if (task.isCompleted || task.isCanceled) continue;
      try {
        task.validate();
        active.add(task);
      } on StateError catch (error) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.invalidInput,
            taskId: task.id,
            message: 'Cannot plan ${task.title}: ${error.message}',
          ),
        );
      }
    }
    final Map<String, PlannerInput> byId = <String, PlannerInput>{
      for (final PlannerInput task in active) task.id: task,
    };
    final List<PlannerInput> ordered = List<PlannerInput>.from(active)
      ..sort((PlannerInput a, PlannerInput b) => _compare(a, b, problem));
    final List<TimeBlock> blocks = <TimeBlock>[];
    for (final TimeBlock block in problem.existingBlocks) {
      try {
        block.validate();
        blocks.add(block);
      } on StateError catch (error) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.invalidInput,
            taskId: block.taskId,
            message: 'Ignoring an invalid existing block: ${error.message}',
          ),
        );
      }
    }
    blocks.sort((TimeBlock a, TimeBlock b) => a.start.compareTo(b.start));
    final List<String> unscheduled = <String>[];
    final Set<String> alreadyScheduledTaskIds = blocks
        .where((TimeBlock block) => !block.completed)
        .map((TimeBlock block) => block.taskId)
        .toSet();

    for (final PlannerInput task in ordered) {
      if (alreadyScheduledTaskIds.contains(task.id)) {
        continue;
      }
      if (_hasIncompletePrerequisite(task, byId)) {
        unscheduled.add(task.id);
        issues.add(
          PlanIssue(
            type: PlanIssueType.dependencyBlocked,
            taskId: task.id,
            message: '${task.title} is waiting on an incomplete prerequisite.',
          ),
        );
        continue;
      }
      if (task.dueDate != null && task.dueDate!.isBefore(problem.now)) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.overdue,
            taskId: task.id,
            message:
                '${task.title} is overdue and needs an explicit recovery decision.',
          ),
        );
      }

      final _Placement? placement = _findPlacement(
        task: task,
        problem: problem,
        occupied: blocks,
      );
      if (placement == null) {
        unscheduled.add(task.id);
        issues.add(
          PlanIssue(
            type: problem.workWindows.isEmpty
                ? PlanIssueType.noWorkWindow
                : PlanIssueType.capacityExceeded,
            taskId: task.id,
            message: problem.workWindows.isEmpty
                ? 'No work window is available for ${task.title}.'
                : '${task.title} does not fit into the available capacity.',
          ),
        );
        continue;
      }

      blocks.add(
        TimeBlock(
          id: 'plan-${task.id}-${placement.start.microsecondsSinceEpoch}',
          taskId: task.id,
          title: task.title,
          start: placement.start,
          end: placement.end,
        ),
      );
      blocks.sort((TimeBlock a, TimeBlock b) => a.start.compareTo(b.start));
    }

    final Set<String> unscheduledIds = unscheduled.toSet();
    final PlanningCapacityAssessment capacity =
        PlanningCapacityAssessment.calculate(
          windows: problem.workWindows,
          existingBlocks: problem.existingBlocks,
          requiredDurations: active
              .where(
                (PlannerInput task) =>
                    !alreadyScheduledTaskIds.contains(task.id),
              )
              .map((PlannerInput task) => task.estimateOrDefault),
          unscheduledDurations: active
              .where((PlannerInput task) => unscheduledIds.contains(task.id))
              .map((PlannerInput task) => task.estimateOrDefault),
          windowOrigin: problem.windowOrigin,
          blockOrigin: problem.blockOrigin,
          assumptions: problem.assumptions,
        );
    return FeasiblePlan(
      blocks: List<TimeBlock>.unmodifiable(blocks),
      unscheduledTaskIds: List<String>.unmodifiable(unscheduled),
      issues: List<PlanIssue>.unmodifiable(issues),
      capacity: capacity,
    );
  }

  int _compare(PlannerInput a, PlannerInput b, PlanningProblem problem) {
    final double aScore = _priorityScore(a, problem);
    final double bScore = _priorityScore(b, problem);
    final int byScore = bScore.compareTo(aScore);
    if (byScore != 0) return byScore;
    return a.id.compareTo(b.id);
  }

  double _priorityScore(PlannerInput task, PlanningProblem problem) {
    final double energyNeed = task.energyRequired / 5;
    final double energyFit =
        1 - (problem.energy.clamp(0.0, 1.0) - energyNeed).abs();
    double score = task.priority * 10 + energyFit * 6;
    final DateTime? due = task.dueDate;
    if (due != null) {
      final int hours = due.difference(problem.now).inHours;
      score += hours < 0
          ? 24
          : hours < 24
          ? 16
          : hours < 72
          ? 8
          : 0;
    }
    return score;
  }

  bool _hasIncompletePrerequisite(
    PlannerInput task,
    Map<String, PlannerInput> byId,
  ) {
    return task.prerequisiteIds.any((String id) {
      final PlannerInput? prerequisite = byId[id];
      return prerequisite != null && !prerequisite.isCompleted;
    });
  }

  _Placement? _findPlacement({
    required PlannerInput task,
    required PlanningProblem problem,
    required List<TimeBlock> occupied,
  }) {
    final Duration duration = task.estimateOrDefault;
    final List<WorkWindowEntity> windows =
        List<WorkWindowEntity>.from(problem.workWindows)..sort(
          (WorkWindowEntity a, WorkWindowEntity b) =>
              a.start.compareTo(b.start),
        );
    for (final WorkWindowEntity window in windows) {
      if (task.energyRequired < window.energyFloor ||
          task.energyRequired > window.energyCeiling) {
        continue;
      }
      DateTime cursor = window.start.isAfter(problem.now)
          ? window.start
          : problem.now;
      final List<TimeBlock> relevant =
          occupied
              .where(
                (TimeBlock block) =>
                    block.start.isBefore(window.end) &&
                    block.end.isAfter(window.start),
              )
              .toList(growable: false)
            ..sort((TimeBlock a, TimeBlock b) => a.start.compareTo(b.start));
      for (final TimeBlock block in relevant) {
        if (!cursor.add(duration).isAfter(block.start)) break;
        if (cursor.isBefore(block.end)) cursor = block.end;
      }
      final DateTime end = cursor.add(duration);
      if (!end.isAfter(window.end)) return _Placement(cursor, end);
    }
    return null;
  }
}

class _Placement {
  const _Placement(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
