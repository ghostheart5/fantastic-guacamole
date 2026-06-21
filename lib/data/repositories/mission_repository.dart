import '../models/mission_model.dart';

abstract class MissionRepository {
  Future<List<MissionModel>> loadMissions();
  Future<void> saveMissions(List<MissionModel> missions);
  Future<void> addCompletedTaskLog(String line);
}
