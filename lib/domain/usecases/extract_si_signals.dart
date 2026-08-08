/// Signals derived from the current ChronoSpark state, consumed by the SI
/// Console pipeline.
class SiSignals {
  const SiSignals({
    required this.friction,
    required this.overwhelm,
    required this.streakHealth,
    required this.goalDrift,
    required this.taskAvoidance,
    required this.emotion,
    required this.emotionalStrain,
    required this.emotionalStability,
    required this.emotionalPatterns,
  });

  final bool friction;
  final bool overwhelm;
  final String streakHealth;
  final bool goalDrift;
  final bool taskAvoidance;
  final String emotion;
  final bool emotionalStrain;
  final bool emotionalStability;
  final List<String> emotionalPatterns;
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Owns the SI signal thresholds. These previously lived inline in
/// `si_pipeline_provider`, which made the provider the owner of core SI logic
/// rather than an orchestrator. Inputs are primitives so the domain layer does
/// not depend on state-layer models; the provider maps the result onto its own
/// view model.
class ExtractSiSignals {
  const ExtractSiSignals();

  /// Emotions that count as strain.
  static const Set<String> strainEmotions = <String>{
    'anxious',
    'scattered',
    'negative',
    'fatigued',
  };

  /// Emotions that count as stability.
  static const Set<String> stabilityEmotions = <String>{
    'calm',
    'focused',
    'positive',
  };

  SiSignals call({
    required double pressureIndex,
    required double behaviorDivergence,
    required double energy,
    required int streak,
    required bool hasGoals,
    required int skippedTaskCount,
    required String emotion,
    required String insightsSummary,
  }) {
    final bool friction = pressureIndex >= 60 || energy < 0.35;
    final bool overwhelm = pressureIndex >= 75 || behaviorDivergence >= 50;
    final String streakHealth = streak >= 10
        ? 'strong'
        : streak >= 3
        ? 'stable'
        : 'fragile';
    final bool goalDrift = hasGoals && behaviorDivergence >= 40;
    final bool taskAvoidance = skippedTaskCount >= 2;
    final bool emotionalStrain = strainEmotions.contains(emotion);
    final bool emotionalStability = stabilityEmotions.contains(emotion);

    final Set<String> patterns = <String>{};
    if (insightsSummary.toLowerCase().contains('overload')) {
      patterns.add('overload_pattern');
    }
    if (emotionalStrain) {
      patterns.add('emotional_strain');
    }
    if (emotionalStability) {
      patterns.add('emotional_stability');
    }

    return SiSignals(
      friction: friction,
      overwhelm: overwhelm,
      streakHealth: streakHealth,
      goalDrift: goalDrift,
      taskAvoidance: taskAvoidance,
      emotion: emotion,
      emotionalStrain: emotionalStrain,
      emotionalStability: emotionalStability,
      emotionalPatterns: patterns.toList(growable: false),
    );
  }
}
