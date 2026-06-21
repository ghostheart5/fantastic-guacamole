import '../entities/mission.dart';

abstract class MissionRepository {
  Future<List<Mission>> getMissions();
}
