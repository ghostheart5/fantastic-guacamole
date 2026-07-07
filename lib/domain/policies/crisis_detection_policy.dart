abstract final class CrisisDetectionPolicy {
  static const List<String> _keywords = <String>[
    'suicide',
    'kill myself',
    'end my life',
    'self harm',
    'self-harm',
    'want to die',
    'hurt myself',
  ];

  static bool detects(String input) {
    final String normalized = input.toLowerCase();
    return _keywords.any(normalized.contains);
  }
}
