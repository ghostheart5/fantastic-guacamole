class AutonomyPlan {
  const AutonomyPlan({
    required this.proactive,
    required this.suggestions,
    required this.risks,
    required this.opportunities,
    required this.initiativeAction,
  });

  final bool proactive;
  final List<String> suggestions;
  final List<String> risks;
  final List<String> opportunities;
  final String initiativeAction;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'proactive': proactive,
      'suggestions': suggestions,
      'risks': risks,
      'opportunities': opportunities,
      'initiative_action': initiativeAction,
    };
  }
}

class SyntheticAutonomyLayer {
  const SyntheticAutonomyLayer();

  AutonomyPlan plan({
    required String intent,
    required double confidence,
    required bool safe,
  }) {
    final bool proactive = confidence >= 0.6 && safe;
    return AutonomyPlan(
      proactive: proactive,
      suggestions: <String>[
        if (intent == 'get_task') 'Suggest a high-impact next task.',
        if (intent == 'start_focus') 'Offer immediate timer-start action.',
      ],
      risks: <String>[if (!safe) 'safety_alignment_risk'],
      opportunities: <String>[if (proactive) 'momentum_window_open'],
      initiativeAction: proactive
          ? 'propose_next_step'
          : 'wait_for_confirmation',
    );
  }
}
