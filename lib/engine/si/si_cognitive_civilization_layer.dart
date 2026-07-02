class CognitiveCivilization {
  const CognitiveCivilization({
    required this.citizens,
    required this.tribes,
    required this.cities,
    required this.climates,
    required this.institutions,
    required this.cohesion,
  });

  final List<String> citizens;
  final List<String> tribes;
  final List<String> cities;
  final List<String> climates;
  final List<String> institutions;
  final double cohesion;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'citizens': citizens,
      'tribes': tribes,
      'cities': cities,
      'climates': climates,
      'institutions': institutions,
      'cohesion': cohesion,
    };
  }
}

class CognitiveCivilizationLayer {
  const CognitiveCivilizationLayer();

  CognitiveCivilization organize({
    required List<String> personas,
    required String mood,
    required int memoryClusters,
    required double reasoningStability,
  }) {
    final double cohesion =
        ((reasoningStability * 0.7) + (personas.isNotEmpty ? 0.2 : 0.1)).clamp(
          0.0,
          1.0,
        );
    return CognitiveCivilization(
      citizens: <String>[
        'intent_agent',
        'memory_agent',
        'ethics_agent',
        'narrative_agent',
      ],
      tribes: personas.isEmpty ? <String>['core_tribe'] : personas,
      cities: <String>[
        'cluster_hub',
        'continuity_hub',
        'alignment_hub',
        'clusters:$memoryClusters',
      ],
      climates: <String>[mood, mood == 'stressed' ? 'storm' : 'temperate'],
      institutions: <String>[
        'reasoning_council',
        'memory_archives',
        'alignment_court',
      ],
      cohesion: cohesion,
    );
  }
}
