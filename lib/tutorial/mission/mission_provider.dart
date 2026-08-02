import 'package:fantastic_guacamole/tutorial/mission/mission_controller.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_repository.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final missionProgressionEnabledProvider = Provider<bool>((Ref ref) {
  return true;
});

// Backward-compatible alias while mission ownership naming is rolled out.
final missionTutorialEnabledProvider = Provider<bool>((Ref ref) {
  return ref.watch(missionProgressionEnabledProvider);
});

final missionRepositoryProvider = Provider<MissionRepository>((Ref ref) {
  return const MissionRepository();
});

final missionControllerProvider = Provider<MissionController>((Ref ref) {
  return MissionController(repository: ref.read(missionRepositoryProvider));
});

final missionStateProvider =
    AsyncNotifierProvider<MissionStateNotifier, MissionState>(
      MissionStateNotifier.new,
    );

class MissionStateNotifier extends AsyncNotifier<MissionState> {
  MissionController get _controller => ref.read(missionControllerProvider);

  @override
  Future<MissionState> build() async {
    return _controller.load();
  }

  Future<void> reportGoalCreated() async {
    await _mutate(_controller.reportGoalCreated);
  }

  Future<void> reportFirstItemCreated() async {
    await _mutate(_controller.reportFirstItemCreated);
  }

  Future<void> reportCreatorOpened() async {
    await _mutate(_controller.reportCreatorOpened);
  }

  Future<void> reportSmartPlannerQuestionAsked() async {
    await _mutate(_controller.reportSmartPlannerQuestionAsked);
  }

  Future<void> reportSmartCoachQuestionAsked() async {
    await reportSmartPlannerQuestionAsked();
  }

  Future<void> reportTimelineOpened() async {
    await _mutate(_controller.reportTimelineOpened);
  }

  Future<void> dismissCompletionBanner() async {
    await _mutate(_controller.dismissCompletionBanner);
  }

  Future<void> reset() async {
    state = const AsyncLoading<MissionState>();
    state = AsyncData(await _controller.reset());
  }

  Future<void> _mutate(
    Future<MissionState> Function(MissionState current) action,
  ) async {
    final MissionState current = state.asData?.value ?? await future;
    final MissionState updated = await action(current);
    state = AsyncData(updated);
  }
}
