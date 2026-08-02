import 'package:fantastic_guacamole/tutorial/mission/mission_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MissionEventBridge {
  const MissionEventBridge(this._ref);

  final Ref _ref;

  void _logAction(String action) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('CHRONOSPARK_MISSION_BRIDGE_ACTION: action=$action');
  }

  Future<void> reportGoalCreated() {
    _logAction('reportGoalCreated');
    return _ref.read(missionStateProvider.notifier).reportGoalCreated();
  }

  Future<void> reportFirstItemCreated() {
    _logAction('reportFirstItemCreated');
    return _ref.read(missionStateProvider.notifier).reportFirstItemCreated();
  }

  Future<void> reportCreatorOpened() {
    _logAction('reportCreatorOpened');
    return _ref.read(missionStateProvider.notifier).reportCreatorOpened();
  }

  Future<void> reportSmartPlannerQuestionAsked() {
    _logAction('reportSmartPlannerQuestionAsked');
    return _ref
        .read(missionStateProvider.notifier)
        .reportSmartPlannerQuestionAsked();
  }

  Future<void> reportSmartCoachQuestionAsked() {
    _logAction('reportSmartCoachQuestionAsked');
    return _ref
        .read(missionStateProvider.notifier)
        .reportSmartCoachQuestionAsked();
  }

  Future<void> reportTimelineOpened() {
    if (kDebugMode) {
      debugPrint('CHRONOSPARK_MISSION_EVENT_TIMELINE_OPENED');
    }
    _logAction('reportTimelineOpened');
    return _ref.read(missionStateProvider.notifier).reportTimelineOpened();
  }

  Future<void> dismissCompletionBanner() {
    _logAction('dismissCompletionBanner');
    return _ref.read(missionStateProvider.notifier).dismissCompletionBanner();
  }
}

final missionEventBridgeProvider = Provider<MissionEventBridge>((Ref ref) {
  return MissionEventBridge(ref);
});
