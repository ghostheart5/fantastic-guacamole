import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class DeleteMilestoneUsecase {
  const DeleteMilestoneUsecase(this._timelineRepository);

  final ITimelineRepository _timelineRepository;

  Future<void> call(String milestoneId) {
    return _timelineRepository.removeEvent(milestoneId.trim());
  }
}
