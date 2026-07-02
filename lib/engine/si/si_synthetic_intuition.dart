class SyntheticIntuition {
  const SyntheticIntuition({
    required this.inferredIntent,
    required this.hiddenMeaning,
    required this.missingDetails,
    required this.emotionalSubtext,
    required this.anticipatesConfusion,
    required this.confidence,
  });

  final String inferredIntent;
  final String hiddenMeaning;
  final List<String> missingDetails;
  final String emotionalSubtext;
  final bool anticipatesConfusion;
  final double confidence;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'inferred_intent': inferredIntent,
      'hidden_meaning': hiddenMeaning,
      'missing_details': missingDetails,
      'emotional_subtext': emotionalSubtext,
      'anticipates_confusion': anticipatesConfusion,
      'confidence': confidence,
    };
  }
}

class SyntheticIntuitionLayer {
  const SyntheticIntuitionLayer();

  SyntheticIntuition infer({
    required String input,
    required String intent,
    required String mood,
    required double confidence,
  }) {
    final String lowered = input.toLowerCase();
    final bool vague =
        lowered.split(' ').length < 4 || lowered.contains('something');
    final bool anticipatesConfusion =
        vague ||
        mood == 'confused' ||
        lowered.contains('not sure') ||
        confidence < 0.55;

    final List<String> missing = <String>[
      if (intent == 'start_focus') 'session_duration',
      if (intent == 'get_task') 'priority_scope',
      if (vague) 'specific_goal',
    ];

    final String hiddenMeaning;
    if (lowered.contains('stuck') || lowered.contains('overwhelmed')) {
      hiddenMeaning =
          'The user may need simplification and emotional reassurance.';
    } else if (lowered.contains('late') || lowered.contains('behind')) {
      hiddenMeaning =
          'The user may be feeling time pressure and fear of falling behind.';
    } else {
      hiddenMeaning = 'The user likely wants momentum and clear next action.';
    }

    return SyntheticIntuition(
      inferredIntent: intent == 'general_query' && lowered.contains('start')
          ? 'start_focus'
          : intent,
      hiddenMeaning: hiddenMeaning,
      missingDetails: missing,
      emotionalSubtext: mood,
      anticipatesConfusion: anticipatesConfusion,
      confidence: (confidence * 0.9).clamp(0.0, 1.0),
    );
  }
}
