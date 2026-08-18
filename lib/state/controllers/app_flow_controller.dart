import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppView {
  nexus,
  tasks,
  logs,
  profile,
  smartPlanner,
  console,
  settings,
  progression,
  plan,
  creator,
  goals,
  milestones,
  memories,
  personalAlignment,
  timeline,
  trajectoryEngine,
}

AppView? appViewFromName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final String target = value.trim();
  if (target == 'tasks') {
    return AppView.creator;
  }
  if (target == 'logs') {
    return AppView.timeline;
  }
  for (final AppView view in AppView.values) {
    if (view.name == target) {
      return view;
    }
  }
  return null;
}

final appFlowProvider = NotifierProvider<AppFlowController, AppView>(
  AppFlowController.new,
);

class AppFlowController extends Notifier<AppView> {
  @override
  AppView build() => AppView.nexus;

  void toNexus() => state = AppView.nexus;

  /// Compatibility aliases. Tasks and habits are created in Creator; the
  /// former Logs destination is the canonical Timeline.
  void toTasks() => state = AppView.creator;
  void toLogs() => state = AppView.timeline;
  void toProfile() => state = AppView.profile;
  void toSmartPlanner() => state = AppView.smartPlanner;
  void toConsole() => state = AppView.console;
  void toSIConsole() => toConsole();
  void toTrajectoryEngine() => state = AppView.trajectoryEngine;
  void toSettings() => state = AppView.settings;
  void toProgression() => state = AppView.progression;
  void toPlan() => state = AppView.plan;
  void toCreator() => state = AppView.creator;
  void toGoals() => state = AppView.goals;
  void toMilestones() => state = AppView.milestones;
  void toMemories() => state = AppView.memories;
  void toPersonalAlignment() => state = AppView.personalAlignment;
  void toTimeline() => state = AppView.timeline;
  void show(AppView view) => state = view;
}
