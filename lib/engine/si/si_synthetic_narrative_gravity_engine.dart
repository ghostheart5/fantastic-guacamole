class NarrativeGravity {
  const NarrativeGravity({
    required this.strongArcs,
    required this.weakArcs,
    required this.brokenArcs,
    required this.emergingArcs,
    required this.emotionalArcs,
    required this.pull,
  });

  final List<String> strongArcs;
  final List<String> weakArcs;
  final List<String> brokenArcs;
  final List<String> emergingArcs;
  final List<String> emotionalArcs;
  final double pull;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'strong_arcs': strongArcs,
      'weak_arcs': weakArcs,
      'broken_arcs': brokenArcs,
      'emerging_arcs': emergingArcs,
      'emotional_arcs': emotionalArcs,
      'pull': pull,
    };
  }
}

class SyntheticNarrativeGravityEngine {
  const SyntheticNarrativeGravityEngine();

  NarrativeGravity evaluate({
    required String intent,
    required String mood,
    required double continuity,
  }) {
    final List<String> strong = <String>[
      if (intent == 'start_focus') 'execution_arc',
    ];
    final List<String> weak = <String>[
      if (intent == 'general_query') 'clarity_arc',
    ];
    final List<String> broken = <String>[
      if (mood == 'stressed' && continuity < 0.5) 'confidence_arc',
    ];
    final List<String> emerging = <String>[
      if (intent == 'reflect') 'insight_arc',
    ];
    final List<String> emotional = <String>[mood];
    final double pull =
        ((strong.length * 0.32) +
                (emerging.length * 0.22) +
                (emotional.length * 0.16) +
                (continuity * 0.3) -
                (broken.length * 0.18))
            .clamp(0.0, 1.0);
    return NarrativeGravity(
      strongArcs: strong,
      weakArcs: weak,
      brokenArcs: broken,
      emergingArcs: emerging,
      emotionalArcs: emotional,
      pull: pull,
    );
  }
}
