import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class RemoveTimelineEvent {
  const RemoveTimelineEvent(this._repository);

  final ITimelineRepository _repository;

  Future<void> call(String id) => _repository.removeEvent(id);
}
