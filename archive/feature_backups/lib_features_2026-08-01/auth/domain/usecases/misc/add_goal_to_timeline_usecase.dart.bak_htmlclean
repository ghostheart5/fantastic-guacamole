import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';

class AddGoalToTimelineUsecase {
  const AddGoalToTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<void> call({
    required String title,
    required String detail,
    String? relatedId,
    DateTime? timestamp,
    DateTime? dueAt,
  }) {
    final DateTime now = timestamp ?? DateTime.now();

    return AddTimelineEvent(_repository).call(
      TimelineEventEntity(
        id: 'goal_${now.microsecondsSinceEpoch}',
        type: TimelineEventType.goal,
        title: title.trim().isEmpty ? 'Goal added' : title.trim(),
        detail: detail.trim().isEmpty
            ? 'Goal added to timeline.'
            : detail.trim(),
        timestamp: now,
        status: TimelineEventStatus.active,
        dueAt: dueAt,
        relatedId: relatedId,
      ),
    );
  }
}
