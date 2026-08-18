import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';

enum PredictiveEvidenceOrigin {
  observed,
  estimated,
  inferred,
  legacy,
  unavailable,
}

enum PredictiveConfidenceBand { high, moderate, low, insufficientEvidence }

enum PredictiveCalibrationState {
  unavailable,
  provisional,
  monitored,
  calibrated,
}

enum DeadlinePressureBand { none, watch, elevated, critical, overdue }

class PredictiveConfidenceProfile {
  const PredictiveConfidenceProfile({
    required this.sourceCompleteness,
    required this.freshness,
    required this.sampleSufficiency,
    required this.intervalPrecision,
    this.calibration = PredictiveCalibrationState.provisional,
  });

  final double sourceCompleteness;
  final double freshness;
  final double sampleSufficiency;
  final double intervalPrecision;
  final PredictiveCalibrationState calibration;

  double get recommendationConfidence =>
      ((sourceCompleteness.clamp(0.0, 1.0) * .20) +
              (freshness.clamp(0.0, 1.0) * .20) +
              (sampleSufficiency.clamp(0.0, 1.0) * .35) +
              (intervalPrecision.clamp(0.0, 1.0) * .25))
          .clamp(0.0, 1.0)
          .toDouble();

  PredictiveConfidenceBand get band {
    if (sourceCompleteness <= 0 || freshness <= 0) {
      return PredictiveConfidenceBand.insufficientEvidence;
    }
    final double value = recommendationConfidence;
    if (value >= .75 && calibration != PredictiveCalibrationState.unavailable) {
      return PredictiveConfidenceBand.high;
    }
    if (value >= .52) return PredictiveConfidenceBand.moderate;
    if (value >= .28) return PredictiveConfidenceBand.low;
    return PredictiveConfidenceBand.insufficientEvidence;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceCompleteness': sourceCompleteness,
    'freshness': freshness,
    'sampleSufficiency': sampleSufficiency,
    'intervalPrecision': intervalPrecision,
    'recommendationConfidence': recommendationConfidence,
    'band': band.name,
    'calibration': calibration.name,
  };
}

class ProbabilityForecast {
  const ProbabilityForecast({
    required this.pointEstimate,
    required this.lowerBound,
    required this.upperBound,
    required this.confidence,
    required this.sampleSize,
    required this.modelVersion,
    required this.evidenceWindow,
    this.assumptions = const <String>[],
  });

  final double pointEstimate;
  final double lowerBound;
  final double upperBound;
  final PredictiveConfidenceProfile confidence;
  final int sampleSize;
  final String modelVersion;
  final Duration evidenceWindow;
  final List<String> assumptions;

  double get safePoint => pointEstimate.clamp(0.0, 1.0).toDouble();
  double get safeLower => lowerBound.clamp(0.0, safePoint).toDouble();
  double get safeUpper => upperBound.clamp(safePoint, 1.0).toDouble();
  bool get hasDecisionGradeEvidence =>
      sampleSize >= 5 &&
      confidence.band != PredictiveConfidenceBand.low &&
      confidence.band != PredictiveConfidenceBand.insufficientEvidence;
}

class DeadlinePressureAssessment {
  const DeadlinePressureAssessment({
    required this.taskId,
    required this.band,
    required this.score,
    required this.slack,
    required this.explanation,
    required this.origin,
  });

  final String taskId;
  final DeadlinePressureBand band;
  final double score;
  final Duration? slack;
  final String explanation;
  final PredictiveEvidenceOrigin origin;
}

class PlanningCapacityAssessment {
  const PlanningCapacityAssessment({
    required this.availableMinutes,
    required this.occupiedMinutes,
    required this.requiredMinutes,
    required this.unscheduledMinutes,
    required this.overloadRatio,
    required this.windowOrigin,
    required this.blockOrigin,
    required this.assumptions,
  });

  final int availableMinutes;
  final int occupiedMinutes;
  final int requiredMinutes;
  final int unscheduledMinutes;
  final double overloadRatio;
  final PredictiveEvidenceOrigin windowOrigin;
  final PredictiveEvidenceOrigin blockOrigin;
  final List<String> assumptions;

  bool get isOverloaded => unscheduledMinutes > 0 || overloadRatio > 1.0;
  int get freeMinutes => (availableMinutes - occupiedMinutes).clamp(0, 1 << 30);

