import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineOnTrackResult {
  const TimelineOnTrackResult({
    required this.isOnTrack,
    required this.healthScore,
    required this.overdueCount,
    required this.riskCount,
    required this.upcomingCount,
  });

  final bool isOnTrack;
  final int healthScore;
  final int overdueCount;
  final int riskCount;
  final int upcomingCount;
}

class ShowTimelineOnTrackUsecase {
  const ShowTimelineOnTrackUsecase(this._repository);

  final ITimelineRepository _repository;

  TimelineOnTrackResult call() {
    final List<TimelineEventEntity> events = _repository.getEvents();

    final int overdue = events
        .where((TimelineEventEntity event) => event.isOverdue)
        .length;
    final int risks = events
        .where((TimelineEventEntity event) => event.isRisk)
        .length;
    final int upcoming = events
        .where((TimelineEventEntity event) => event.isUpcoming)
        .length;
    final int milestones = events
        .where((TimelineEventEntity event) => event.isMilestone)
        .length;

    final int penalty = (overdue * 12) + (risks * 10) + (upcoming > 8 ? 8 : 0);
    final int bonus = (milestones * 3).clamp(0, 18);
    final int healthScore = (100 - penalty + bonus).clamp(0, 100);

    return TimelineOnTrackResult(
      isOnTrack: healthScore >= 70,
      healthScore: healthScore,
      overdueCount: overdue,
      riskCount: risks,
      upcomingCount: upcoming,
    );
  }
}
