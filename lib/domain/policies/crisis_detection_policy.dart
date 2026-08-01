abstract final class CrisisDetectionPolicy {
  static const List<String> _keywords = <String>[
    'suicide',
    'kill myself',
    'end my life',
    'self harm',
    'self-harm',
    'want to die',
    'hurt myself',
    'dont want to live',
    'do not want to live',
    "don't want to live",
    'i want to disappear',
    'i cant go on',
    "i can't go on",
    'take my life',
    'ending it all',
    'end it all',
  ];

  static bool detects(String input) {
    final String normalized = input.toLowerCase();
    return _keywords.any(normalized.contains);
  }
}
