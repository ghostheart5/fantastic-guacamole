import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('friendlyAuthErrorMessage', () {
    test(
      'every supported failure has Spanish copy without backend details',
      () {
        for (final code in <String>[
          'invalid-email',
          'user-not-found',
          'wrong-password',
          'email-already-in-use',
          'weak-password',
          'too-many-requests',
          'push-token-isolation-failed',
          'network-request-failed',
          'user-disabled',
          'user-token-expired',
          'invalid-user-token',
          'requires-recent-login',
          'google-sign-in-cancelled',
          'popup-closed-by-user',
          'github-sign-in-cancelled',
          'no-current-user',
          'auth-unavailable',
          'operation-failed',
          'operation-not-supported',
          'missing-password',
          'missing-email',
          'recovery-session-required',
          'unknown',
        ]) {
          final spanish = friendlyAuthErrorMessage(
            code,
            rawMessage:
                'private-account@example.invalid token=private-test-value',
            isSpanish: true,
          );
          expect(spanish, isNot(friendlyAuthErrorMessage(code)), reason: code);
          expect(spanish, isNot(contains('private-account')));
          expect(spanish, isNot(contains('private-test-value')));
        }
      },
    );

    test(
      'Spanish sign-up outage stays generic and account existence is private',
      () {
        expect(
          friendlyAuthErrorMessage(
            'operation-failed',
            rawMessage: 'Database error saving new user: private-test-value',
            isSpanish: true,
          ),
          'El registro no está disponible temporalmente. Inténtalo de nuevo en un momento.',
        );
        final message = friendlyAuthErrorMessage(
          'email-already-in-use',
          isSpanish: true,
        );
        expect(message, 'No se puede crear una cuenta con estos datos.');
        expect(message, isNot(contains('existe')));
      },
    );

    test('returns backend message for operation-failed', () {
      final String message = friendlyAuthErrorMessage(
        'operation-failed',
        rawMessage: 'Account cannot be deleted during active billing cycle.',
      );

      expect(
        message,
        'The account operation could not be completed. Retry or contact support if it continues.',
      );
    });

    test('returns backend message for operation-not-supported', () {
      final String message = friendlyAuthErrorMessage(
        'operation-not-supported',
        rawMessage: 'Deletion endpoint is not configured.',
      );

      expect(
        message,
        'This account operation is unavailable right now. Contact support for help.',
      );
    });

    test('keeps standard mapping for known auth code', () {
      final String message = friendlyAuthErrorMessage('wrong-password');

      expect(message, 'Credentials are incorrect.');
    });

    test('does not confirm whether a sign-up email already exists', () {
      final String message = friendlyAuthErrorMessage('email-already-in-use');

      expect(message, 'Unable to create an account with these details.');
      expect(message.toLowerCase(), isNot(contains('exists')));
    });

    test('falls back to backend message for unknown code', () {
      final String message = friendlyAuthErrorMessage(
        'custom-backend-error',
        rawMessage: 'Please contact support with code E-13.',
      );

      expect(message, 'Authentication failed. Retry.');
    });
  });
}
