import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('security hardening', () {
    test('production restrictions require release mode and prod flavor', () {
      expect(Env.resolveIsProduction('dev', isReleaseMode: true), isFalse);
      expect(Env.resolveIsProduction('prod', isReleaseMode: true), isTrue);
      expect(
        Env.resolveHasTesterFullAccess(isProduction: true, enableTesterFullAccess: true),
        isFalse,
      );
    });

    test('dynamic network endpoints must be HTTPS without credentials', () {
      expect(parseSecureHttpsEndpoint('http://example.com'), isNull);
      expect(parseSecureHttpsEndpoint('https://user:password@example.com/path'), isNull);
      expect(
        parseSecureHttpsEndpoint('https://api.chronospark.app/path'),
        Uri.parse('https://api.chronospark.app/path'),
      );
    });

    test('logger redacts common credentials and personal identifiers', () {
      final String redacted = Logger.redactSensitive(
        'email=user@example.com Authorization: Bearer abc.def '
        'access_token=secret password=hunter2',
      );

      expect(redacted, isNot(contains('user@example.com')));
      expect(redacted, isNot(contains('abc.def')));
      expect(redacted, isNot(contains('secret')));
      expect(redacted, isNot(contains('hunter2')));
    });
  });
}
