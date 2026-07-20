import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/validators/auth_input_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthInputValidator', () {
    const AuthInputValidator validator = AuthInputValidator();

    test('accepts a valid login payload', () {
      final Result<void> result = validator.validateLogin(
        email: 'user@example.com',
        password: 'Password123',
      );

      expect(result.isSuccess, isTrue);
    });

    test('rejects a weak signup password', () {
      final Result<void> result = validator.validateSignUp(
        email: 'user@example.com',
        password: 'weakpass',
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('Result', () {
    test('fold returns the success branch', () {
      const Result<int> result = Result<int>.success(42);

      final String value = result.fold(
        onSuccess: (int success) => 'value:$success',
        onFailure: (Object failure) => 'error:$failure',
      );

      expect(value, 'value:42');
    });

    test('fold returns the failure branch', () {
      const Result<int> result = Result<int>.failure('broken');

      final String value = result.fold(
        onSuccess: (int success) => 'value:$success',
        onFailure: (Object failure) => 'error:$failure',
      );

      expect(value, 'error:broken');
    });
  });
}
