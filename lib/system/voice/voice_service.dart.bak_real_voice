class VoiceService {
  const VoiceService();

  bool get isSpeaking => false;

  Future<void> speak(String text) async {
    // Voice output is intentionally disabled in this build.
    // Keep this method as a safe no-op so UI voice actions do not crash.
  }

  Future<void> speakSummary({
    required String title,
    required List<String> points,
  }) async {
    final String summary = [
      title,
      ...points,
    ].where((String value) => value.trim().isNotEmpty).join('. ');

    await speak(summary);
  }

  Future<void> speakAccessibilityHint({
    required String surface,
    required List<String> controls,
  }) async {
    final String hint = [
      surface,
      ...controls,
    ].where((String value) => value.trim().isNotEmpty).join('. ');

    await speak(hint);
  }

  Future<void> stop() async {
    // No-op.
  }

  Future<void> pause() async {
    // No-op.
  }

  Future<void> setLanguage(String language) async {
    // No-op.
  }

  Future<void> setVolume(double volume) async {
    // No-op.
  }

  Future<void> setRate(double rate) async {
    // No-op.
  }

  Future<void> setPitch(double pitch) async {
    // No-op.
  }
}
