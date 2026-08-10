import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('si_console integration flow', () {
    test('si console route remains under advanced settings namespace', () {
      expect(RoutePaths.si, startsWith(RoutePaths.advancedRoot));
      expect(RoutePaths.si, contains('si-console'));
    });

    test('console app view transition is available', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appFlowProvider.notifier).toConsole();
      expect(container.read(appFlowProvider), AppView.console);
    });
  });
}
