import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
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
    expect(appViewFromName(''), isNull);
    expect(appViewFromName('unknown_view'), isNull);
  });
}
