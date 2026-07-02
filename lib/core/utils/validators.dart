class Validators {
  static bool isNonEmpty(String value) => value.trim().isNotEmpty;

  static bool minLength(String value, int min) => value.trim().length >= min;

  static bool maxLength(String value, int max) => value.trim().length <= max;

  static bool isValidEmail(String value) {
    final String input = value.trim();
    if (input.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input);
  }

  static bool isStrongPassword(String value) {
    final String input = value.trim();
    if (input.length < 8) return false;
    return RegExp(r'[A-Z]').hasMatch(input) &&
        RegExp(r'[a-z]').hasMatch(input) &&
        RegExp(r'\d').hasMatch(input);
  }

  static bool isSafeName(String value) {
    final String input = value.trim();
    if (input.isEmpty || input.length > 64) return false;
    return RegExp(r'^[a-zA-Z0-9 _.-]+$').hasMatch(input);
  }
}
