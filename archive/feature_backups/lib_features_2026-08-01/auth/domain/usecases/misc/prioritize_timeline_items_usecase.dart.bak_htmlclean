import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class PrioritizeTimelineItemsUsecase {
  const PrioritizeTimelineItemsUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call({int limit = 10}) {
    final List<TimelineEventEntity> events = <TimelineEventEntity>[
      ..._repository.getEvents(),
    ];

    int score(TimelineEventEntity event) {
      int value = 0;

      if (event.isOverdue) {
        value += 50;
      }
      if (event.isRisk) {
        value += 35;
      }
      if (event.isUpcoming) {
        value += 25;
      }
      if (event.isDeadline) {
        value += 20;
      }
      if (event.isRecommendation) {
        value += 10;
      }

      final DateTime? dueAt = event.dueAt;
      if (dueAt != null) {
        final int hours = dueAt.difference(DateTime.now()).inHours;
        if (hours >= 0 && hours <= 24) {
          value += 20;
        }
      }

      return value;
    }

    events.sort(
      (TimelineEventEntity a, TimelineEventEntity b) =>
          score(b).compareTo(score(a)),
    );

    if (events.length <= limit) {
      return events;
    }

    return events.sublist(0, limit);
  }
}
