import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tasks integration flow', () {
    test('tasks route remains under advanced settings namespace', () {
      expect(RoutePaths.tasks, startsWith(RoutePaths.advancedRoot));
      expect(RoutePaths.tasks, contains('tasks'));
    });
  });
}
