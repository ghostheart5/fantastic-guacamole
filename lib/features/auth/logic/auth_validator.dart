import 'package:fantastic_guacamole/core/utils/validators.dart';

/// Auth-layer validation helpers.
///
/// Each method returns a non-null error string when the value is invalid, or
/// `null` when valid — matching the signature expected by Flutter's
/// [FormField.validator] callback and making the call sites self-documenting.
abstract final class AuthValidator {
  /// Returns an error message if [value] is not a well-formed email address,
  /// or `null` if it is valid.
  static String? email(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }
    if (!Validators.isValidEmail(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Returns an error message if [value] does not meet the password strength
  /// requirements (≥ 8 characters, at least one uppercase letter, one
  /// lowercase letter, and one digit), or `null` if it is valid.
  static String? password(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Password is required.';
    }
    if (!Validators.isStrongPassword(trimmed)) {
      return 'Password must be 8+ characters with uppercase, lowercase, and a number.';
    }
    return null;
  }

  /// Returns an error message if [confirm] does not match [password], or
  /// `null` if the two values are identical.
  ///
  /// Validate [password] first with [AuthValidator.password]; this method only
  /// checks whether the confirmation matches.
  static String? passwordConfirm(String password, String confirm) {
    if (confirm != password) {
      return 'Passwords do not match.';
    }
    return null;
  }
}
