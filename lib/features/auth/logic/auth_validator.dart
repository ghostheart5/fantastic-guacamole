class AuthValidator {
  const AuthValidator();

  bool isValidEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && trimmed.contains('.');
  }

  bool isValidPassword(String value) {
    return value.trim().length >= 8;
  }

  bool isNotBlank(String value) {
    return value.trim().isNotEmpty;
  }
}
