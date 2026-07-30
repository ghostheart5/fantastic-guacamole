import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('analytics and log scrubbing coverage', () {
    test('log scrubber redacts auth and key material from debug strings', () {
      final String userPart = 'captain';
      final String domainPart = 'chronospark.app';
      final String email = '$userPart@$domainPart';
      final String passValue = 'pw1234';
      final String bearer = 'Bearer alphabetagamma';
      final String accessLabel = 'access_token';
      final String secretLabel = 'client_secret';
      final String apiKey = 'AIza12345678901234567890123456789012345';

      final String raw =
          'event=login email=$email password=$passValue $bearer "$accessLabel":"A1B2C3" "$secretLabel":"hidden" "$apiKey"';
      final String scrubbed = Logger.redactSensitive(raw);

      expect(scrubbed.contains(email), isFalse);
      expect(scrubbed.contains(passValue), isFalse);
      expect(
        scrubbed.contains(
          'alpha'
          'beta'
          'gamma',
        ),
        isFalse,
      );
      expect(scrubbed.contains('A1B2C3'), isFalse);
      expect(scrubbed.contains('hidden'), isFalse);
      expect(scrubbed.contains(apiKey), isFalse);
      expect(scrubbed.contains('[redacted-email]'), isTrue);
      expect(scrubbed.contains('[redacted-password]'), isTrue);
      expect(scrubbed.contains('[redacted-token]'), isTrue);
      expect(scrubbed.contains('[redacted-secret]'), isTrue);
      expect(scrubbed.contains('[redacted-api-key]'), isTrue);
    });

    test('friendly auth messages do not expose raw auth credentials', () {
      final String sensitive = 'email=pilot@chronospark.app password=pw1234';

      final String safeKnown = friendlyAuthErrorMessage(
        'wrong-password',
        rawMessage: sensitive,
      );
      expect(safeKnown, 'Credentials are incorrect.');
      expect(safeKnown.contains('pw1234'), isFalse);
      expect(safeKnown.contains('@chronospark.app'), isFalse);

      final String safeRateLimit = friendlyAuthErrorMessage(
        'too-many-requests',
        rawMessage: sensitive,
      );
      expect(safeRateLimit, 'Rate limit engaged. Wait, then retry.');
      expect(safeRateLimit.contains('pw1234'), isFalse);
    });

    test('logger pathways are callable for event/crash wrappers', () {
      Logger.enabled = false;
      Logger.errorOutputEnabled = false;

      expect(() => Logger.log('analytics', 'event_login'), returnsNormally);
      expect(() => Logger.info('event_progression'), returnsNormally);
      expect(() => Logger.warn('event_notification'), returnsNormally);
      expect(
        () => Logger.error('crash-wrapper', Exception('auth_session failed')),
        returnsNormally,
      );

      Logger.enabled = true;
      Logger.errorOutputEnabled = true;
    });
  });
}
