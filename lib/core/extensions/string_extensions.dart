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

  String truncate(int maxLength, {String ellipsis = '…'}) {
    if (maxLength < 0) {
      throw ArgumentError.value(maxLength, 'maxLength', 'must not be negative');
    }
    return length <= maxLength ? this : '${substring(0, maxLength)}$ellipsis';
  }

  // ------------------------------------------------------------------
  // Parsing
  // ------------------------------------------------------------------

  int? get toIntOrNull => int.tryParse(trim());
  double? get toDoubleOrNull => double.tryParse(trim());

  // ------------------------------------------------------------------
  // Initials
  // ------------------------------------------------------------------

  String get initials {
    final String trimmed = trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

extension NullableStringExt on String? {
  bool get isNullOrBlank => this?.trim().isEmpty ?? true;
  String get orEmpty => this ?? '';
}
