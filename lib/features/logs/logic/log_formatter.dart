class LogFormatter {
  const LogFormatter();

  String normalize(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'No details';
    }
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  List<String> normalizeAll(List<String> values) {
    return values.map(normalize).toList(growable: false);
  }
}
