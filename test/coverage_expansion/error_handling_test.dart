import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/errors/failure.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('error handling coverage', () {
    test('friendlyAuthErrorMessage maps known codes to safe messages', () {
      expect(
        friendlyAuthErrorMessage('invalid-email'),
        'Please enter a valid email address.',
      );
      expect(
        friendlyAuthErrorMessage('network-request-failed'),
        'Sign-in is temporarily unavailable. Check your connection and try again.',
      );
      expect(
        friendlyAuthErrorMessage('user-token-expired'),
        'We could not restore your session. Please sign in again.',
      );
      expect(
        friendlyAuthErrorMessage('missing-password'),
        'Password is required.',
      );
    });

    test(
      'friendlyAuthErrorMessage returns generic fallback for unknown code',
      () {
        expect(
          friendlyAuthErrorMessage('something-unexpected'),
          'Authentication could not be completed. Please try again.',
        );
      },
    );

    test('friendlyAuthErrorMessage handles backend sign-up failure case', () {
      final String message = friendlyAuthErrorMessage(
        'unknown',
        rawMessage: 'Unexpected failure while saving new user to database.',
      );
      expect(
        message,
        'Sign-up is temporarily unavailable. Please retry in a moment.',
      );
    });

    test('known domain failures keep stable string output', () {
      const AppException appEx = AppException('safe-message');
      const StorageException storageEx = StorageException('storage-failure');
      const ValidationException validationEx = ValidationException(
        'invalid-input',
      );
      const Failure failure = Failure('fail');
      const StorageFailure storageFailure = StorageFailure('storage-fail');

      expect(appEx.toString(), 'safe-message');
      expect(storageEx.toString(), 'storage-failure');
      expect(validationEx.toString(), 'invalid-input');
      expect(failure.toString(), 'fail');
      expect(storageFailure.toString(), 'storage-fail');
    });

    test('logger redacts sensitive fragments from messages', () {
      final String mail = 'pilot@chronospark.app';
      final String pass = 'password=topsecret';
      final String bearer = 'Bearer abc123xyz456';
      final String keyLabel = 'api_key';
      final String keyValue = 'AIza12345678901234567890123456789012345';

      final String redacted = Logger.redactSensitive(
        'auth email=$mail $pass $bearer "$keyLabel":"$keyValue" rawKey=$keyValue',
      );

      expect(redacted.contains(mail), isFalse);
      expect(redacted.contains('topsecret'), isFalse);
      expect(redacted.contains('abc123xyz456'), isFalse);
      expect(redacted.contains(keyValue), isFalse);
      expect(redacted.contains('[redacted-email]'), isTrue);
      expect(redacted.contains('[redacted-password]'), isTrue);
      expect(redacted.contains('[redacted-token]'), isTrue);
      expect(redacted.contains('[redacted-secret]'), isTrue);
      expect(redacted.contains('[redacted-api-key]'), isTrue);
    });

    test('logger error pathways do not throw when output is disabled', () {
      Logger.errorOutputEnabled = false;
      expect(
        () => Logger.error('runtime failure for session_id', Exception('oops')),
        returnsNormally,
      );
      Logger.errorOutputEnabled = true;
    });
  });
}
