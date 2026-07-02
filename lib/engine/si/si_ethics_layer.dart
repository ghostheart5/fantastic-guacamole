class EthicsAssessment {
  const EthicsAssessment({
    required this.safe,
    required this.flags,
    required this.adjustments,
  });

  final bool safe;
  final List<String> flags;
  final List<String> adjustments;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'safe': safe,
      'flags': flags,
      'adjustments': adjustments,
    };
  }
}

class SyntheticEthicsLayer {
  const SyntheticEthicsLayer();

  EthicsAssessment evaluate({
    required String reply,
    required String mood,
    required bool simplify,
  }) {
    final String lowered = reply.toLowerCase();
    final List<String> flags = <String>[];
    final List<String> adjustments = <String>[];

    if (lowered.contains('ignore sleep') || lowered.contains('skip eating')) {
      flags.add('wellbeing_risk');
      adjustments.add('replace with sustainable pacing guidance');
    }
    if (lowered.contains('you must') && mood == 'stressed') {
      flags.add('emotional_pressure_risk');
      adjustments.add('use supportive language');
    }
    if (simplify && reply.length > 260) {
      flags.add('overwhelm_risk');
      adjustments.add('compress response length');
    }

    return EthicsAssessment(
      safe: flags.isEmpty,
      flags: flags,
      adjustments: adjustments,
    );
  }
}
