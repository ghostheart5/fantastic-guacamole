import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('scheduler integration flow', () {
    test('notification settings routes remain correctly nested', () {
      expect(RoutePaths.notifications, startsWith(RoutePaths.settings));
      expect(
        RoutePaths.notificationPermissionRecovery,
        startsWith(RoutePaths.notifications),
      );
      expect(RoutePaths.notificationPermissionRecovery, contains('recovery'));
    });
  });
}
