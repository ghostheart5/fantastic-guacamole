class CognitiveTemperature {
  const CognitiveTemperature({
    required this.level,
    required this.value,
    required this.reason,
  });

  final String level;
  final double value;
  final String reason;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'level': level, 'value': value, 'reason': reason};
  }
}

class CognitiveTemperatureController {
  const CognitiveTemperatureController();

  CognitiveTemperature calibrate({
    required String mood,
    required String intent,
    required double urgency,
    required double stress,
  }) {
    if (urgency > 0.75 || intent == 'start_focus') {
      return const CognitiveTemperature(
        level: 'low',
        value: 0.25,
        reason: 'Urgent execution favors precision.',
      );
    }
    if (intent.contains('idea') || intent == 'insight_request') {
      return const CognitiveTemperature(
        level: 'high',
        value: 0.78,
        reason: 'Exploration mode favors imagination and divergence.',
      );
    }
    if (mood == 'stressed' || stress > 0.65) {
      return const CognitiveTemperature(
        level: 'medium',
        value: 0.45,
        reason: 'Balanced tone supports calm and clarity.',
      );
    }

    return const CognitiveTemperature(
      level: 'medium',
      value: 0.55,
      reason: 'Default balanced reasoning mode.',
    );
  }
}
