import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('crashlyticsUserId', () {
    test('never exposes the signed-in user\'s raw id', () {
      const User user = User(id: 'user-123', emailVerified: true);
      expect(crashlyticsUserId(user), isEmpty);
    });

    test('clears to empty string once signed out', () {
      expect(crashlyticsUserId(null), '');
    });
  });
}
