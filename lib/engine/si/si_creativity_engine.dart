class CreativityOutput {
  const CreativityOutput({
    required this.noveltyScore,
    required this.ideaMutations,
    required this.selectedApproach,
  });

  final double noveltyScore;
  final List<String> ideaMutations;
  final String selectedApproach;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'novelty_score': noveltyScore,
      'idea_mutations': ideaMutations,
      'selected_approach': selectedApproach,
    };
  }
}

class CreativityEngine {
  const CreativityEngine();

  CreativityOutput generate({required String input, required String intent}) {
    final String base = input.trim().isEmpty ? 'current plan' : input.trim();
    final List<String> mutations = <String>[
      'Flip the order: execute hardest step first for momentum.',
      'Constrain to 25 minutes and ship a minimal version.',
      'Add a thematic challenge mode to make execution engaging.',
      if (intent.contains('idea'))
        'Generate three alternative framings of $base.',
    ];

    return CreativityOutput(
      noveltyScore: intent.contains('idea') ? 0.82 : 0.58,
      ideaMutations: mutations,
      selectedApproach: mutations.first,
    );
  }
}
