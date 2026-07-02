class ShadowInsight {
  const ShadowInsight({
    required this.fears,
    required this.insecurities,
    required this.blockers,
    required this.blindSpots,
    required this.gentleNavigation,
  });

  final List<String> fears;
  final List<String> insecurities;
  final List<String> blockers;
  final List<String> blindSpots;
  final String gentleNavigation;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fears': fears,
      'insecurities': insecurities,
      'blockers': blockers,
      'blind_spots': blindSpots,
      'gentle_navigation': gentleNavigation,
    };
  }
}

class SyntheticShadowModule {
  const SyntheticShadowModule();

  ShadowInsight inspect({required String input, required String mood}) {
    final String lowered = input.toLowerCase();
    return ShadowInsight(
      fears: <String>[
        if (lowered.contains('fail')) 'fear_of_failure',
        if (lowered.contains('behind')) 'fear_of_falling_behind',
      ],
      insecurities: <String>[
        if (lowered.contains('not good enough')) 'self_efficacy_doubt',
      ],
      blockers: <String>[
        if (mood == 'stressed') 'stress_overload',
        if (lowered.contains('stuck')) 'execution_stall',
      ],
      blindSpots: <String>[
        if (lowered.contains('all or nothing')) 'perfectionism_pattern',
      ],
      gentleNavigation:
          'Validate emotion, reduce scope, and choose one concrete action.',
    );
  }
}
