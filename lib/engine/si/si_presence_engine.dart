class PresenceState {
  const PresenceState({
    required this.identityContinuity,
    required this.emotionalContinuity,
    required this.memoryContinuity,
    required this.flowScore,
    required this.companionFeel,
  });

  final double identityContinuity;
  final double emotionalContinuity;
  final double memoryContinuity;
  final double flowScore;
  final bool companionFeel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'identity_continuity': identityContinuity,
      'emotional_continuity': emotionalContinuity,
      'memory_continuity': memoryContinuity,
      'flow_score': flowScore,
      'companion_feel': companionFeel,
    };
  }
}

class SyntheticPresenceEngine {
  const SyntheticPresenceEngine();

  PresenceState evaluate({
    required String mood,
    required String previousMood,
    required int memoryRecords,
    required bool consistentPersona,
  }) {
    final double identity = consistentPersona ? 0.9 : 0.6;
    final double emotional = mood == previousMood ? 0.88 : 0.64;
    final double memory = (0.4 + (memoryRecords.clamp(0, 15) / 25)).clamp(
      0.4,
      1.0,
    );
    final double flow = ((identity + emotional + memory) / 3).clamp(0.0, 1.0);

    return PresenceState(
      identityContinuity: identity,
      emotionalContinuity: emotional,
      memoryContinuity: memory,
      flowScore: flow,
      companionFeel: flow >= 0.72,
    );
  }
}
