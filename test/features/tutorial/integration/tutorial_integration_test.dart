import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tutorial integration flow', () {
    test('onboarding and login routes stay rooted and distinct', () {
      expect(RoutePaths.onboarding, startsWith('/'));
      expect(RoutePaths.login, startsWith('/'));
      expect(RoutePaths.onboarding, isNot(equals(RoutePaths.login)));
    });
  });
}
