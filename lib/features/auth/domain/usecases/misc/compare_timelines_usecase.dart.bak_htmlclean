import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';

class TimelineComparisonResult {
  const TimelineComparisonResult({
    required this.leftCount,
    required this.rightCount,
    required this.leftMilestones,
    required this.rightMilestones,
    required this.leftRisks,
    required this.rightRisks,
    required this.countDelta,
    required this.milestoneDelta,
    required this.riskDelta,
  });

  final int leftCount;
  final int rightCount;
  final int leftMilestones;
  final int rightMilestones;
  final int leftRisks;
  final int rightRisks;
  final int countDelta;
  final int milestoneDelta;
  final int riskDelta;
}

class CompareTimelinesUsecase {
  const CompareTimelinesUsecase();

  TimelineComparisonResult call({
    required List<TimelineEventEntity> left,
    required List<TimelineEventEntity> right,
  }) {
    final int leftMilestones = left
        .where((TimelineEventEntity event) => event.isMilestone)
        .length;
    final int rightMilestones = right
        .where((TimelineEventEntity event) => event.isMilestone)
        .length;
    final int leftRisks = left
        .where((TimelineEventEntity event) => event.isRisk)
        .length;
    final int rightRisks = right
        .where((TimelineEventEntity event) => event.isRisk)
        .length;

    return TimelineComparisonResult(
      leftCount: left.length,
      rightCount: right.length,
      leftMilestones: leftMilestones,
      rightMilestones: rightMilestones,
      leftRisks: leftRisks,
      rightRisks: rightRisks,
      countDelta: left.length - right.length,
      milestoneDelta: leftMilestones - rightMilestones,
      riskDelta: leftRisks - rightRisks,
    );
  }
}
