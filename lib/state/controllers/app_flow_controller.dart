import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppView {
  nexus,
  profile,
  smartPlanner,
  console,
  settings,
  progression,
  creator,
  goals,
  timeline,
  trajectoryEngine,
}

AppView? appViewFromName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final String target = value.trim();
  switch (target) {
    case 'tasks':
      return AppView.creator;
    case 'logs':
    case 'memories':
    case 'milestones':
    case 'plan':
      return AppView.timeline;
  }
  for (final AppView view in AppView.values) {
    if (view.name == target) {
      return view;
    }
  }
  return null;
}

String routePathForAppView(AppView view) {
  return switch (view) {
    AppView.nexus => RoutePaths.nexus,
    AppView.profile => RoutePaths.profile,
    AppView.smartPlanner => RoutePaths.smartPlanner,
    AppView.console => RoutePaths.si,
    AppView.settings => RoutePaths.settings,
    AppView.progression => RoutePaths.progression,
    AppView.creator => RoutePaths.creator,
    // Goals is a Creator-owned sub-surface until it has its own canonical URL.
    AppView.goals => RoutePaths.creatorGoals,
    AppView.timeline => RoutePaths.timeline,
    AppView.trajectoryEngine => RoutePaths.trajectoryEngine,
  };
}

AppView? appViewFromRoutePath(String? path) {
  if (path == null || path.trim().isEmpty) {
    return null;
  }
  final String target = path.trim();
  return switch (target) {
    RoutePaths.shell || RoutePaths.home || RoutePaths.nexus => AppView.nexus,
    RoutePaths.profile || RoutePaths.legacyProfile => AppView.profile,
    RoutePaths.smartPlanner ||
    RoutePaths.legacyInsights => AppView.smartPlanner,
    RoutePaths.si || RoutePaths.legacySi => AppView.console,
    RoutePaths.settings => AppView.settings,
    RoutePaths.progression ||
    RoutePaths.legacyProgression => AppView.progression,
    RoutePaths.creator ||
    RoutePaths.tasks ||
    RoutePaths.legacyTasks => AppView.creator,
    RoutePaths.plan ||
    RoutePaths.timeline ||
    RoutePaths.logs ||
    RoutePaths.legacyLogs => AppView.timeline,
    RoutePaths.trajectoryEngine => AppView.trajectoryEngine,
    _ => null,
  };
}

final appFlowProvider = NotifierProvider<AppFlowController, AppView>(
  AppFlowController.new,
);

class AppFlowController extends Notifier<AppView> {
  @override
  AppView build() => AppView.nexus;

  void toNexus() => state = AppView.nexus;

  /// Compatibility aliases for retired standalone destinations.
  void toTasks() => state = AppView.creator;
  void toLogs() => state = AppView.timeline;
  void toProfile() => state = AppView.profile;
  void toSmartPlanner() => state = AppView.smartPlanner;
  void toConsole() => state = AppView.console;
  void toSIConsole() => toConsole();
  void toTrajectoryEngine() => state = AppView.trajectoryEngine;
  void toSettings() => state = AppView.settings;
  void toProgression() => state = AppView.progression;
  void toCreator() => state = AppView.creator;
  void toGoals() => state = AppView.goals;
  void toMilestones() => state = AppView.timeline;
  void toMemories() => state = AppView.timeline;
  void toTimeline() => state = AppView.timeline;
  void show(AppView view) => state = view;
}
