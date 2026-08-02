import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';

class AddMilestoneToTimelineUsecase {
  const AddMilestoneToTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<void> call({
    required String title,
    required String detail,
    String? relatedId,
    DateTime? timestamp,
  }) {
    final DateTime now = timestamp ?? DateTime.now();

    return AddTimelineEvent(_repository).call(
      TimelineEventEntity(
        id: 'milestone_${now.microsecondsSinceEpoch}',
        type: TimelineEventType.milestone,
        title: title.trim().isEmpty ? 'Milestone reached' : title.trim(),
        detail: detail.trim().isEmpty
            ? 'Milestone added to timeline.'
            : detail.trim(),
        timestamp: now,
        status: TimelineEventStatus.completed,
        relatedId: relatedId,
      ),
    );
  }
}
