import '../../entities/mission.dart';

class AddTaskToMissionUseCase {
  Mission call(Mission mission) {
    return Mission(
      id: mission.id,
      name: mission.name,
      taskCount: mission.taskCount + 1,
    );
  }
}
