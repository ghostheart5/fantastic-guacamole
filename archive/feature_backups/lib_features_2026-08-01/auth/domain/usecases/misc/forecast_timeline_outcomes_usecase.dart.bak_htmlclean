import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineForecastResult {
  const TimelineForecastResult({
    required this.title,
    required this.detail,
    required this.confidence,
  });

  final String title;
  final String detail;
  final double confidence;
}

class ForecastTimelineOutcomesUsecase {
  const ForecastTimelineOutcomesUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineForecastResult> call() {
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

    final List<TimelineForecastResult> results = <TimelineForecastResult>[];

    if (overdue > 0 || risks > 0) {
      results.add(
        const TimelineForecastResult(
          title: 'Timeline pressure rising',
          detail: 'Overdue and risk items may reduce completion momentum.',
          confidence: 0.82,
        ),
      );
    }

    if (upcoming > 5) {
      results.add(
        const TimelineForecastResult(
          title: 'Upcoming load is high',
          detail:
              'Several timeline items are due soon and may need prioritization.',
          confidence: 0.76,
        ),
      );
    }

    if (milestones > 0 && overdue == 0) {
      results.add(
        const TimelineForecastResult(
          title: 'Progress trend is healthy',
          detail:
              'Recent milestones suggest the user is making steady progress.',
          confidence: 0.74,
        ),
      );
    }

    if (results.isEmpty) {
      results.add(
        const TimelineForecastResult(
          title: 'Timeline is stable',
          detail: 'No major timeline risks were detected.',
          confidence: 0.7,
        ),
      );
    }

    return results;
  }
}
