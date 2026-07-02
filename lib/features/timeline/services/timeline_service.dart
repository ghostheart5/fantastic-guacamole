import 'package:fantastic_guacamole/data/models/time_block.dart';
import 'package:fantastic_guacamole/features/timeline/repositories/timeline_repository.dart';

class TimelineService {
  TimelineService(this._repository);

  final TimelineRepository _repository;

  Future<List<TimeBlock>> getBlocksForDay(DateTime day) =>
      _repository.getBlocksForDay(day);

  Future<void> saveBlock(TimeBlock block) => _repository.saveBlock(block);

  Future<void> deleteBlock(String id) => _repository.deleteBlock(id);
}
