import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineSummaryResult {
  const TimelineSummaryResult({
    required this.total,
    required this.milestones,
    required this.risks,
    required this.overdue,
    required this.upcoming,
    required this.recommendations,
    required this.healthScore,
  });

  final int total;
  final int milestones;
  final int risks;
  final int overdue;
  final int upcoming;
  final int recommendations;
  final int healthScore;

  bool get isOnTrack => healthScore >= 70;
}

class GenerateTimelineSummaryUsecase {
  const GenerateTimelineSummaryUsecase(this._repository);

  final ITimelineRepository _repository;

  TimelineSummaryResult call() {
    final List<TimelineEventEntity> events = _repository.getEvents();
    final int milestones = events
        .where((TimelineEventEntity event) => event.isMilestone)
        .length;
    final int risks = events
        .where((TimelineEventEntity event) => event.isRisk)
        .length;
    final int overdue = events
        .where((TimelineEventEntity event) => event.isOverdue)
        .length;
    final int upcoming = events
        .where((TimelineEventEntity event) => event.isUpcoming)
        .length;
    final int recommendations = events
        .where((TimelineEventEntity event) => event.isRecommendation)
        .length;
    final int penalty = (overdue * 12) + (risks * 10) + (upcoming > 8 ? 8 : 0);
    final int bonus = (milestones * 3).clamp(0, 18);
    final int healthScore = (100 - penalty + bonus).clamp(0, 100);

    return TimelineSummaryResult(
      total: events.length,
      milestones: milestones,
      risks: risks,
      overdue: overdue,
      upcoming: upcoming,
      recommendations: recommendations,
      healthScore: healthScore,
    );
  }
}
