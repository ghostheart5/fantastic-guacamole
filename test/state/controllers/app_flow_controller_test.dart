import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appFlowProvider defaults to coach', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appFlowProvider), AppView.coach);
  });

  test('navigation helpers and show() update app flow state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appFlowProvider.notifier);
    controller.toPlan();
    expect(container.read(appFlowProvider), AppView.plan);

    controller.toTimeline();
    expect(container.read(appFlowProvider), AppView.timeline);

    controller.show(AppView.settings);
    expect(container.read(appFlowProvider), AppView.settings);
  });

  test('appViewFromName resolves valid names and rejects unknown values', () {
    expect(appViewFromName('coach'), AppView.coach);
    expect(appViewFromName('timeline'), AppView.timeline);
    expect(appViewFromName(''), isNull);
    expect(appViewFromName('unknown_view'), isNull);
  });
}
