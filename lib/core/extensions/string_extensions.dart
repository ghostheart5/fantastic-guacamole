extension StringExt on String {
  // ------------------------------------------------------------------
  // Blank checks  (replaces the very common .trim().isEmpty pattern)
  // ------------------------------------------------------------------

  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => trim().isNotEmpty;

  // ------------------------------------------------------------------
  // Casing
  // ------------------------------------------------------------------

  String get capitalize =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);

  String get titleCase => split(
    ' ',
  ).map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  String get sentenceCase =>
      isEmpty ? this : this[0].toUpperCase() + substring(1).toLowerCase();

  // ------------------------------------------------------------------
  // Truncation
  // ------------------------------------------------------------------

  String truncate(int maxLength, {String ellipsis = '…'}) =>
      length <= maxLength ? this : '${substring(0, maxLength)}$ellipsis';

  // ------------------------------------------------------------------
  // Parsing
  // ------------------------------------------------------------------

  int? get toIntOrNull => int.tryParse(trim());
  double? get toDoubleOrNull => double.tryParse(trim());

  // ------------------------------------------------------------------
  // Validation helpers
  // ------------------------------------------------------------------

  bool get isValidEmail =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trim());

  bool get isStrongPassword {
    final s = trim();
    if (s.length < 8) return false;
    return RegExp(r'[A-Z]').hasMatch(s) &&
        RegExp(r'[a-z]').hasMatch(s) &&
        RegExp(r'\d').hasMatch(s);
  }

  // ------------------------------------------------------------------
  // Initials
  // ------------------------------------------------------------------

  String get initials {
    final words = trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

extension NullableStringExt on String? {
  bool get isNullOrBlank => this?.trim().isEmpty ?? true;
  String get orEmpty => this ?? '';
}
