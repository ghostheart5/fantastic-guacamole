class SIConsoleResponseValidator {
  static bool isInvalid(String value) {
    final String normalized = value.trim().toLowerCase();

    return normalized == 'undefined' ||
        normalized == 'null' ||
        normalized == 'undefined response' ||
        normalized == 'no response';
  }
}
