import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';

class AddEmotionToTimelineUsecase {
  const AddEmotionToTimelineUsecase(this._repository);

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
        id: 'emotion_${now.microsecondsSinceEpoch}',
        type: TimelineEventType.reflection,
        title: title.trim().isEmpty ? 'Emotional reflection' : title.trim(),
        detail: detail.trim().isEmpty ? 'Emotion recorded.' : detail.trim(),
        timestamp: now,
        status: TimelineEventStatus.info,
        relatedId: relatedId,
      ),
    );
  }
}
