// CHRONOSPARK-CLASS: SHIPPING | Feature: Trajectory forecasting
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';

enum TrajectorySourceState { loading, ready, empty, partial, offline, error }

enum TrajectoryRiskBand { unknown, low, watch, elevated, critical }

enum TrajectoryInterventionType {
  maintainCourse,
  applySmartPlanner,
  completeTask,
  delayTask,
  reduceScope,
  recoverCommitment,
}

class TrajectoryTaskNode {
  const TrajectoryTaskNode({
    required this.id,
    required this.title,
    required this.priority,
    required this.estimatedMinutes,
    this.goalId,
    this.dueAt,
    this.scheduledAt,
  });

  final String id;
  final String title;
  final int priority;
  final int estimatedMinutes;
  final String? goalId;
  final DateTime? dueAt;
  final DateTime? scheduledAt;
}

class TrajectoryGoalNode {
  TrajectoryGoalNode({
    required this.id,
    required this.title,
    required List<String> linkedTaskIds,
    this.targetDate,
  }) : linkedTaskIds = List<String>.unmodifiable(linkedTaskIds);

  final String id;
  final String title;
  final DateTime? targetDate;
  final List<String> linkedTaskIds;
}

class TrajectoryBlockNode {
  const TrajectoryBlockNode({
    required this.id,
    required this.taskId,
    required this.start,
    required this.end,
  });

  final String id;
  final String taskId;
  final DateTime start;
  final DateTime end;

  int get minutes => end.isAfter(start) ? end.difference(start).inMinutes : 0;
}

class TrajectoryTimelineSignal {
  const TrajectoryTimelineSignal({
    required this.id,
    required this.relatedId,
    required this.dueAt,
    required this.isOverdue,
    required this.isAtRisk,
  });

  final String id;
  final String? relatedId;
  final DateTime? dueAt;
  final bool isOverdue;
  final bool isAtRisk;
}

class TrajectoryProgressionSnapshot {
  const TrajectoryProgressionSnapshot({
    required this.level,
    required this.xp,
    required this.streak,
  });

  final int level;
  final int xp;
  final int streak;
}

class TrajectoryBaseline {
  TrajectoryBaseline({
    required this.accountScope,
    required this.revision,
    required this.observedAt,
    required this.evidenceWindow,
    required this.momentum,
    required this.pressure,
    required this.energy,
    required this.completedInWindow,
    required this.deferredInWindow,
    required this.observationCount,
    required this.availableMinutes,
    required this.occupiedMinutes,
    required this.unscheduledMinutes,
    int? noContextAvailableMinutes,
    int? noContextUnscheduledMinutes,
    required List<TrajectoryTaskNode> tasks,
    required List<TrajectoryGoalNode> goals,
    required List<TrajectoryBlockNode> blocks,
    required List<TrajectoryTimelineSignal> timelineSignals,
    required this.progression,
    required this.confidence,
    required Map<String, String> sourceRevisions,
    Set<String> boundaryTaskIds = const <String>{},
    Set<String> protectedCommitmentTaskIds = const <String>{},
    List<String> personContextWarnings = const <String>[],
    Map<String, Object?> personContextTrace = const <String, Object?>{},
    this.energyOrigin = PredictiveEvidenceOrigin.observed,
    this.availabilityOrigin = PredictiveEvidenceOrigin.observed,
  }) : noContextAvailableMinutes =
           noContextAvailableMinutes ?? availableMinutes,
       noContextUnscheduledMinutes =
           noContextUnscheduledMinutes ?? unscheduledMinutes,
       tasks = List<TrajectoryTaskNode>.unmodifiable(tasks),
       goals = List<TrajectoryGoalNode>.unmodifiable(goals),
       blocks = List<TrajectoryBlockNode>.unmodifiable(blocks),
       timelineSignals = List<TrajectoryTimelineSignal>.unmodifiable(
         timelineSignals,
       ),
       boundaryTaskIds = Set<String>.unmodifiable(boundaryTaskIds),
       protectedCommitmentTaskIds = Set<String>.unmodifiable(
         protectedCommitmentTaskIds,
       ),
       personContextWarnings = List<String>.unmodifiable(personContextWarnings),
       personContextTrace = Map<String, Object?>.unmodifiable(
         personContextTrace,
       ),
       sourceRevisions = Map<String, String>.unmodifiable(sourceRevisions);

  final String accountScope;
  final String revision;
  final DateTime observedAt;
  final Duration evidenceWindow;
  final int momentum;
  final int pressure;
  final int energy;
  final int completedInWindow;
  final int deferredInWindow;
  final int observationCount;
  final int availableMinutes;
  final int occupiedMinutes;
  final int unscheduledMinutes;
  final int noContextAvailableMinutes;
  final int noContextUnscheduledMinutes;
  final List<TrajectoryTaskNode> tasks;
  final List<TrajectoryGoalNode> goals;
  final List<TrajectoryBlockNode> blocks;
  final List<TrajectoryTimelineSignal> timelineSignals;
  final TrajectoryProgressionSnapshot progression;
  final PredictiveConfidenceProfile confidence;
  final Map<String, String> sourceRevisions;
  final Set<String> boundaryTaskIds;
  final Set<String> protectedCommitmentTaskIds;
  final List<String> personContextWarnings;
  final Map<String, Object?> personContextTrace;
  final PredictiveEvidenceOrigin energyOrigin;
  final PredictiveEvidenceOrigin availabilityOrigin;

  bool get hasObservedEnergy =>
      energyOrigin == PredictiveEvidenceOrigin.observed;
  bool get hasObservedAvailability =>
      availabilityOrigin == PredictiveEvidenceOrigin.observed;

