import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('friendlyAuthErrorMessage', () {
    test('returns backend message for operation-failed', () {
      final String message = friendlyAuthErrorMessage(
        'operation-failed',
        rawMessage: 'Account cannot be deleted during active billing cycle.',
      );

      expect(message, 'Account cannot be deleted during active billing cycle.');
    });

    test('returns backend message for operation-not-supported', () {
      final String message = friendlyAuthErrorMessage(
        'operation-not-supported',
        rawMessage: 'Deletion endpoint is not configured.',
      );

      expect(message, 'Deletion endpoint is not configured.');
    });

    test('keeps standard mapping for known auth code', () {
      final String message = friendlyAuthErrorMessage('wrong-password');

      expect(message, 'Credentials are incorrect.');
    });

    test('falls back to backend message for unknown code', () {
      final String message = friendlyAuthErrorMessage(
        'custom-backend-error',
        rawMessage: 'Please contact support with code E-13.',
      );

      expect(message, 'Please contact support with code E-13.');
    });
  });
}
