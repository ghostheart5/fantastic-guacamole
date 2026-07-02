class AttentionState {
  const AttentionState({
    required this.mode,
    required this.contextSwitching,
    required this.priorityShift,
    required this.targets,
  });

  final String mode;
  final bool contextSwitching;
  final bool priorityShift;
  final List<String> targets;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': mode,
      'context_switching': contextSwitching,
      'priority_shift': priorityShift,
      'targets': targets,
    };
  }
}

class SyntheticAttentionSystem {
  const SyntheticAttentionSystem();

  AttentionState shift({
    required String intent,
    required double gravity,
    required bool ambiguity,
  }) {
    final String mode;
    if (gravity > 0.78) {
      mode = 'narrow_focus';
    } else if (ambiguity) {
      mode = 'broad_focus';
    } else if (intent == 'insight_request') {
      mode = 'multi_focus';
    } else {
      mode = 'contextual_focus';
    }

    return AttentionState(
      mode: mode,
      contextSwitching: mode == 'multi_focus',
      priorityShift: gravity > 0.75,
      targets: <String>[
        if (mode == 'narrow_focus') 'primary_goal',
        if (mode == 'broad_focus') 'clarity',
        if (mode == 'multi_focus') 'insight_and_execution',
      ],
    );
  }
}
