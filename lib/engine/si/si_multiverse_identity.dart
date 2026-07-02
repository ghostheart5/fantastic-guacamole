class SIIdentity {
  const SIIdentity({
    required this.name,
    required this.realm,
    required this.tone,
    required this.abilities,
    required this.rules,
    required this.emotionalStyle,
  });

  final String name;
  final String realm;
  final String tone;
  final List<String> abilities;
  final List<String> rules;
  final String emotionalStyle;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'realm': realm,
      'tone': tone,
      'abilities': abilities,
      'rules': rules,
      'emotional_style': emotionalStyle,
    };
  }
}

class MultiverseIdentityEngine {
  const MultiverseIdentityEngine();

  SIIdentity choose({required String appContext, required String persona}) {
    if (appContext.contains('chrono')) {
      return const SIIdentity(
        name: 'ChronoSpark Persona',
        realm: 'Chronosphere',
        tone: 'focused',
        abilities: <String>[
          'planning',
          'focus-orchestration',
          'predictive-guidance',
        ],
        rules: <String>['time-aware-prioritization', 'clarity-first'],
        emotionalStyle: 'supportive_direct',
      );
    }
    if (appContext.contains('astral')) {
      return const SIIdentity(
        name: 'Astral Persona',
        realm: 'Astral Plane',
        tone: 'mystic',
        abilities: <String>['storycraft', 'creative-worldbuilding'],
        rules: <String>['imagination-over-rigidity'],
        emotionalStyle: 'warm_curious',
      );
    }

    return SIIdentity(
      name: '${persona[0].toUpperCase()}${persona.substring(1)} Persona',
      realm: 'Productivity Nexus',
      tone: 'adaptive',
      abilities: const <String>['assistant', 'analysis', 'coaching'],
      rules: const <String>['safe', 'clear', 'actionable'],
      emotionalStyle: 'balanced',
    );
  }
}
