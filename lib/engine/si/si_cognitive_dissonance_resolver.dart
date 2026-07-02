class DissonanceResolution {
  const DissonanceResolution({
    required this.detected,
    required this.conflicts,
    required this.resolutionTone,
    required this.resolutionAction,
  });

  final bool detected;
  final List<String> conflicts;
  final String resolutionTone;
  final String resolutionAction;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'detected': detected,
      'conflicts': conflicts,
      'resolution_tone': resolutionTone,
      'resolution_action': resolutionAction,
    };
  }
}

class CognitiveDissonanceResolver {
  const CognitiveDissonanceResolver();

  DissonanceResolution resolve({
    required String intent,
    required String mood,
    required List<String> goals,
    required List<String> habits,
    required String input,
  }) {
    final List<String> conflicts = <String>[];
    if (intent == 'start_focus' && mood == 'stressed') {
      conflicts.add('intent_emotion_conflict');
    }
    if (goals.isNotEmpty &&
        habits.isNotEmpty &&
        habits.any((String h) => h.contains('avoid'))) {
      conflicts.add('goal_habit_conflict');
    }
    if (goals.isNotEmpty && input.toLowerCase().contains('skip goal')) {
      conflicts.add('request_goal_conflict');
    }

    return DissonanceResolution(
      detected: conflicts.isNotEmpty,
      conflicts: conflicts,
      resolutionTone: conflicts.isNotEmpty ? 'gentle_reframe' : 'direct',
      resolutionAction: conflicts.isNotEmpty
          ? 'offer smallest aligned step and acknowledge tension'
          : 'continue normal guidance',
    );
  }
}
