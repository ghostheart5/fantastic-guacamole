import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class DeleteSubgoalUsecase {
  const DeleteSubgoalUsecase(this._timelineRepository);

  final ITimelineRepository _timelineRepository;

  Future<void> call(String subgoalId) {
    return _timelineRepository.removeEvent(subgoalId.trim());
  }
}