  static PlanningCapacityAssessment calculate({
    required List<WorkWindowEntity> windows,
    required List<TimeBlock> existingBlocks,
    required Iterable<Duration> requiredDurations,
    required Iterable<Duration> unscheduledDurations,
    required PredictiveEvidenceOrigin windowOrigin,
    required PredictiveEvidenceOrigin blockOrigin,
    List<String> assumptions = const <String>[],
  }) {
    final int available = windows
        .where((WorkWindowEntity item) => item.isValidRange)
        .fold<int>(
          0,
          (int total, WorkWindowEntity item) => total + item.duration.inMinutes,
        );
    final int occupied = _occupiedMinutesWithinWindows(windows, existingBlocks);
    final int required = requiredDurations.fold<int>(
      0,
      (int total, Duration item) => total + item.inMinutes,
    );
    final int unscheduled = unscheduledDurations.fold<int>(
      0,
      (int total, Duration item) => total + item.inMinutes,
    );
    final int usable = (available - occupied).clamp(0, 1 << 30);
    return PlanningCapacityAssessment(
      availableMinutes: available,
      occupiedMinutes: occupied,
      requiredMinutes: required,
      unscheduledMinutes: unscheduled,
      overloadRatio: usable == 0
          ? (required == 0 ? 0 : double.infinity)
          : required / usable,
      windowOrigin: windowOrigin,
      blockOrigin: blockOrigin,
      assumptions: List<String>.unmodifiable(assumptions),
    );
  }
}

int _occupiedMinutesWithinWindows(
  List<WorkWindowEntity> windows,
  List<TimeBlock> blocks,
) {
  final List<({DateTime start, DateTime end})> intersections =
      <({DateTime start, DateTime end})>[];
  for (final WorkWindowEntity window in windows.where(
    (WorkWindowEntity item) => item.isValidRange,
  )) {
    for (final TimeBlock block in blocks.where(
      (TimeBlock item) => !item.completed && item.end.isAfter(item.start),
    )) {
      final DateTime start = block.start.isAfter(window.start)
          ? block.start
          : window.start;
      final DateTime end = block.end.isBefore(window.end)
          ? block.end
          : window.end;
      if (end.isAfter(start)) intersections.add((start: start, end: end));
    }
  }
  intersections.sort((a, b) => a.start.compareTo(b.start));
  if (intersections.isEmpty) return 0;
  int minutes = 0;
  DateTime cursorStart = intersections.first.start;
  DateTime cursorEnd = intersections.first.end;
  for (final interval in intersections.skip(1)) {
    if (!interval.start.isAfter(cursorEnd)) {
      if (interval.end.isAfter(cursorEnd)) cursorEnd = interval.end;
      continue;
    }
    minutes += cursorEnd.difference(cursorStart).inMinutes;
    cursorStart = interval.start;
    cursorEnd = interval.end;
  }
  return minutes + cursorEnd.difference(cursorStart).inMinutes;
}

class TaskScoreBreakdown {
  const TaskScoreBreakdown({
    required this.taskId,
    required this.priority,
    required this.deadlinePressure,
    required this.energyFit,
    required this.fatigueAdjustment,
    required this.difficultyAdjustment,
    required this.learningAffinity,
    required this.total,
    required this.reasons,
  });

  final String taskId;
  final double priority;
  final DeadlinePressureAssessment deadlinePressure;
  final double energyFit;
  final double fatigueAdjustment;
  final double difficultyAdjustment;
  final double learningAffinity;
  final double total;
  final List<String> reasons;
}

enum RecoveryTrigger {
  missedCommitment,
  deadlineAtRisk,
  capacityExceeded,
  repeatedDeferral,
  lowEnergy,
}

class RecoveryRecommendation {
  const RecoveryRecommendation({
    required this.trigger,
    required this.subjectId,
    required this.immediateAction,
    required this.why,
    required this.consequence,
    required this.confidence,
    this.proposedStart,
    this.displacedSubjectIds = const <String>[],
  });

  final RecoveryTrigger trigger;
  final String? subjectId;
  final String immediateAction;
  final String why;
  final String consequence;
  final PredictiveConfidenceProfile confidence;
  final DateTime? proposedStart;
  final List<String> displacedSubjectIds;
}
