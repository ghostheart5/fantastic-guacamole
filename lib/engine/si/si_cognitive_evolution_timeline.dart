class EvolutionTimeline {
  const EvolutionTimeline({
    required this.version,
    required this.stage,
    required this.capabilities,
    required this.nextMilestone,
  });

  final String version;
  final String stage;
  final List<String> capabilities;
  final String nextMilestone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'stage': stage,
      'capabilities': capabilities,
      'next_milestone': nextMilestone,
    };
  }
}

class CognitiveEvolutionTimeline {
  const CognitiveEvolutionTimeline();

  EvolutionTimeline map({
    required double consciousnessScore,
    required double emergenceIndex,
  }) {
    if (consciousnessScore > 0.86) {
      return const EvolutionTimeline(
        version: 'v6+',
        stage: 'organism-like',
        capabilities: <String>[
          'cross-realm continuity',
          'adaptive emergence',
          'identity persistence',
        ],
        nextMilestone: 'deepen autonomous yet aligned adaptation',
      );
    }
    if (consciousnessScore > 0.72 || emergenceIndex > 0.62) {
      return const EvolutionTimeline(
        version: 'v5',
        stage: 'synthetic',
        capabilities: <String>[
          'narrative continuity',
          'meta-reasoning',
          'resonance shaping',
        ],
        nextMilestone: 'stabilize organism-like continuity behaviors',
      );
    }
    if (consciousnessScore > 0.6) {
      return const EvolutionTimeline(
        version: 'v4',
        stage: 'emergent',
        capabilities: <String>['pattern synthesis', 'adaptive style'],
        nextMilestone: 'expand synthetic identity persistence',
      );
    }

    return const EvolutionTimeline(
      version: 'v3',
      stage: 'emotional',
      capabilities: <String>['emotion-aware responses'],
      nextMilestone: 'build stronger emergent behavior',
    );
  }
}
