import 'dart:math' as math;

import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';

/// Deterministic counterfactual projector.
///
/// This engine does not claim causal certainty. It compares explicit
/// interventions against one immutable baseline and returns provisional ranges,
/// evidence, assumptions, and goal/Timeline/Progression consequences.
class FutureConsequenceEngine {
  const FutureConsequenceEngine();

  TrajectoryComparison compare({
    required TrajectoryBaseline baseline,
    required List<TrajectoryIntervention> interventions,
    DateTime? generatedAt,
  }) {
    final DateTime now = (generatedAt ?? DateTime.now()).toUtc();
    final List<TrajectoryScenarioOutcome> outcomes =
        interventions
            .map(
              (TrajectoryIntervention intervention) => project(
                baseline: baseline,
                intervention: intervention,
                generatedAt: now,
              ),
            )
            .toList(growable: false)
          ..sort(
            (TrajectoryScenarioOutcome a, TrajectoryScenarioOutcome b) =>
                b.utilityScore.compareTo(a.utilityScore),
          );
    return TrajectoryComparison(
      baseline: baseline,
      outcomes: List<TrajectoryScenarioOutcome>.unmodifiable(outcomes),
      recommendedScenarioId: outcomes.isEmpty ? '' : outcomes.first.id,
    );
  }

  TrajectoryScenarioOutcome project({
    required TrajectoryBaseline baseline,
    required TrajectoryIntervention intervention,
    DateTime? generatedAt,
  }) {
    final DateTime now = (generatedAt ?? DateTime.now()).toUtc();
    final TrajectoryTaskNode? subject = _task(baseline, intervention.subjectId);
    final int horizonDays = math.max(1, intervention.horizon.inDays);
    final ({int momentum, int pressure}) deltas = _metricDeltas(
      baseline: baseline,
      intervention: intervention,
      subject: subject,
    );
    final int projectedMomentum = (baseline.momentum + deltas.momentum).clamp(
      0,
      100,
    );
    final int projectedPressure = (baseline.pressure + deltas.pressure).clamp(
      0,
      100,
    );
    final int uncertainty = _uncertainty(baseline, horizonDays);
    final PredictiveConfidenceProfile confidence = _confidence(
      baseline,
      uncertainty,
      horizonDays,
    );
    final TimelineConsequence timeline = _timelineConsequence(
      baseline,
      intervention,
      subject,
      now,
    );
    final TrajectoryRiskProjection risk = _riskProjection(
      baseline: baseline,
      intervention: intervention,
      subject: subject,
      projectedPressure: projectedPressure,
      timeline: timeline,
    );
    final List<GoalDelayProjection> goals = _goalProjections(
      baseline: baseline,
      intervention: intervention,
      subject: subject,
      generatedAt: now,
      confidence: confidence,
      uncertainty: uncertainty,
    );
    final ProgressionConsequence progression = _progressionConsequence(
      intervention,
      subject,
    );
    final int totalGoalDelay = goals.fold<int>(
      0,
      (int total, GoalDelayProjection goal) =>
          total + math.max(0, goal.delayDays),
    );
    final double utility =
        (deltas.momentum * .42) -
        (deltas.pressure * .36) -
        ((risk.projectedScore - risk.currentScore) * .28) -
        (totalGoalDelay * 1.7) +
        (progression.potentialXp * .06) -
        (timeline.deadlineCrossings * 4.0);
    final String subjectLabel = subject?.title ?? 'the current portfolio';

    return TrajectoryScenarioOutcome(
      id: '${baseline.revision}:${intervention.id}',
      baselineRevision: baseline.revision,
      intervention: intervention,
      generatedAt: now,
      projectedMomentum: projectedMomentum,
      projectedPressure: projectedPressure,
      uncertainty: uncertainty,
      confidence: confidence,
      risk: risk,
      timeline: timeline,
      goals: List<GoalDelayProjection>.unmodifiable(goals),
      progression: progression,
      evidence: <String>[
        'baseline_revision=${baseline.revision}',
        'observations=${baseline.observationCount}',
        'completed_window=${baseline.completedInWindow}',
        'deferred_window=${baseline.deferredInWindow}',
        'available_minutes=${baseline.availableMinutes}',
        'occupied_minutes=${baseline.occupiedMinutes}',
        'unscheduled_minutes=${baseline.unscheduledMinutes}',
        'subject=${subject?.id ?? 'portfolio'}',
        ...baseline.sourceRevisions.entries.map(
          (MapEntry<String, String> item) => '${item.key}=${item.value}',
        ),
      ],
      assumptions: <String>[
        ...intervention.assumptions,
        if (!baseline.hasObservedEnergy)
          'Energy is a seeded planning estimate, not a user observation.',
        if (!baseline.hasObservedAvailability)
          'No observed availability is configured. Capacity-based risk and goal completion dates are withheld.',
        'Only the declared intervention changes; unmodeled life events remain outside this scenario.',
        'Projected XP is informational and is never awarded by this simulation.',
      ],
      explanation:
          '${intervention.title} changes $subjectLabel against baseline ${baseline.revision}. '
          'Projected risk is ${risk.band.name}; ${timeline.summary}',
      utilityScore: utility,
    );
  }

