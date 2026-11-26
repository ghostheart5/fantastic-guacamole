import 'dart:math' as math;

import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_calibration_adjustment.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/engine/si/si_deadline.dart';
import 'package:fantastic_guacamole/engine/trajectory/trajectory_habit_projection.dart';

/// Deterministic counterfactual projector.
///
/// This engine does not claim causal certainty. It compares explicit
/// interventions against one immutable baseline and returns provisional ranges,
/// evidence, assumptions, and goal/Timeline/Progression consequences.
///
/// Model v4: the time range (the intervention's horizon) decides which tasks
/// count, and workload is the share of free time the work in the range needs.
class FutureConsequenceEngine {
  const FutureConsequenceEngine();

  /// The work inside a range of [horizonDays] local calendar days from [now]:
  /// a task counts when its earliest scheduled or due time is no later than
  /// the same wall-clock time [horizonDays] days later, when it is overdue,
  /// or when it has no date (undated tasks count in every range). A whole-day
  /// deadline owns its whole local day. Expected completions follow the last
  /// 7 days' pace: mid = round(completed / 7 x days), capped at the tasks in
  /// the range, with ceil(sqrt(mid)) either side.
  static TrajectoryHorizonWorkload horizonWorkload({
    required List<TrajectoryTaskNode> tasks,
    required DateTime now,
    required int horizonDays,
    required int completedLast7Days,
  }) {
    final int days = math.max(1, horizonDays);
    final DateTime local = now.toLocal();
    // Calendar fields, not Duration: a clock change must not shift the end.
    final DateTime end = DateTime(
      local.year,
      local.month,
      local.day + days,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
    final DateTime dayAfterRange = DateTime(
      local.year,
      local.month,
      local.day + days + 1,
    );
    final Set<String> ids = <String>{};
    int minutes = 0;
    int undated = 0;
    for (final TrajectoryTaskNode task in tasks) {
      final DateTime? scheduled = task.scheduledAt;
      final DateTime? due = task.dueAt;
      final bool dated = scheduled != null || due != null;
      final bool inside =
          !dated ||
          (scheduled != null && !scheduled.isAfter(end)) ||
          (due != null &&
              (task.dueDay != null
                  ? siDeadlinePast(due, task.dueDay, dayAfterRange)
                  : !due.isAfter(end)));
      if (!inside || !ids.add(task.id)) continue;
      if (!dated) undated++;
      minutes += math.max(0, task.estimatedMinutes);
    }
    final int count = ids.length;
    final int mid = math.min(
      count,
      (math.max(0, completedLast7Days) / 7 * days).round(),
    );
    final int spread = math.sqrt(mid).ceil();
    return TrajectoryHorizonWorkload(
      horizonDays: days,
      taskIds: ids,
      requiredMinutes: minutes,
      expectedCompletions: TrajectoryExpectedCompletions(
        low: math.max(0, mid - spread),
        mid: mid,
        high: math.min(count, mid + spread),
      ),
      undatedTasks: undated,
    );
  }

  /// The share of free time (0-100) that [requiredMinutes] need over [days]
  /// days of [dailyFreeMinutes]: 0 without work, 100 with work and no free
  /// time.
  static int capacityLoad({
    required int requiredMinutes,
    required int dailyFreeMinutes,
    required int days,
  }) {
    if (requiredMinutes <= 0) return 0;
    if (dailyFreeMinutes <= 0) return 100;
    return (100 * requiredMinutes / (dailyFreeMinutes * math.max(1, days)))
        .round()
        .clamp(0, 100);
  }

  TrajectoryComparison compare({
    required TrajectoryBaseline baseline,
    required List<TrajectoryIntervention> interventions,
    DateTime? generatedAt,
    TrajectoryCalibrationAdjustment? calibration,
  }) {
    final DateTime now = (generatedAt ?? DateTime.now()).toUtc();
    final List<TrajectoryScenarioOutcome> outcomes =
        interventions
            .map(
              (TrajectoryIntervention intervention) => project(
                baseline: baseline,
                intervention: intervention,
                generatedAt: now,
                calibration: calibration,
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
    TrajectoryCalibrationAdjustment? calibration,
  }) {
    final DateTime now = (generatedAt ?? DateTime.now()).toUtc();
    final TrajectoryTaskNode? subject = _task(baseline, intervention.subjectId);
    final int horizonDays = math.max(1, intervention.horizon.inDays);
    final TrajectoryHorizonWorkload workload = horizonWorkload(
      tasks: baseline.tasks,
      now: baseline.observedAt,
      horizonDays: horizonDays,
      completedLast7Days: baseline.completedInWindow,
    );
    final int momentumDelta = _momentumDelta(
      baseline: baseline,
      intervention: intervention,
      subject: subject,
    );
    final int projectedMomentum = (baseline.momentum + momentumDelta).clamp(
      0,
      100,
    );
    final int reliefMinutes = _reliefMinutes(intervention, subject, workload);
    final int keepGoingPressure = capacityLoad(
      requiredMinutes: workload.requiredMinutes,
      dailyFreeMinutes: baseline.dailyFreeMinutes,
      days: horizonDays,
    );
    final int projectedPressure = capacityLoad(
      requiredMinutes: workload.requiredMinutes - reliefMinutes,
      dailyFreeMinutes: baseline.dailyFreeMinutes,
      days: horizonDays,
    );
    // Options are ranked against keeping going over the same range, on the
    // unrounded share of free time, so removing a typical task keeps its
    // advantage at long ranges where the shown whole percent rounds it away.
    final double pressureDelta = baseline.dailyFreeMinutes <= 0
        ? (projectedPressure - keepGoingPressure).toDouble()
        : -100 * reliefMinutes / (baseline.dailyFreeMinutes * horizonDays);
    // Recorded forecast accuracy, when supplied, widens or narrows the range
    // within the engine's bounds and sets the calibration state.
    final int baseUncertainty = _uncertainty(baseline, horizonDays);
    final int uncertainty =
        calibration?.apply(baseUncertainty) ?? baseUncertainty;
    final PredictiveConfidenceProfile confidence = _confidence(
      baseline,
      uncertainty,
      horizonDays,
      calibration?.state ?? PredictiveCalibrationState.provisional,
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
      currentPressure: keepGoingPressure,
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
        (momentumDelta * .42) -
        (pressureDelta * .36) -
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
        'no_context_available_minutes=${baseline.noContextAvailableMinutes}',
        'occupied_minutes=${baseline.occupiedMinutes}',
        'unscheduled_minutes=${baseline.unscheduledMinutes}',
        'no_context_unscheduled_minutes=${baseline.noContextUnscheduledMinutes}',
        if (baseline.personContextTrace.isNotEmpty)
          'person_context_trace=${baseline.personContextTrace}',
        'subject=${subject?.id ?? 'portfolio'}',
        'horizon_days=$horizonDays',
        'daily_free_minutes=${baseline.dailyFreeMinutes}',
        'daily_free_origin=${baseline.dailyFreeOrigin.name}',
        'tasks_in_horizon=${workload.taskCount}',
        'required_minutes_in_horizon=${workload.requiredMinutes}',
        'expected_completions=${workload.expectedCompletions.low}-${workload.expectedCompletions.mid}-${workload.expectedCompletions.high}',
        // Habit lines are listed as data only; nothing above reads them.
        ...baseline.habits.map(TrajectoryHabitProjection.evidenceLine),
        ...baseline.sourceRevisions.entries.map(
          (MapEntry<String, String> item) => '${item.key}=${item.value}',
        ),
      ],
      assumptions: <String>[
        ...intervention.assumptions,
        ...baseline.assumptions,
        if (goals.isNotEmpty) trajectoryGoalDateAssumption,
        ...baseline.personContextWarnings.map(
          (String warning) => 'Person Context constraint: $warning',
        ),
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

  /// Momentum deltas keep their v3 constants (a known limitation: they are
  /// not fitted to the person's observed rates).
  int _momentumDelta({
    required TrajectoryBaseline baseline,
    required TrajectoryIntervention intervention,
    required TrajectoryTaskNode? subject,
  }) {
    final int priority = subject?.priority.clamp(1, 5) ?? 3;
    return switch (intervention.type) {
      TrajectoryInterventionType.maintainCourse => 0,
      TrajectoryInterventionType.applySmartPlanner =>
        5 + math.min(5, intervention.proposedBlocks.length),
      TrajectoryInterventionType.completeTask => 4 + priority * 2,
      TrajectoryInterventionType.delayTask => -(2 + priority),
      TrajectoryInterventionType.reduceScope => baseline.pressure >= 65 ? 4 : 1,
      TrajectoryInterventionType.recoverCommitment => 3 + priority,
    };
  }

  /// Minutes an option takes out of the range: completing or removing a task
  /// that is in the range removes its minutes. Delaying keeps them (its cost
  /// shows as deadline crossings); the other options remove no work.
  int _reliefMinutes(
    TrajectoryIntervention intervention,
    TrajectoryTaskNode? subject,
    TrajectoryHorizonWorkload workload,
  ) {
    if (subject == null || !workload.taskIds.contains(subject.id)) return 0;
    return switch (intervention.type) {
      TrajectoryInterventionType.completeTask ||
      TrajectoryInterventionType.reduceScope => math.max(
        0,
        subject.estimatedMinutes,
      ),
      _ => 0,
    };
  }

  int _uncertainty(TrajectoryBaseline baseline, int horizonDays) {
    final int sampleRelief = math.min(12, baseline.observationCount);
    final int horizonPenalty = (horizonDays / 7).ceil() * 3;
    final int missingDataPenalty = baseline.confidence.sourceCompleteness < .7
        ? 8
        : 0;
    return (24 - sampleRelief + horizonPenalty + missingDataPenalty).clamp(
      trajectoryUncertaintyMinimum,
      trajectoryUncertaintyMaximum,
    );
  }

  PredictiveConfidenceProfile _confidence(
    TrajectoryBaseline baseline,
    int uncertainty,
    int horizonDays,
    PredictiveCalibrationState calibration,
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
      calibration: calibration,
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
        '${intervention.proposedBlocks.length} Choose a step block(s) are projected; ${intervention.displacedSubjectIds.length} commitment(s) remain displaced.',
      TrajectoryInterventionType.delayTask =>
        '${affectedBlocks.length} existing block(s) are affected; $deadlineCrossings deadline crossing(s) are projected.',
      TrajectoryInterventionType.completeTask =>
        '${affectedBlocks.length} linked block(s) can close after the simulated completion.',
      TrajectoryInterventionType.reduceScope =>
        '${affectedBlocks.length} linked block(s) can be removed from active load.',
      _ => '${affectedBlocks.length} linked Schedule block(s) are affected.',
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
    required int currentPressure,
    required int projectedPressure,
    required TimelineConsequence timeline,
  }) {
    // currentPressure is keeping going over the same range, so current and
    // projected describe the same window.
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
      currentPressure,
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
          currentScore: currentPressure,
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
          isScored: baseline.hasObservedAvailability,
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
    if (!baseline.hasObservedAvailability || baseline.dailyFreeMinutes <= 0) {
      return const <GoalDelayProjection>[];
    }
    final int freeMinutes = baseline.dailyFreeMinutes;
    final DateTime local = generatedAt.toLocal();
    // Calendar days at the same local clock time: a clock change must not
    // shift the date.
    DateTime daysLater(int days) => DateTime(
      local.year,
      local.month,
      local.day + days,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    ).toUtc();
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
          // Range-independent: the goal's remaining minutes at the daily free
          // time (trajectoryGoalDateAssumption states this).
          final int workDays = math.max(1, (remaining / freeMinutes).ceil());
          int interventionDelay = 0;
          if (intervention.type == TrajectoryInterventionType.delayTask &&
              subject != null &&
              goal.linkedTaskIds.contains(subject.id)) {
            interventionDelay = math.max(1, intervention.delay.inDays);
          }
          final int projectedDays = workDays + interventionDelay;
          final DateTime projected = daysLater(projectedDays);
          final int intervalDays = math.max(1, (uncertainty / 8).ceil());
          final int delayDays = goal.targetDate == null
              ? 0
              : math.max(0, _calendarDaysBetween(goal.targetDate!, projected));
          return GoalDelayProjection(
            goalId: goal.id,
            goalTitle: goal.title,
            targetDate: goal.targetDate,
            projectedCompletion: projected,
            lowerCompletion: daysLater(projectedDays - intervalDays),
            upperCompletion: daysLater(projectedDays + intervalDays),
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

  /// Local calendar days from the day of [from] to the day of [to].
  static int _calendarDaysBetween(DateTime from, DateTime to) {
    final DateTime a = from.toLocal();
    final DateTime b = to.toLocal();
    return DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  }

  ProgressionConsequence _progressionConsequence(
    TrajectoryIntervention intervention,
    TrajectoryTaskNode? subject,
  ) {
    final int potentialXp = switch (intervention.type) {
      TrajectoryInterventionType.completeTask => ProgressionPolicy.completionXp,
      TrajectoryInterventionType.recoverCommitment => 0,
      TrajectoryInterventionType.applySmartPlanner => 0,
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
          ? 'No Activity reward is projected from this intervention alone.'
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
