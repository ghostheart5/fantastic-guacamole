import 'package:fantastic_guacamole/app/app_view.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fantastic_guacamole/app/app_view.dart' show AppView;

AppView? appViewFromName(String? value) {
  return AppRouteRegistry.viewForName(value);
}

String routePathForAppView(AppView view) {
  return AppRouteRegistry.routeForView(view).path;
}

AppView? appViewFromRoutePath(String? path) {
  return AppRouteRegistry.viewForPath(path);
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
