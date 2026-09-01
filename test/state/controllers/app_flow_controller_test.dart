import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appFlowProvider defaults to Nexus', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appFlowProvider), AppView.nexus);
  });

  test('navigation helpers and show() update app flow state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appFlowProvider.notifier);
    controller.toSmartPlanner();
    expect(container.read(appFlowProvider), AppView.smartPlanner);

    controller.toTimeline();
    expect(container.read(appFlowProvider), AppView.timeline);

    controller.toLogs();
    expect(container.read(appFlowProvider), AppView.timeline);

    controller.toMemories();
    expect(container.read(appFlowProvider), AppView.timeline);

    controller.toMilestones();
    expect(container.read(appFlowProvider), AppView.timeline);

    controller.toTasks();
    expect(container.read(appFlowProvider), AppView.creator);

    controller.toTrajectoryEngine();
    expect(container.read(appFlowProvider), AppView.trajectoryEngine);

    controller.show(AppView.settings);
    expect(container.read(appFlowProvider), AppView.settings);
  });

  test('appViewFromName resolves valid names and rejects unknown values', () {
    expect(appViewFromName('coach'), isNull);
    expect(appViewFromName('smartCoach'), isNull);
    expect(appViewFromName('signal'), isNull);
    expect(appViewFromName('timeline'), AppView.timeline);
    expect(appViewFromName('tasks'), AppView.creator);
    expect(appViewFromName('logs'), AppView.timeline);
    expect(appViewFromName('memories'), AppView.timeline);
    expect(appViewFromName('milestones'), AppView.timeline);
    expect(appViewFromName(''), isNull);
    expect(appViewFromName('unknown_view'), isNull);
  });

  test('app views map to one canonical route path', () {
    expect(routePathForAppView(AppView.nexus), RoutePaths.nexus);
    expect(routePathForAppView(AppView.profile), RoutePaths.profile);
    expect(routePathForAppView(AppView.smartPlanner), RoutePaths.smartPlanner);
    expect(routePathForAppView(AppView.console), RoutePaths.si);
    expect(routePathForAppView(AppView.settings), RoutePaths.settings);
    expect(routePathForAppView(AppView.progression), RoutePaths.progression);
    expect(routePathForAppView(AppView.creator), RoutePaths.creator);
    expect(routePathForAppView(AppView.goals), RoutePaths.creatorGoals);
    expect(routePathForAppView(AppView.timeline), RoutePaths.timeline);
    expect(
      routePathForAppView(AppView.trajectoryEngine),
      RoutePaths.trajectoryEngine,
    );
  });

  test('route paths resolve to the visible app view they represent', () {
    expect(appViewFromRoutePath(RoutePaths.shell), AppView.nexus);
    expect(appViewFromRoutePath(RoutePaths.home), AppView.nexus);
    expect(appViewFromRoutePath(RoutePaths.nexus), AppView.nexus);
    expect(appViewFromRoutePath(RoutePaths.profile), AppView.profile);
    expect(appViewFromRoutePath(RoutePaths.legacyProfile), AppView.profile);
    expect(appViewFromRoutePath(RoutePaths.smartPlanner), AppView.smartPlanner);
    expect(
      appViewFromRoutePath(RoutePaths.legacyInsights),
      AppView.smartPlanner,
    );
    expect(appViewFromRoutePath(RoutePaths.si), AppView.console);
    expect(appViewFromRoutePath(RoutePaths.legacySi), AppView.console);
    expect(appViewFromRoutePath(RoutePaths.settings), AppView.settings);
    expect(appViewFromRoutePath(RoutePaths.progression), AppView.progression);
    expect(
      appViewFromRoutePath(RoutePaths.legacyProgression),
      AppView.progression,
    );
    expect(appViewFromRoutePath(RoutePaths.creator), AppView.creator);
    expect(appViewFromRoutePath(RoutePaths.creatorGoals), AppView.goals);
    expect(appViewFromRoutePath(RoutePaths.tasks), AppView.creator);
    expect(appViewFromRoutePath(RoutePaths.legacyTasks), AppView.creator);
    expect(appViewFromRoutePath(RoutePaths.plan), AppView.timeline);
    expect(appViewFromRoutePath(RoutePaths.timeline), AppView.timeline);
    expect(appViewFromRoutePath(RoutePaths.logs), AppView.timeline);
    expect(appViewFromRoutePath(RoutePaths.legacyLogs), AppView.timeline);
    expect(
      appViewFromRoutePath(RoutePaths.trajectoryEngine),
      AppView.trajectoryEngine,
    );
    expect(appViewFromRoutePath('/unknown'), isNull);
  });
}
