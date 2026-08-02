import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineRiskResult {
  const TimelineRiskResult({
    required this.riskEvents,
    required this.overdueEvents,
    required this.riskScore,
  });

  final List<TimelineEventEntity> riskEvents;
  final List<TimelineEventEntity> overdueEvents;
  final int riskScore;

  bool get hasRisk => riskScore > 0;
}

class DetectTimelineRiskUsecase {
  const DetectTimelineRiskUsecase(this._repository);

  final ITimelineRepository _repository;

  TimelineRiskResult call() {
    final List<TimelineEventEntity> events = _repository.getEvents();

    final List<TimelineEventEntity> riskEvents = events
        .where((TimelineEventEntity event) => event.isRisk)
        .toList(growable: false);

    final List<TimelineEventEntity> overdueEvents = events
        .where((TimelineEventEntity event) => event.isOverdue)
        .toList(growable: false);

    final int score = ((riskEvents.length * 10) + (overdueEvents.length * 12))
        .clamp(0, 100);

    return TimelineRiskResult(
      riskEvents: riskEvents,
      overdueEvents: overdueEvents,
      riskScore: score,
    );
  }
}
