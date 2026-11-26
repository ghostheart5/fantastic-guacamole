// CHRONOSPARK-CLASS: SHIPPING | Feature: Trajectory forecasting
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart'
    show HabitCadence;
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';

/// Written into every new forecast receipt. v4: the time range sets which
/// tasks count, and workload is measured against free time.
const String trajectoryConsequenceModelVersion = 'trajectory-consequence-v4';

/// Stated on every outcome that shows goal dates.
const String trajectoryGoalDateAssumption =
    'Goal dates assume your daily free time goes to the goal\'s remaining tasks; other work can push them later.';

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
    this.dueDay,
    this.scheduledAt,
  });

  final String id;
  final String title;
  final int priority;
  final int estimatedMinutes;
  final String? goalId;
  final DateTime? dueAt;

  /// The calendar day of a whole-day deadline (only year, month and day
  /// count); null when the deadline has a time or there is none. A whole-day
  /// deadline owns that entire local day.
  final DateTime? dueDay;
  final DateTime? scheduledAt;
}

/// How many tasks a time range is expected to see finished (or, on a habit
/// line, how many check-ins): a central estimate with a low and high end.
class TrajectoryExpectedCompletions {
  const TrajectoryExpectedCompletions({
    required this.low,
    required this.mid,
    required this.high,
  });

  static const TrajectoryExpectedCompletions none =
      TrajectoryExpectedCompletions(low: 0, mid: 0, high: 0);

  final int low;
  final int mid;
  final int high;
}

/// The work that falls inside one time range: active tasks due or scheduled
/// within it, overdue tasks and undated tasks (which count in every range).
class TrajectoryHorizonWorkload {
  TrajectoryHorizonWorkload({
    required this.horizonDays,
    required Set<String> taskIds,
    required this.requiredMinutes,
    required this.expectedCompletions,
    required this.undatedTasks,
  }) : taskIds = Set<String>.unmodifiable(taskIds);

  final int horizonDays;
  final Set<String> taskIds;
  final int requiredMinutes;
  final TrajectoryExpectedCompletions expectedCompletions;
  final int undatedTasks;

  int get taskCount => taskIds.length;
}

/// Whether a habit has enough closed periods for a projected line.
enum TrajectoryHabitEvidence { enough, notEnoughHistory }

/// One active habit's own projected line over the chosen range. Habits are
/// listed beside the forecast and never move workload, momentum, risk, the
/// ranking or the recommendation; they are not written into receipts.
class TrajectoryHabitNode {
  const TrajectoryHabitNode({
    required this.habitId,
    required this.title,
    required this.cadence,
    required this.closedPeriodsJudged,
    required this.completedPeriods,
    required this.rate,
    required this.expectedPeriods,
    required this.projectedCheckIns,
    required this.checkedInThisPeriod,
    required this.evidence,
    this.historyNeeded = 3,
  });

  final String habitId;
  final String title;
  final HabitCadence cadence;

  /// Closed periods looked at (under the current frequency revision).
  final int closedPeriodsJudged;

  /// Of those, the periods with a check-in.
  final int completedPeriods;

  /// completedPeriods / closedPeriodsJudged; null without enough history.
  final double? rate;

  /// The habit's periods in the chosen range.
  final int expectedPeriods;

  /// Check-ins expected in the range at the recorded rate (an estimate);
  /// null without enough history.
  final TrajectoryExpectedCompletions? projectedCheckIns;

  /// The current, still open, period already has a check-in.
  final bool checkedInThisPeriod;
  final TrajectoryHabitEvidence evidence;

  /// Closed periods needed before a line is projected.
  final int historyNeeded;
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
    this.horizonDays = 7,
    int? dailyFreeMinutes,
    PredictiveEvidenceOrigin? dailyFreeOrigin,
    int? tasksInHorizon,
    int? requiredMinutesInHorizon,
    this.expectedCompletionsInHorizon = TrajectoryExpectedCompletions.none,
    List<String> assumptions = const <String>[],
    int? pressureInHorizon,
    List<TrajectoryHabitNode> habits = const <TrajectoryHabitNode>[],
  }) : pressureInHorizon = pressureInHorizon ?? pressure,
       habits = List<TrajectoryHabitNode>.unmodifiable(habits),
       dailyFreeMinutes =
           dailyFreeMinutes ??
           (availableMinutes - occupiedMinutes).clamp(0, 1 << 30),
       dailyFreeOrigin = dailyFreeOrigin ?? availabilityOrigin,
       tasksInHorizon = tasksInHorizon ?? tasks.length,
       requiredMinutesInHorizon =
           requiredMinutesInHorizon ??
           tasks.fold<int>(
             0,
             (int total, TrajectoryTaskNode task) =>
                 total + task.estimatedMinutes,
           ),
       assumptions = List<String>.unmodifiable(assumptions),
       noContextAvailableMinutes =
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

  /// The chosen time range (7, 30 or 90 days) this baseline was built for.
  final int horizonDays;

  /// Workload over the chosen range: the share of the range's free time the
  /// work in it needs. Options are compared against this value; [pressure]
  /// stays the next-7-days value (Home reads it).
  final int pressureInHorizon;

  /// Free minutes in a day: one day's working window (the live provider does
  /// not subtract time held by tasks that are themselves counted as work).
  /// When [dailyFreeOrigin] is not observed it comes from the planner's
  /// assumed workday and [assumptions] say so.
  final int dailyFreeMinutes;
  final PredictiveEvidenceOrigin dailyFreeOrigin;

  /// Active tasks inside the chosen range (due or scheduled within it,
  /// overdue, or undated) and the minutes they need.
  final int tasksInHorizon;
  final int requiredMinutesInHorizon;

  /// Finished tasks expected in the chosen range at the last 7 days' pace.
  final TrajectoryExpectedCompletions expectedCompletionsInHorizon;

  /// What this baseline assumed (for example an assumed workday, or undated
  /// tasks counted in every range).
  final List<String> assumptions;

  /// One projected line per active habit, for the chosen range. Listed only:
  /// no other baseline or outcome figure reads them.
  final List<TrajectoryHabitNode> habits;

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
    this.isScored = true,
  });

  final String code;
  final String label;
  final int currentScore;
  final int projectedScore;
  final String explanation;
  final bool isScored;
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
    this.modelVersion = trajectoryConsequenceModelVersion,
    this.calibrationMultiplier = 1.0,
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

  /// The multiplier recorded forecast accuracy applied to [uncertainty]
  /// (1.0 when none was applied).
  final double calibrationMultiplier;
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
