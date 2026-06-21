extension StringExtensions on String {
  String get trimmedSafe => trim();

  bool get isPlannerId => RegExp(r'^[a-zA-Z0-9_\-]{2,32}$').hasMatch(trim());

  String get titleCase {
    final List<String> words = trim().split(RegExp(r'\s+'));
    return words
        .where((String w) => w.isNotEmpty)
        .map(
          (String w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
