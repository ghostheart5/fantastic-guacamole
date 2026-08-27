import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/decision_observation_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
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
    required this.executionMinutes,
    required this.rationale,
    required this.evidence,
    required this.confidence,
    required this.plan,
    required this.rankedCandidates,
    required this.recoveryRecommendations,
    required this.confidenceProfile,
    this.modelVersion = 'predictive-planning-v2',
  });
  final TaskEntity? selectedTask;
  final List<TaskEntity> orderedTasks;
  final bool shouldTakeBreak;
  final int executionMinutes;
  final String rationale;
  final List<DecisionEvidence> evidence;
  final DecisionConfidence confidence;
  final FeasiblePlan plan;
  final List<RankedTask> rankedCandidates;
  final List<RecoveryRecommendation> recoveryRecommendations;
  final PredictiveConfidenceProfile confidenceProfile;
  final String modelVersion;
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
    double priorityScale = 1,
    List<WorkWindowEntity> workWindows = const <WorkWindowEntity>[],
    List<TimeBlock> existingBlocks = const <TimeBlock>[],
    PredictiveEvidenceOrigin workWindowOrigin =
        PredictiveEvidenceOrigin.observed,
    PredictiveEvidenceOrigin existingBlockOrigin =
        PredictiveEvidenceOrigin.observed,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final List<PlannerInput> resolvedInputs =
        inputs ??
        PlannerInputAdapter.fromTaskEntities(tasks ?? const <TaskEntity>[]);
    final List<PlannerInput> active = resolvedInputs
        .where((PlannerInput task) => !task.isCompleted && !task.isCanceled)
        .toList(growable: false);
    final bool usesAssumedWindow = workWindows.isEmpty;
    final List<WorkWindowEntity> resolvedWindows = usesAssumedWindow
        ? <WorkWindowEntity>[_defaultWindow(timestamp)]
        : workWindows
              .where(
                (WorkWindowEntity window) =>
                    window.status == WorkWindowStatus.planned ||
                    window.status == WorkWindowStatus.active,
              )
              .toList(growable: false);
    final List<TimeBlock> resolvedBlocks = _preserveScheduledCommitments(
      inputs: active,
      existingBlocks: existingBlocks,
      now: timestamp,
    );
    final FeasiblePlan plan = planner.plan(
      PlanningProblem(
        inputs: active,
        workWindows: resolvedWindows,
        existingBlocks: resolvedBlocks,
        energy: state.energy,
        now: timestamp,
        windowOrigin: usesAssumedWindow
            ? PredictiveEvidenceOrigin.estimated
            : workWindowOrigin,
        blockOrigin: existingBlockOrigin,
        assumptions: <String>[
          if (usesAssumedWindow)
            'No configured work window was available; a 09:00-17:00 local capacity window was assumed.',
        ],
      ),
    );
    PredictiveConfidenceProfile confidenceFor({
      required double data,
      required double precision,
    }) => PredictiveConfidenceProfile(
      sourceCompleteness: _sourceCompleteness(
        active,
        hasObservedWindow: !usesAssumedWindow,
      ),
      freshness: state.isStale ? .45 : 1,
      sampleSufficiency: data,
      intervalPrecision: precision,
      calibration: PredictiveCalibrationState.provisional,
    );
    final bool recovery = state.fatigue > .7 || state.energy < .3;
    if (recovery || active.isEmpty) {
      return DecisionRecommendation(
        selectedTask: null,
        orderedTasks: const [],
        shouldTakeBreak: recovery,
        executionMinutes: 10,
        rationale: recovery
            ? 'Recovery is recommended because energy is low or fatigue is high.'
            : 'No active tasks are available to schedule.',
        evidence: <DecisionEvidence>[
          DecisionEvidence(
            source: 'si_state',
            detail: 'energy=${state.energy}; fatigue=${state.fatigue}',
            observedAt: timestamp,
          ),
        ],
        confidence: DecisionConfidence(
          dataSufficiency: active.isEmpty ? .35 : .75,
          recommendation: recovery ? .85 : .9,
          safety: 1,
        ),
        plan: plan,
        rankedCandidates: const <RankedTask>[],
        recoveryRecommendations: recovery
            ? <RecoveryRecommendation>[
                RecoveryRecommendation(
                  trigger: RecoveryTrigger.lowEnergy,
                  subjectId: null,
                  immediateAction:
                      'Reduce scope and choose one low-energy recovery action.',
                  why:
                      'Current energy or fatigue is outside the safe execution range.',
                  consequence:
                      'Pushing a high-load task now can increase deferral and reduce tomorrow\'s capacity.',
                  confidence: confidenceFor(data: .35, precision: .65),
                ),
              ]
            : const <RecoveryRecommendation>[],
        confidenceProfile: confidenceFor(
          data: active.isEmpty ? .15 : .35,
          precision: recovery ? .65 : .25,
        ),
      );
    }
    final ranked = const TaskRanker().rank(
      active
          .map((PlannerInput input) => input.toTaskEntity())
          .toList(growable: false),
      learning: learning,
      energy: state.energy,
      fatigue: state.fatigue,
      now: timestamp,
      siState: state,
      priorityScale: priorityScale,
    );
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
        executionMinutes: 10,
        rationale:
            issue?.message ??
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
        rankedCandidates: List<RankedTask>.unmodifiable(ranked),
        recoveryRecommendations: <RecoveryRecommendation>[
          RecoveryRecommendation(
            trigger: RecoveryTrigger.capacityExceeded,
            subjectId: null,
            immediateAction:
                'Reduce or move work until every commitment fits an available window.',
            why:
                issue?.message ??
                'Available capacity cannot fit the active plan.',
            consequence:
                'Unscheduled work will roll forward or compete with an existing commitment.',
            confidence: confidenceFor(
              data: _dataSufficiency(learning, timestamp),
              precision: .8,
            ),
          ),
        ],
        confidenceProfile: confidenceFor(
          data: _dataSufficiency(learning, timestamp),
          precision: .8,
        ),
      );
    }
    final List<TaskEntity> nonAvoided = feasible
        .where(
          (TaskEntity task) =>
              _recentSkipCount(learning, task.id, timestamp) < 2,
        )
        .toList(growable: false);
    final List<TaskEntity> ordered = nonAvoided.isEmpty ? feasible : nonAvoided;
    final TaskEntity selected = ordered.first;
    final double data = _dataSufficiency(learning, timestamp);
    final RankedTask selectedRanked = ranked.firstWhere(
      (RankedTask item) => item.task.id == selected.id,
    );
    final List<RecoveryRecommendation> recoveryRecommendations =
        _recoveryRecommendations(
          selected: selected,
          ranked: selectedRanked,
          plan: plan,
          learning: learning,
          now: timestamp,
          confidence: confidenceFor(
            data: data,
            precision: plan.isFeasible ? .8 : .55,
          ),
        );
    return DecisionRecommendation(
      selectedTask: selected,
      orderedTasks: ordered,
      shouldTakeBreak: false,
      executionMinutes: selected.estimateOrDefault.inMinutes,
      rationale:
          'Selected ${selected.title} using urgency, energy fit, learned effort tolerance, and schedule feasibility.',
      evidence: <DecisionEvidence>[
        DecisionEvidence(
          source: 'task',
          detail:
              'priority=${selected.priority}; difficulty=${selected.difficulty}',
          observedAt: timestamp,
        ),
        DecisionEvidence(
          source: 'state',
          detail: 'energy=${state.energy}; fatigue=${state.fatigue}',
          observedAt: timestamp,
        ),
        DecisionEvidence(
          source: 'plan',
          detail: plan.isFeasible
              ? 'fits available work windows'
              : 'fits available capacity; other tasks remain unscheduled',
          observedAt: timestamp,
        ),
        if (learning.taskAffinity.containsKey(selected.id))
          DecisionEvidence(
            source: 'feedback',
            detail:
                'observed recommendation acceptance=${(learning.taskAffinity[selected.id] ?? .5).toStringAsFixed(2)}',
            observedAt: timestamp,
          ),
        if (nonAvoided.length != feasible.length)
          DecisionEvidence(
            source: 'feedback',
            detail:
                'suppressed ${feasible.length - nonAvoided.length} repeatedly skipped task(s) while alternatives exist',
            observedAt: timestamp,
          ),
      ],
      confidence: DecisionConfidence(
        dataSufficiency: data,
        recommendation: data * .8 + .16,
        safety: .95,
      ),
      plan: plan,
      rankedCandidates: List<RankedTask>.unmodifiable(ranked),
      recoveryRecommendations: List<RecoveryRecommendation>.unmodifiable(
        recoveryRecommendations,
      ),
      confidenceProfile: confidenceFor(
        data: data,
        precision: plan.isFeasible ? .8 : .55,
      ),
    );
  }

  double _sourceCompleteness(
    List<PlannerInput> tasks, {
    required bool hasObservedWindow,
  }) {
    if (tasks.isEmpty) return hasObservedWindow ? .55 : .35;
    final double estimateCoverage =
        tasks
            .where((PlannerInput item) => item.estimatedDuration != null)
            .length /
        tasks.length;
    final double deadlineCoverage =
        tasks.where((PlannerInput item) => item.dueDate != null).length /
        tasks.length;
    return (.45 +
            estimateCoverage * .20 +
            deadlineCoverage * .15 +
            (hasObservedWindow ? .20 : 0))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  List<RecoveryRecommendation> _recoveryRecommendations({
    required TaskEntity selected,
    required RankedTask ranked,
    required FeasiblePlan plan,
    required LearningEntity learning,
    required DateTime now,
    required PredictiveConfidenceProfile confidence,
  }) {
    final List<RecoveryRecommendation> output = <RecoveryRecommendation>[];
    if (plan.capacity.isOverloaded) {
      output.add(
        RecoveryRecommendation(
          trigger: RecoveryTrigger.capacityExceeded,
          subjectId: selected.id,
          immediateAction:
              'Protect ${selected.title} and move lower-ranked work out of the overloaded window.',
          why:
              '${plan.capacity.unscheduledMinutes} minutes do not fit the current capacity model.',
          consequence:
              'Keeping every commitment in place raises rollover and deadline pressure.',
          confidence: confidence,
          displacedSubjectIds: plan.unscheduledTaskIds,
        ),
      );
    }
    final DeadlinePressureBand deadlineBand =
        ranked.breakdown.deadlinePressure.band;
    if (deadlineBand == DeadlinePressureBand.critical ||
        deadlineBand == DeadlinePressureBand.overdue) {
      output.add(
        RecoveryRecommendation(
          trigger: deadlineBand == DeadlinePressureBand.overdue
              ? RecoveryTrigger.missedCommitment
              : RecoveryTrigger.deadlineAtRisk,
          subjectId: selected.id,
          immediateAction:
              'Recover ${selected.title} in the next feasible block.',
          why: ranked.breakdown.deadlinePressure.explanation,
          consequence:
              'Further delay reduces deadline slack and may displace another commitment.',
          confidence: confidence,
          proposedStart: _plannedStart(plan, selected.id),
        ),
      );
    }
    if (_recentSkipCount(learning, selected.id, now) >= 2) {
      output.add(
        RecoveryRecommendation(
          trigger: RecoveryTrigger.repeatedDeferral,
          subjectId: selected.id,
          immediateAction:
              'Reduce ${selected.title} to its first verifiable checkpoint before rescheduling it again.',
          why: 'This task has been skipped repeatedly in the last 14 days.',
          consequence:
              'Another unchanged retry is likely to repeat the same friction pattern.',
          confidence: confidence,
        ),
      );
    }
    return output;
  }

  DateTime? _plannedStart(FeasiblePlan plan, String taskId) {
    for (final TimeBlock block in plan.blocks) {
      if (block.taskId == taskId) return block.start;
    }
    return null;
  }

  List<TimeBlock> _preserveScheduledCommitments({
    required List<PlannerInput> inputs,
    required List<TimeBlock> existingBlocks,
    required DateTime now,
  }) {
    final Set<String> occupiedTaskIds = existingBlocks
        .where((TimeBlock block) => !block.completed)
        .map((TimeBlock block) => block.taskId)
        .toSet();
    final List<TimeBlock> blocks = List<TimeBlock>.from(existingBlocks);

    for (final PlannerInput input in inputs) {
      final DateTime? start = input.scheduledFor;
      if (start == null || occupiedTaskIds.contains(input.id)) continue;

      final DateTime end = start.add(input.estimateOrDefault);
      if (!end.isAfter(now)) continue;

      blocks.add(
        TimeBlock(
          id: 'scheduled-${input.id}-${start.microsecondsSinceEpoch}',
          taskId: input.id,
          title: input.title,
          start: start,
          end: end,
        ),
      );
      occupiedTaskIds.add(input.id);
    }

    return List<TimeBlock>.unmodifiable(blocks);
  }

  double _dataSufficiency(LearningEntity learning, DateTime now) {
    final int recentObservations = learning.observations
        .where(
          (observation) => observation.timestamp.isAfter(
            now.subtract(const Duration(days: 30)),
          ),
        )
        .length;
    final int outcomes = learning.completed + learning.skipped;
    return ((outcomes * .08) + (recentObservations * .04))
        .clamp(.35, .9)
        .toDouble();
  }

  int _recentSkipCount(LearningEntity learning, String taskId, DateTime now) {
    return learning.observations
        .where(
          (observation) =>
              observation.type == DecisionObservationType.taskSkipped &&
              observation.taskId == taskId &&
              observation.timestamp.isAfter(
                now.subtract(const Duration(days: 14)),
              ),
        )
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
