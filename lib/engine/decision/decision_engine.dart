import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/decision_observation_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/engine/planning/feasible_planner.dart';
import 'package:fantastic_guacamole/engine/tasks/task_ranker.dart';

class DecisionEvidence {
  const DecisionEvidence({
    required this.source,
    required this.detail,
    required this.observedAt,
  });
  final String source;
  final String detail;
  final DateTime observedAt;
}

class DecisionConfidence {
  const DecisionConfidence({
    required this.dataSufficiency,
    required this.recommendation,
    required this.safety,
  });
  final double dataSufficiency;
  final double recommendation;
  final double safety;
}

class DecisionRecommendation {
  const DecisionRecommendation({
    required this.selectedTask,
    required this.orderedTasks,
    required this.shouldTakeBreak,
    required this.focusMinutes,
    required this.rationale,
    required this.evidence,
    required this.confidence,
    required this.plan,
  });
  final TaskEntity? selectedTask;
  final List<TaskEntity> orderedTasks;
  final bool shouldTakeBreak;
  final int focusMinutes;
  final String rationale;
  final List<DecisionEvidence> evidence;
  final DecisionConfidence confidence;
  final FeasiblePlan plan;
}

/// The sole deterministic policy for planning-facing recommendations.
class DecisionEngine {
  const DecisionEngine({this.planner = const FeasiblePlanner()});
  final FeasiblePlanner planner;

