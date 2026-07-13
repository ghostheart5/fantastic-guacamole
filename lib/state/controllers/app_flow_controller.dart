import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppView {
  coach,
  nexus,
  tasks,
  logs,
  profile,
  smartCoach,
  insight,
  console,
  settings,
  progression,
  plan,
  creator,
  flowmap,
  goals,
  milestones,
  memories,
  soulMap,
  timeline,
}

AppView? appViewFromName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final String target = value.trim();
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
  AppView build() => AppView.coach;

  void toCoach() => state = AppView.coach;
  void toNexus() => state = AppView.nexus;
  void toTasks() => state = AppView.tasks;
  void toLogs() => state = AppView.logs;
  void toProfile() => state = AppView.profile;
  void toSmartCoach() => state = AppView.smartCoach;
  void toInsight() => state = AppView.insight;
  void toConsole() => state = AppView.console;
  void toSettings() => state = AppView.settings;
  void toProgression() => state = AppView.progression;
  void toPlan() => state = AppView.plan;
  void toCreator() => state = AppView.creator;
  void toFlowmap() => state = AppView.flowmap;
  void toGoals() => state = AppView.goals;
  void toMilestones() => state = AppView.milestones;
  void toMemories() => state = AppView.memories;
  void toSoulMap() => state = AppView.soulMap;
  void toTimeline() => state = AppView.timeline;
  void show(AppView view) => state = view;
}
