import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Crash reports carried no user identity before this — `crashlyticsUserId`
/// is the only logic behind that, so it's the only part of the Crashlytics
/// wiring that's meaningfully unit-testable without mocking the plugin
/// itself (nothing else in this codebase does that for any Crashlytics call
/// site).
void main() {
  group('crashlyticsUserId', () {
    test('derives the signed-in user\'s id', () {
      const User user = User(id: 'user-123', emailVerified: true);
      expect(crashlyticsUserId(user), 'user-123');
    });

    test('clears to empty string once signed out', () {
      expect(crashlyticsUserId(null), '');
    });
  });
}
