import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('creator integration flow', () {
    test('creator view can be activated through app flow controller', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appFlowProvider.notifier).toCreator();
      expect(container.read(appFlowProvider), AppView.creator);
    });

    test('creator route path remains stable', () {
      expect(RoutePaths.creator, '/creator');
      expect(RoutePaths.creator, startsWith('/'));
    });
  });
}

