import 'package:fantastic_guacamole/data/models/time_block.dart';

class TimelineRepository {
  TimelineRepository();

  Future<List<TimeBlock>> getBlocksForDay(DateTime day) async => [];

  Future<void> saveBlock(TimeBlock block) async {}

  Future<void> deleteBlock(String id) async {}
}
