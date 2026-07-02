class ArchetypeFusion {
  const ArchetypeFusion({
    required this.primary,
    required this.secondary,
    required this.blend,
    required this.style,
  });

  final String primary;
  final String secondary;
  final String blend;
  final String style;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'primary': primary,
      'secondary': secondary,
      'blend': blend,
      'style': style,
    };
  }
}

class SyntheticArchetypeFusionSystem {
  const SyntheticArchetypeFusionSystem();

  ArchetypeFusion fuse({
    required String archetype,
    required String intent,
    required String mood,
  }) {
    if (archetype == 'strategist' && mood == 'stressed') {
      return const ArchetypeFusion(
        primary: 'guardian',
        secondary: 'strategist',
        blend: 'guardian_strategist',
        style: 'safe_and_structured',
      );
    }
    if (intent == 'insight_request') {
      return const ArchetypeFusion(
        primary: 'companion',
        secondary: 'analyst',
        blend: 'companion_analyst',
        style: 'warm_diagnostic',
      );
    }
    return ArchetypeFusion(
      primary: archetype,
      secondary: 'guide',
      blend: '${archetype}_guide',
      style: 'adaptive',
    );
  }
}
