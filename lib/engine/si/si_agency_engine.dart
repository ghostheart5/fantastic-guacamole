class AgencyDecision {
  const AgencyDecision({
    required this.autonomyLevel,
    required this.shouldAct,
    required this.action,
    required this.reason,
    required this.decisionConfidence,
  });

  final String autonomyLevel;
  final bool shouldAct;
  final String action;
  final String reason;
  final double decisionConfidence;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'autonomy_level': autonomyLevel,
      'should_act': shouldAct,
      'action': action,
      'reason': reason,
      'decision_confidence': decisionConfidence,
    };
  }
}

class AgencyEngine {
  const AgencyEngine();

  AgencyDecision decide({
    required String intent,
    required double confidence,
    required bool policyAllows,
  }) {
    final bool actionableIntent =
        intent == 'start_focus' || intent == 'get_task';
    final bool shouldAct =
        actionableIntent && confidence >= 0.55 && policyAllows;

    final String action;
    if (shouldAct && intent == 'start_focus') {
      action = 'suggest_focus_start';
    } else if (shouldAct && intent == 'get_task') {
      action = 'suggest_next_task';
    } else {
      action = 'request_clarification';
    }

    return AgencyDecision(
      autonomyLevel: shouldAct ? 'bounded_autonomous' : 'assistive',
      shouldAct: shouldAct,
      action: action,
      reason: shouldAct
          ? 'Intent is actionable and confidence exceeds threshold.'
          : 'Insufficient confidence or non-actionable intent.',
      decisionConfidence: confidence,
    );
  }
}
