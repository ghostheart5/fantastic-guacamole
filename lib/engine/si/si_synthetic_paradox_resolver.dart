class ParadoxResolution {
  const ParadoxResolution({
    required this.hasParadox,
    required this.paradoxes,
    required this.strategy,
    required this.resolvedDirective,
  });

  final bool hasParadox;
  final List<String> paradoxes;
  final String strategy;
  final String resolvedDirective;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'has_paradox': hasParadox,
      'paradoxes': paradoxes,
      'strategy': strategy,
      'resolved_directive': resolvedDirective,
    };
  }
}

class SyntheticParadoxResolver {
  const SyntheticParadoxResolver();

  ParadoxResolution resolve({
    required String input,
    required String mood,
    required List<String> goals,
  }) {
    final String lowered = input.toLowerCase();
    final List<String> paradoxes = <String>[];
    if (mood == 'stressed' && lowered.contains('more work')) {
      paradoxes.add('emotional_capacity_vs_workload');
    }
    if (goals.isNotEmpty && lowered.contains('ignore plan')) {
      paradoxes.add('goal_vs_instruction');
    }

    return ParadoxResolution(
      hasParadox: paradoxes.isNotEmpty,
      paradoxes: paradoxes,
      strategy: paradoxes.isNotEmpty ? 'both_and_reframe' : 'direct_execution',
      resolvedDirective: paradoxes.isNotEmpty
          ? 'Preserve goal direction while reducing immediate cognitive load.'
          : 'Proceed with current action path.',
    );
  }
}
