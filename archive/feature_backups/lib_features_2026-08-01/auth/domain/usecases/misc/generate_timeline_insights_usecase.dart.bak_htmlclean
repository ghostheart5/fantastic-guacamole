import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class GenerateTimelineInsightsUsecase {
  const GenerateTimelineInsightsUsecase(this._repository);

  final ITimelineRepository _repository;

  List<String> call() {
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

    final List<String> insights = <String>[];

    if (events.isEmpty) {
      insights.add('Timeline has no recorded events yet.');
    }
    if (overdue > 0) {
      insights.add('$overdue timeline item(s) are overdue.');
    }
    if (risks > 0) {
      insights.add('$risks timeline risk signal(s) need attention.');
    }
    if (upcoming > 0) {
      insights.add('$upcoming item(s) are due soon.');
    }
    if (milestones > 0) {
      insights.add('$milestones milestone event(s) show progress.');
    }
    if (insights.isEmpty) {
      insights.add('Timeline is stable and on track.');
    }

    return insights;
  }
}