  ({int momentum, int pressure}) _metricDeltas({
    required TrajectoryBaseline baseline,
    required TrajectoryIntervention intervention,
    required TrajectoryTaskNode? subject,
  }) {
    final int priority = subject?.priority.clamp(1, 5) ?? 3;
    final int load = ((subject?.estimatedMinutes ?? 45) / 30).ceil().clamp(
      1,
      8,
    );
    return switch (intervention.type) {
      TrajectoryInterventionType.maintainCourse => (momentum: 0, pressure: 0),
      TrajectoryInterventionType.applySmartPlanner => (
        momentum: 5 + math.min(5, intervention.proposedBlocks.length),
        pressure: -(4 + math.min(12, baseline.unscheduledMinutes ~/ 30))
            .toInt(),
      ),
      TrajectoryInterventionType.completeTask => (
        momentum: 4 + priority * 2,
        pressure: -(2 + math.min(8, load)).toInt(),
      ),
      TrajectoryInterventionType.delayTask => (
        momentum: -(2 + priority),
        pressure: (3 + priority + math.min(6, intervention.delay.inDays))
            .toInt(),
      ),
      TrajectoryInterventionType.reduceScope => (
        momentum: baseline.pressure >= 65 ? 4 : 1,
        pressure: -(5 + math.min(10, load)).toInt(),
      ),
      TrajectoryInterventionType.recoverCommitment => (
        momentum: 3 + priority,
        pressure: -(3 + math.min(7, load)).toInt(),
      ),
    };
  }

  int _uncertainty(TrajectoryBaseline baseline, int horizonDays) {
    final int sampleRelief = math.min(12, baseline.observationCount);
    final int horizonPenalty = (horizonDays / 7).ceil() * 3;
    final int missingDataPenalty = baseline.confidence.sourceCompleteness < .7
        ? 8
        : 0;
    return (24 - sampleRelief + horizonPenalty + missingDataPenalty).clamp(
      8,
      42,
    );
  }

  PredictiveConfidenceProfile _confidence(
    TrajectoryBaseline baseline,
    int uncertainty,
    int horizonDays,
  ) {
    final double horizonFreshness = (1 - (horizonDays - 1) / 120).clamp(
      .2,
      1.0,
    );
    return PredictiveConfidenceProfile(
      sourceCompleteness: baseline.confidence.sourceCompleteness,
      freshness: baseline.confidence.freshness * horizonFreshness,
      sampleSufficiency: baseline.confidence.sampleSufficiency,
      intervalPrecision: (1 - uncertainty * 2 / 100).clamp(0.0, 1.0),
      calibration: PredictiveCalibrationState.provisional,
    );
  }

  TimelineConsequence _timelineConsequence(
    TrajectoryBaseline baseline,
    TrajectoryIntervention intervention,
    TrajectoryTaskNode? subject,
    DateTime now,
  ) {
    final List<String> affectedBlocks = baseline.blocks
        .where((TrajectoryBlockNode block) => block.taskId == subject?.id)
        .map((TrajectoryBlockNode block) => block.id)
        .toList(growable: false);
    int deadlineCrossings = 0;
    if (intervention.type == TrajectoryInterventionType.delayTask &&
        subject?.dueAt != null) {
      final DateTime movedTo = (subject!.scheduledAt ?? now).add(
        intervention.delay,
      );
      if (movedTo.isAfter(subject.dueAt!)) deadlineCrossings = 1;
    }
    final int minutesAdded = switch (intervention.type) {
      TrajectoryInterventionType.delayTask => subject?.estimatedMinutes ?? 0,
      TrajectoryInterventionType.applySmartPlanner =>
        intervention.proposedBlocks.fold<int>(
          0,
          (int total, TrajectoryBlockNode block) => total + block.minutes,
        ),
      _ => 0,
    };
    final String summary = switch (intervention.type) {
      TrajectoryInterventionType.applySmartPlanner =>
        '${intervention.proposedBlocks.length} Smart Planner block(s) are projected; ${intervention.displacedSubjectIds.length} commitment(s) remain displaced.',
      TrajectoryInterventionType.delayTask =>
        '${affectedBlocks.length} existing block(s) are affected; $deadlineCrossings deadline crossing(s) are projected.',
      TrajectoryInterventionType.completeTask =>
        '${affectedBlocks.length} linked block(s) can close after the simulated completion.',
      TrajectoryInterventionType.reduceScope =>
        '${affectedBlocks.length} linked block(s) can be removed from active load.',
      _ => '${affectedBlocks.length} linked Timeline block(s) are affected.',
    };
    return TimelineConsequence(
      affectedBlockIds: List<String>.unmodifiable(affectedBlocks),
      displacedSubjectIds: List<String>.unmodifiable(
        intervention.displacedSubjectIds,
      ),
      deadlineCrossings: deadlineCrossings,
      minutesAdded: minutesAdded,
      summary: summary,
    );
  }