  DecisionRecommendation recommend({
    List<PlannerInput>? inputs,
    List<TaskEntity>? tasks,
    required SiStateEntity state,
    required LearningEntity learning,
    List<WorkWindowEntity> workWindows = const <WorkWindowEntity>[],
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final List<PlannerInput> resolvedInputs = inputs ??
        PlannerInputAdapter.fromTaskEntities(tasks ?? const <TaskEntity>[]);
    final List<PlannerInput> active = resolvedInputs
        .where((PlannerInput task) => !task.isCompleted && !task.isCanceled)
        .toList(growable: false);
    final List<WorkWindowEntity> resolvedWindows = workWindows.isEmpty
        ? <WorkWindowEntity>[_defaultWindow(timestamp)]
        : workWindows
            .where((WorkWindowEntity window) =>
                window.status == WorkWindowStatus.planned ||
                window.status == WorkWindowStatus.active)
            .toList(growable: false);
    final FeasiblePlan plan = planner.plan(PlanningProblem(
      inputs: active,
      workWindows: resolvedWindows,
      existingBlocks: const [],
      energy: state.energy,
      now: timestamp,
    ));
    final bool recovery = state.fatigue > .7 || state.energy < .3;
    if (recovery || active.isEmpty) {
      return DecisionRecommendation(
        selectedTask: null,
        orderedTasks: const [],
        shouldTakeBreak: recovery,
        focusMinutes: 10,
        rationale: recovery
            ? 'Recovery is recommended because energy is low or fatigue is high.'
            : 'No active tasks are available to schedule.',
        evidence: <DecisionEvidence>[
          DecisionEvidence(source: 'si_state', detail: 'energy=${state.energy}; fatigue=${state.fatigue}', observedAt: timestamp),
        ],
        confidence: DecisionConfidence(
          dataSufficiency: active.isEmpty ? .35 : .75,
          recommendation: recovery ? .85 : .9,
          safety: 1,
        ),
        plan: plan,
      );
    }
    final ranked = const TaskRanker().rank(
      active.map((PlannerInput input) => input.toTaskEntity()).toList(growable: false),
      learning: learning,
      energy: state.energy,
      fatigue: state.fatigue,
      now: timestamp,
      siState: state,
    );
    ranked.sort((RankedTask a, RankedTask b) {
      final double aAffinity = learning.taskAffinity[a.task.id] ?? .5;
      final double bAffinity = learning.taskAffinity[b.task.id] ?? .5;
      final int byOutcome = (b.score + bAffinity * 4)
          .compareTo(a.score + aAffinity * 4);
      return byOutcome != 0 ? byOutcome : a.task.id.compareTo(b.task.id);
    });
    final List<TaskEntity> feasible = ranked
        .map((RankedTask item) => item.task)
        .where((TaskEntity task) => !plan.unscheduledTaskIds.contains(task.id))
        .toList(growable: false);
    if (feasible.isEmpty) {
      final PlanIssue? issue = plan.issues.isEmpty ? null : plan.issues.first;
      return DecisionRecommendation(
        selectedTask: null,
        orderedTasks: const <TaskEntity>[],
        shouldTakeBreak: false,
        focusMinutes: 10,
        rationale: issue?.message ??
            'No task can be scheduled without violating the current constraints.',
        evidence: <DecisionEvidence>[
          DecisionEvidence(
            source: 'plan',
            detail: issue?.message ?? 'No feasible placement was found.',
            observedAt: timestamp,
          ),
        ],
        confidence: DecisionConfidence(
          dataSufficiency: _dataSufficiency(learning, timestamp),
          recommendation: .9,
          safety: 1,
        ),
        plan: plan,
      );
    }
    final List<TaskEntity> nonAvoided = feasible
        .where((TaskEntity task) => _recentSkipCount(learning, task.id, timestamp) < 2)
        .toList(growable: false);
    final List<TaskEntity> ordered = nonAvoided.isEmpty ? feasible : nonAvoided;
    final TaskEntity selected = ordered.first;
    final double data = _dataSufficiency(learning, timestamp);
    return DecisionRecommendation(
      selectedTask: selected,
      orderedTasks: ordered,
      shouldTakeBreak: false,
      focusMinutes: selected.estimateOrDefault.inMinutes,
      rationale: 'Selected ${selected.title} using urgency, energy fit, learned effort tolerance, and schedule feasibility.',
      evidence: <DecisionEvidence>[
        DecisionEvidence(source: 'task', detail: 'priority=${selected.priority}; difficulty=${selected.difficulty}', observedAt: timestamp),
        DecisionEvidence(source: 'state', detail: 'energy=${state.energy}; fatigue=${state.fatigue}', observedAt: timestamp),
        DecisionEvidence(source: 'plan', detail: plan.isFeasible ? 'fits available work windows' : 'fits available capacity; other tasks remain unscheduled', observedAt: timestamp),
        if (learning.taskAffinity.containsKey(selected.id))
          DecisionEvidence(source: 'feedback', detail: 'observed recommendation acceptance=${(learning.taskAffinity[selected.id] ?? .5).toStringAsFixed(2)}', observedAt: timestamp),
        if (nonAvoided.length != feasible.length)
          DecisionEvidence(source: 'feedback', detail: 'suppressed ${feasible.length - nonAvoided.length} repeatedly skipped task(s) while alternatives exist', observedAt: timestamp),
      ],
      confidence: DecisionConfidence(dataSufficiency: data, recommendation: data * .8 + .16, safety: .95),
      plan: plan,
    );
  }

  double _dataSufficiency(LearningEntity learning, DateTime now) {
    final int recentObservations = learning.observations
        .where((observation) =>
            observation.timestamp.isAfter(now.subtract(const Duration(days: 30))))
        .length;
    final int outcomes = learning.completed + learning.skipped;
    return ((outcomes * .08) + (recentObservations * .04))
        .clamp(.35, .9)
        .toDouble();
  }

  int _recentSkipCount(LearningEntity learning, String taskId, DateTime now) {
    return learning.observations
        .where((observation) =>
            observation.type == DecisionObservationType.taskSkipped &&
            observation.taskId == taskId &&
            observation.timestamp.isAfter(now.subtract(const Duration(days: 14))))
        .length;
  }

  WorkWindowEntity _defaultWindow(DateTime now) {
    DateTime start = DateTime(now.year, now.month, now.day, 9);
    DateTime end = DateTime(now.year, now.month, now.day, 17);
    if (!end.isAfter(now)) {
      start = start.add(const Duration(days: 1));
      end = end.add(const Duration(days: 1));
    }
    return WorkWindowEntity(
      id: 'default-${start.toIso8601String()}',
      start: start,
      end: end,
    );
  }
}
