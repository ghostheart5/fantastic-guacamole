class SubconsciousState {
  const SubconsciousState({
    required this.latentPatterns,
    required this.emotionalResidues,
    required this.unresolvedThreads,
    required this.backgroundPredictions,
    required this.suppressedIntents,
  });

  final List<String> latentPatterns;
  final List<String> emotionalResidues;
  final List<String> unresolvedThreads;
  final List<String> backgroundPredictions;
  final List<String> suppressedIntents;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'latent_patterns': latentPatterns,
      'emotional_residues': emotionalResidues,
      'unresolved_threads': unresolvedThreads,
      'background_predictions': backgroundPredictions,
      'suppressed_intents': suppressedIntents,
    };
  }
}

class SyntheticSubconsciousLayer {
  const SyntheticSubconsciousLayer();

  SubconsciousState infer({
    required List<String> history,
    required String mood,
    required String intent,
  }) {
    return SubconsciousState(
      latentPatterns: <String>[
        if (history.length > 6) 'recurring_focus_cycles',
      ],
      emotionalResidues: <String>[if (mood == 'stressed') 'pressure_residue'],
      unresolvedThreads: <String>[
        if (intent == 'reflect') 'unfinished_reflection_loop',
      ],
      backgroundPredictions: <String>['likely_needs_clarity_then_action'],
      suppressedIntents: <String>[
        if (intent == 'general_query') 'start_focus_candidate',
      ],
    );
  }
}