  int get requiredMinutes => tasks.fold<int>(
    0,
    (int total, TrajectoryTaskNode task) => total + task.estimatedMinutes,
  );

  int get overdueCount => timelineSignals
      .where((TrajectoryTimelineSignal item) => item.isOverdue)
      .length;

  int get atRiskCount => timelineSignals
      .where((TrajectoryTimelineSignal item) => item.isAtRisk)
      .length;
}

class TrajectoryIntervention {
  TrajectoryIntervention({
    required this.id,
    required this.type,
    required this.title,
    required this.horizon,
    required this.description,
    this.subjectId,
    this.delay = Duration.zero,
    List<TrajectoryBlockNode> proposedBlocks = const <TrajectoryBlockNode>[],
    List<String> displacedSubjectIds = const <String>[],
    List<String> assumptions = const <String>[],
  }) : proposedBlocks = List<TrajectoryBlockNode>.unmodifiable(proposedBlocks),
       displacedSubjectIds = List<String>.unmodifiable(displacedSubjectIds),
       assumptions = List<String>.unmodifiable(assumptions);

  final String id;
  final TrajectoryInterventionType type;
  final String title;
  final Duration horizon;
  final String description;
  final String? subjectId;
  final Duration delay;
  final List<TrajectoryBlockNode> proposedBlocks;
  final List<String> displacedSubjectIds;
  final List<String> assumptions;
}

class TrajectoryRiskContribution {
  const TrajectoryRiskContribution({
    required this.code,
    required this.label,
    required this.currentScore,
    required this.projectedScore,
    required this.explanation,
  });

  final String code;
  final String label;
  final int currentScore;
  final int projectedScore;
  final String explanation;
}

class TrajectoryRiskProjection {
  TrajectoryRiskProjection({
    required this.currentScore,
    required this.projectedScore,
    required this.band,
    required List<TrajectoryRiskContribution> contributions,
  }) : contributions = List<TrajectoryRiskContribution>.unmodifiable(
         contributions,
       );

  final int currentScore;
  final int projectedScore;
  final TrajectoryRiskBand band;
  final List<TrajectoryRiskContribution> contributions;
}

class GoalDelayProjection {
  const GoalDelayProjection({
    required this.goalId,
    required this.goalTitle,
    required this.projectedCompletion,
    required this.lowerCompletion,
    required this.upperCompletion,
    required this.delayDays,
    required this.remainingMinutes,
    required this.confidence,
    required this.explanation,
    this.targetDate,
  });

  final String goalId;
  final String goalTitle;
  final DateTime? targetDate;
  final DateTime projectedCompletion;
  final DateTime lowerCompletion;
  final DateTime upperCompletion;
  final int delayDays;
  final int remainingMinutes;
  final PredictiveConfidenceProfile confidence;
  final String explanation;
}

class TimelineConsequence {
  TimelineConsequence({
    required List<String> affectedBlockIds,
    required List<String> displacedSubjectIds,
    required this.deadlineCrossings,
    required this.minutesAdded,
    required this.summary,
  }) : affectedBlockIds = List<String>.unmodifiable(affectedBlockIds),
       displacedSubjectIds = List<String>.unmodifiable(displacedSubjectIds);

  final List<String> affectedBlockIds;
  final List<String> displacedSubjectIds;
  final int deadlineCrossings;
  final int minutesAdded;
  final String summary;
}

class ProgressionConsequence {
  const ProgressionConsequence({
    required this.potentialXp,
    required this.streakProtected,
    required this.summary,
  });

  /// Informational projection only. This value is never awarded by simulation.
  final int potentialXp;
  final bool streakProtected;
  final String summary;
}

class TrajectoryScenarioOutcome {
  TrajectoryScenarioOutcome({
    required this.id,
    required this.baselineRevision,
    required this.intervention,
    required this.generatedAt,
    required this.projectedMomentum,
    required this.projectedPressure,
    required this.uncertainty,
    required this.confidence,
    required this.risk,
    required this.timeline,
    required List<GoalDelayProjection> goals,
    required this.progression,
    required List<String> evidence,
    required List<String> assumptions,
    required this.explanation,
    required this.utilityScore,
    this.modelVersion = 'trajectory-consequence-v3',
  }) : goals = List<GoalDelayProjection>.unmodifiable(goals),
       evidence = List<String>.unmodifiable(evidence),
       assumptions = List<String>.unmodifiable(assumptions);

  final String id;
  final String baselineRevision;
  final TrajectoryIntervention intervention;
  final DateTime generatedAt;
  final int projectedMomentum;
  final int projectedPressure;
  final int uncertainty;
  final PredictiveConfidenceProfile confidence;
  final TrajectoryRiskProjection risk;
  final TimelineConsequence timeline;
  final List<GoalDelayProjection> goals;
  final ProgressionConsequence progression;
  final List<String> evidence;
  final List<String> assumptions;
  final String explanation;
  final double utilityScore;
  final String modelVersion;
}

class TrajectoryComparison {
  TrajectoryComparison({
    required this.baseline,
    required List<TrajectoryScenarioOutcome> outcomes,
    required this.recommendedScenarioId,
  }) : outcomes = List<TrajectoryScenarioOutcome>.unmodifiable(outcomes);

  final TrajectoryBaseline baseline;
  final List<TrajectoryScenarioOutcome> outcomes;
  final String recommendedScenarioId;

  TrajectoryScenarioOutcome? get recommended {
    for (final TrajectoryScenarioOutcome outcome in outcomes) {
      if (outcome.id == recommendedScenarioId) return outcome;
    }
    return null;
  }
}
