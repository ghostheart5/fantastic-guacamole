import '../models/mission_model.dart';
import '../services/chronologs_service.dart';
import '../services/mission_service.dart';
import 'mission_repository.dart';

class MissionRepositoryImpl implements MissionRepository {
  MissionRepositoryImpl({
    MissionService? missionService,
    ChronoLogsService? chronoLogsService,
  }) : _missionService = missionService ?? MissionService(),
       _chronoLogsService = chronoLogsService ?? ChronoLogsService();

  final MissionService _missionService;
  final ChronoLogsService _chronoLogsService;

  @override
  Future<void> addCompletedTaskLog(String line) {
    return _chronoLogsService.addCompletedTask(line);
  }

  @override
  Future<List<MissionModel>> loadMissions() {
    return _missionService.loadMissions();
  }

  @override
  Future<void> saveMissions(List<MissionModel> missions) {
    return _missionService.saveMissions(missions);
  }
}