  TrajectoryRiskProjection _riskProjection({
    required TrajectoryBaseline baseline,
    required TrajectoryIntervention intervention,
    required TrajectoryTaskNode? subject,
    required int projectedPressure,
    required TimelineConsequence timeline,
  }) {
    final int currentDeferral = baseline.observationCount == 0
        ? 0
        : ((baseline.deferredInWindow / baseline.observationCount) * 100)
              .round();
    int projectedDeferral = currentDeferral;
    if (intervention.type == TrajectoryInterventionType.delayTask) {
      projectedDeferral = (projectedDeferral + 15).clamp(0, 100);
    } else if (intervention.type == TrajectoryInterventionType.completeTask ||
        intervention.type == TrajectoryInterventionType.recoverCommitment) {
      projectedDeferral = (projectedDeferral - 10).clamp(0, 100);
    }
    final int currentDeadline =
        (baseline.overdueCount * 18 + baseline.atRiskCount * 8).clamp(0, 100);
    final int projectedDeadline =
        (currentDeadline + timeline.deadlineCrossings * 22).clamp(0, 100);
    final int capacityBase = !baseline.hasObservedAvailability
        ? 0
        : baseline.availableMinutes <= 0
        ? (baseline.requiredMinutes > 0 ? 100 : 0)
        : ((baseline.unscheduledMinutes / baseline.availableMinutes) * 100)
              .round()
              .clamp(0, 100);
    int projectedCapacity = capacityBase;
    if (intervention.type == TrajectoryInterventionType.applySmartPlanner ||
        intervention.type == TrajectoryInterventionType.reduceScope) {
      projectedCapacity = (capacityBase - 18).clamp(0, 100);
    }
    final List<int> currentRiskSignals = <int>[
      baseline.pressure,
      currentDeferral,
      currentDeadline,
      if (baseline.hasObservedAvailability) capacityBase,
    ];
    final List<int> projectedRiskSignals = <int>[
      projectedPressure,
      projectedDeferral,
      projectedDeadline,
      if (baseline.hasObservedAvailability) projectedCapacity,
    ];
    final int current = _combinedRisk(currentRiskSignals);
    final int projected = _combinedRisk(projectedRiskSignals);
    return TrajectoryRiskProjection(
      currentScore: current,
      projectedScore: projected,
      band: _riskBand(projected),
      contributions: <TrajectoryRiskContribution>[
        TrajectoryRiskContribution(
          code: 'pressure',
          label: 'Pressure load',
          currentScore: baseline.pressure,
          projectedScore: projectedPressure,
          explanation: 'Sustained pressure raises rollover and recovery risk.',
        ),
        TrajectoryRiskContribution(
          code: 'deferral',
          label: 'Deferral accumulation',
          currentScore: currentDeferral,
          projectedScore: projectedDeferral,
          explanation:
              'Repeated deferrals compound uncertainty in future capacity.',
        ),
        TrajectoryRiskContribution(
          code: 'deadline',
          label: 'Deadline pressure',
          currentScore: currentDeadline,
          projectedScore: projectedDeadline,
          explanation:
              'Crossed deadlines reduce slack and can displace other work.',
        ),
        TrajectoryRiskContribution(
          code: 'capacity',
          label: 'Capacity overload',
          currentScore: capacityBase,
          projectedScore: projectedCapacity,
          explanation: baseline.hasObservedAvailability
              ? 'Unscheduled work indicates that current commitments do not fit.'
              : 'Capacity risk is not scored until working availability is configured.',
        ),
      ],
    );
  }

