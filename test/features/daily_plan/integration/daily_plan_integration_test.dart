import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('daily_plan integration flow', () {
    test('plan route is anchored to root home surface', () {
      expect(RoutePaths.plan, '/plan');
      expect(RoutePaths.plan, startsWith('/'));
      expect(RoutePaths.plan, isNot(equals(RoutePaths.home)));
    });
  });
}
