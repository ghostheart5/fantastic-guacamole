class ThoughtCompression {
  const ThoughtCompression();

  String compress(String internalReasoning, {int maxChars = 220}) {
    final String text = internalReasoning
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length <= maxChars) return text;

    final String shortened = text.substring(0, maxChars);
    final int lastPeriod = shortened.lastIndexOf('.');
    if (lastPeriod > 80) {
      return shortened.substring(0, lastPeriod + 1);
    }
    return '$shortened...';
  }
}