  int _combinedRisk(List<int> scores) {
    double survival = 1;
    for (final int score in scores) {
      survival *= 1 - (score.clamp(0, 100) / 100 * .45);
    }
    return ((1 - survival) * 100).round().clamp(0, 100);
  }

  TrajectoryRiskBand _riskBand(int score) => switch (score) {
    >= 80 => TrajectoryRiskBand.critical,
    >= 60 => TrajectoryRiskBand.elevated,
    >= 35 => TrajectoryRiskBand.watch,
    _ => TrajectoryRiskBand.low,
  };

  List<GoalDelayProjection> _goalProjections({
    required TrajectoryBaseline baseline,
    required TrajectoryIntervention intervention,
    required TrajectoryTaskNode? subject,
    required DateTime generatedAt,
    required PredictiveConfidenceProfile confidence,
    required int uncertainty,
  }) {
    if (!baseline.hasObservedAvailability) {
      return const <GoalDelayProjection>[];
    }
    final int freeMinutes = math.max(
      30,
      baseline.availableMinutes - baseline.occupiedMinutes,
    );
    return baseline.goals
        .map((TrajectoryGoalNode goal) {
          final List<TrajectoryTaskNode> linked = baseline.tasks
              .where(
                (TrajectoryTaskNode task) =>
                    goal.linkedTaskIds.contains(task.id),
              )
              .toList(growable: false);
          int remaining = linked.fold<int>(
            0,
            (int total, TrajectoryTaskNode task) =>
                total + task.estimatedMinutes,
          );
          if ((intervention.type == TrajectoryInterventionType.completeTask ||
                  intervention.type ==
                      TrajectoryInterventionType.reduceScope) &&
              subject != null &&
              goal.linkedTaskIds.contains(subject.id)) {
            remaining = math.max(0, remaining - subject.estimatedMinutes);
          }
          final int workDays = math.max(1, (remaining / freeMinutes).ceil());
          int interventionDelay = 0;
          if (intervention.type == TrajectoryInterventionType.delayTask &&
              subject != null &&
              goal.linkedTaskIds.contains(subject.id)) {
            interventionDelay = math.max(1, intervention.delay.inDays);
          }
          final DateTime projected = generatedAt.add(
            Duration(days: workDays + interventionDelay),
          );
          final int intervalDays = math.max(1, (uncertainty / 8).ceil());
          final int delayDays = goal.targetDate == null
              ? 0
              : math.max(0, projected.difference(goal.targetDate!).inDays);
          return GoalDelayProjection(
            goalId: goal.id,
            goalTitle: goal.title,
            targetDate: goal.targetDate,
            projectedCompletion: projected,
            lowerCompletion: projected.subtract(Duration(days: intervalDays)),
            upperCompletion: projected.add(Duration(days: intervalDays)),
            delayDays: delayDays,
            remainingMinutes: remaining,
            confidence: confidence,
            explanation: goal.targetDate == null
                ? '$remaining remaining linked minutes; no target date is recorded.'
                : delayDays > 0
                ? 'Projected completion crosses the target by about $delayDays day(s).'
                : 'Projected completion remains inside the recorded target date.',
          );
        })
        .toList(growable: false);
  }

  ProgressionConsequence _progressionConsequence(
    TrajectoryIntervention intervention,
    TrajectoryTaskNode? subject,
  ) {
    final int potentialXp = switch (intervention.type) {
      TrajectoryInterventionType.completeTask ||
      TrajectoryInterventionType.recoverCommitment =>
        8 + (subject?.priority.clamp(1, 5) ?? 3) * 2,
      TrajectoryInterventionType.applySmartPlanner => 6,
      _ => 0,
    };
    final bool protectsStreak = switch (intervention.type) {
      TrajectoryInterventionType.completeTask ||
      TrajectoryInterventionType.recoverCommitment ||
      TrajectoryInterventionType.applySmartPlanner => true,
      _ => false,
    };
    return ProgressionConsequence(
      potentialXp: potentialXp,
      streakProtected: protectsStreak,
      summary: potentialXp == 0
          ? 'No Progression reward is projected from this intervention alone.'
          : 'Up to $potentialXp XP is informationally projected if the action is actually completed; current streak protection is ${protectsStreak ? 'supported' : 'not supported'}.',
    );
  }

  TrajectoryTaskNode? _task(TrajectoryBaseline baseline, String? id) {
    if (id == null) return null;
    for (final TrajectoryTaskNode task in baseline.tasks) {
      if (task.id == id) return task;
    }
    return null;
  }
}
