class Validators {
  static bool isNonEmpty(String value) => value.trim().isNotEmpty;

  static bool isSafeName(String value) {
    final regExp = RegExp(r'^[a-zA-Z0-9 _\-]{3,40}$');
    return regExp.hasMatch(value.trim());
  }
}
