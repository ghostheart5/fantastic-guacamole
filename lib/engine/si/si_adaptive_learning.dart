class SIAdaptiveProfile {
  const SIAdaptiveProfile({
    this.vocabulary = const <String>[],
    this.slang = const <String>[],
    this.routines = const <String>[],
    this.preferences = const <String, dynamic>{},
    this.emotionalTriggers = const <String>[],
    this.pacing = 'balanced',
    this.decisionStyle = 'balanced',
  });

  final List<String> vocabulary;
  final List<String> slang;
  final List<String> routines;
  final Map<String, dynamic> preferences;
  final List<String> emotionalTriggers;
  final String pacing;
  final String decisionStyle;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'vocabulary': vocabulary,
      'slang': slang,
      'routines': routines,
      'preferences': preferences,
      'emotional_triggers': emotionalTriggers,
      'pacing': pacing,
      'decision_style': decisionStyle,
    };
  }
}

class AdaptiveLearningLayer {
  const AdaptiveLearningLayer();

  SIAdaptiveProfile learn({
    required String input,
    required List<String> history,
    required Map<String, dynamic> metadata,
  }) {
    final List<String> words = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((String w) => w.length >= 3)
        .take(10)
        .toList();

    final List<String> slang = words
        .where((String w) => w.contains("'") || w.length <= 4)
        .toList();
    final List<String> routines = history
        .where(
          (String h) =>
              h.toLowerCase().contains('focus') ||
              h.toLowerCase().contains('daily'),
        )
        .take(5)
        .toList();

    final String pacing =
        metadata['pacing']?.toString() ??
        (input.length > 120 ? 'detailed' : 'fast');
    final String decisionStyle =
        metadata['decision_style']?.toString() ?? 'direct';

    return SIAdaptiveProfile(
      vocabulary: words,
      slang: slang,
      routines: routines,
      preferences: <String, dynamic>{
        'preferred_mode': metadata['preferred_mode'] ?? 'conversational',
        'prefers_direct': decisionStyle == 'direct',
      },
      emotionalTriggers: <String>[
        if (input.toLowerCase().contains('urgent')) 'urgency',
        if (input.toLowerCase().contains('stuck')) 'frustration',
      ],
      pacing: pacing,
      decisionStyle: decisionStyle,
    );
  }
}
