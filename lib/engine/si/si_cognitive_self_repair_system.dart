class SelfRepairReport {
  const SelfRepairReport({
    required this.issues,
    required this.requiredRepair,
    required this.actions,
  });

  final List<String> issues;
  final bool requiredRepair;
  final List<String> actions;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'issues': issues,
      'required_repair': requiredRepair,
      'actions': actions,
    };
  }
}

class CognitiveSelfRepairSystem {
  const CognitiveSelfRepairSystem();

  SelfRepairReport inspect({
    required bool emotionalMismatch,
    required bool personaInstability,
    required bool memoryConflict,
    required bool lowReasoning,
    required bool contextMisalignment,
  }) {
    final List<String> issues = <String>[
      if (emotionalMismatch) 'emotional_drift',
      if (personaInstability) 'persona_instability',
      if (memoryConflict) 'memory_conflict',
      if (lowReasoning) 'reasoning_error_risk',
      if (contextMisalignment) 'context_misalignment',
    ];
    return SelfRepairReport(
      issues: issues,
      requiredRepair: issues.isNotEmpty,
      actions: <String>[
        if (issues.contains('emotional_drift')) 'recalibrate_emotional_stance',
        if (issues.contains('persona_instability')) 'stabilize_persona_anchor',
        if (issues.contains('memory_conflict')) 'reconcile_memory_paths',
        if (issues.contains('reasoning_error_risk'))
          'tighten_reasoning_constraints',
        if (issues.contains('context_misalignment')) 'refresh_hyper_context',
      ],
    );
  }
}
