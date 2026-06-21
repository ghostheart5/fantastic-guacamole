import '../../entities/mission.dart';

class CreateMissionUseCase {
  Mission call({required String id, required String name}) {
    return Mission(id: id, name: name.trim(), taskCount: 0);
  }
}
