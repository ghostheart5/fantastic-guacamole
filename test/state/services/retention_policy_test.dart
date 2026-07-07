import 'package:fantastic_guacamole/state/services/retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetentionPolicy', () {
    test('standard policy keeps sessions for 30 days', () {
      expect(RetentionPolicy.standard.sessionMaxAge, const Duration(days: 30));
    });

    test('session expiration honors 30-day window', () {
      final DateTime now = DateTime.utc(2026, 7, 7, 12);
      final DateTime withinWindow = now.subtract(const Duration(days: 29, hours: 23));
      final DateTime outsideWindow = now.subtract(const Duration(days: 30, minutes: 1));

      expect(RetentionPolicy.standard.isSessionExpired(withinWindow, now: now), isFalse);
      expect(RetentionPolicy.standard.isSessionExpired(outsideWindow, now: now), isTrue);
    });
  });
}
