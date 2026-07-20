import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';

enum AuthValidationRule {
  emailRequired,
  emailFormat,
  passwordRequired,
  passwordLength,
  passwordStrength,
}

class AuthInputValidator {
  const AuthInputValidator();

  Result<void> validateEmail(String value) {
    try {
      EmailAddress(value);
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(error);
    }
  }

  Result<void> validatePassword(String value) {
    try {
      PasswordValue(value);
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(error);
    }
  }

  Result<void> validateLogin({required String email, required String password}) {
    final Result<void> emailResult = validateEmail(email);
    if (emailResult.isFailure) {
      return emailResult;
    }
    return validatePassword(password);
  }

  Result<void> validateSignUp({required String email, required String password}) {
    final Result<void> loginResult = validateLogin(email: email, password: password);
    if (loginResult.isFailure) {
      return loginResult;
    }
    final PasswordValue value = PasswordValue(password);
    if (!value.isStrong) {
      return const Result<void>.failure(
        FormatException('Password must contain upper-case, lower-case, and numeric characters.'),
      );
    }
    return const Result<void>.success(null);
  }
}
