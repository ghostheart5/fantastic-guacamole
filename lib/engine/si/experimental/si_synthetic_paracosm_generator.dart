class Paracosm {
  const Paracosm({
    required this.realm,
    required this.lore,
    required this.characters,
    required this.abilities,
    required this.timeline,
    required this.artifacts,
  });

  final String realm;
  final String lore;
  final List<String> characters;
  final List<String> abilities;
  final String timeline;
  final List<String> artifacts;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'realm': realm,
      'lore': lore,
      'characters': characters,
      'abilities': abilities,
      'timeline': timeline,
      'artifacts': artifacts,
    };
  }
}

class SyntheticParacosmGenerator {
  const SyntheticParacosmGenerator();

  Paracosm generate({required String appContext, required String intent}) {
    final String realm = appContext.contains('chrono')
        ? 'Chrono Citadel'
        : 'Astral Nexus';
    return Paracosm(
      realm: realm,
      lore:
          'A living multiverse where focus, creativity, and reflection are linked energies.',
      characters: <String>['The Guide', 'The Architect', 'The Echo Keeper'],
      abilities: <String>[
        'timeline shaping',
        'signal amplification',
        'memory weaving',
      ],
      timeline: intent == 'start_focus' ? 'Execution Epoch' : 'Synthesis Epoch',
      artifacts: <String>['Pulse Compass', 'Resonance Core', 'Memory Prism'],
    );
  }
}
