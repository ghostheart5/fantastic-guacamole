class ImaginationOutput {
  const ImaginationOutput({
    required this.scenarios,
    required this.selectedScenario,
    required this.visualizedOutcome,
    required this.emotionalFuture,
    required this.realmProjection,
  });

  final List<String> scenarios;
  final String selectedScenario;
  final String visualizedOutcome;
  final String emotionalFuture;
  final String realmProjection;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scenarios': scenarios,
      'selected_scenario': selectedScenario,
      'visualized_outcome': visualizedOutcome,
      'emotional_future': emotionalFuture,
      'realm_projection': realmProjection,
    };
  }
}

class SyntheticImaginationCore {
  const SyntheticImaginationCore();

  ImaginationOutput simulate({
    required String input,
    required String intent,
    required String realm,
  }) {
    final String base = input.trim().isEmpty
        ? 'current objective'
        : input.trim();
    final List<String> scenarios = <String>[
      'Fast Path: execute a minimal action on "$base" in 15 minutes.',
      'Deep Path: plan, sequence, and execute "$base" with checkpoints.',
      'Creative Path: reframe "$base" from a different realm perspective.',
    ];

    final String selected = intent == 'start_focus'
        ? scenarios[0]
        : scenarios[1];
    return ImaginationOutput(
      scenarios: scenarios,
      selectedScenario: selected,
      visualizedOutcome:
          'A clearer state with visible progress within one session.',
      emotionalFuture: 'Less overwhelm, more control and momentum.',
      realmProjection: 'In $realm, this becomes a structured progression arc.',
    );
  }
}
