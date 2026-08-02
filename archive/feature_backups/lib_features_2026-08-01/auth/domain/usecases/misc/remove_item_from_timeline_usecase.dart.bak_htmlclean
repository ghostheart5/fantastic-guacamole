import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/remove_timeline_event.dart';

class RemoveItemFromTimelineUsecase {
  const RemoveItemFromTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<void> call(String id) {
    return RemoveTimelineEvent(_repository).call(id);
  }
}
