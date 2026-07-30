import 'package:fantastic_guacamole/tutorial/mission/mission_repository.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_state.dart';

class MissionController {
  MissionController({required this.repository});

  final MissionRepository repository;

  Future<MissionState> load() {
    return repository.load();
  }

  Future<MissionState> reportGoalCreated(MissionState current) {
    return _completeIfActive(current, MissionId.createFirstGoal);
  }

  Future<MissionState> reportCreatorOpened(MissionState current) {
    return _completeIfActive(current, MissionId.configureFirstItem);
  }

  Future<MissionState> reportSmartPlannerQuestionAsked(MissionState current) {
    return _completeIfActive(current, MissionId.askSmartPlannerQuestion);
  }

  Future<MissionState> reportTimelineOpened(MissionState current) {
    return _completeIfActive(current, MissionId.openTimeline);
  }

  Future<MissionState> dismissCompletionBanner(MissionState current) async {
    final MissionState next = current.dismissCompletionBanner();
    if (identical(next, current)) {
      return current;
    }
    await repository.save(next);
    return next;
  }

  Future<MissionState> reset() async {
    await repository.reset();
    final MissionState initial = MissionState.initial();
    await repository.save(initial);
    return initial;
  }

  Future<MissionState> _completeIfActive(
    MissionState current,
    MissionId missionId,
  ) async {
    final MissionState next = current.completeAndAdvance(missionId);
    if (identical(next, current)) {
      return current;
    }
    await repository.save(next);
    return next;
  }
}
