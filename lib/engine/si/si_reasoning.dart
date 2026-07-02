class AgentNote {
  const AgentNote({required this.agent, required this.note});

  final String agent;
  final String note;
}

class ReasoningTrace {
  const ReasoningTrace({
    required this.plan,
    required this.evaluate,
    required this.refine,
    required this.notes,
  });

  final String plan;
  final String evaluate;
  final String refine;
  final List<AgentNote> notes;
}

class ReasoningLayer {
  const ReasoningLayer();

  ReasoningTrace run({
    required String intent,
    required String mood,
    required String input,
  }) {
    final String plan = 'Prioritize intent=$intent with mood=$mood';
    final String evaluate = input.isEmpty
        ? 'Low context, ask follow-up'
        : 'Sufficient context for action';
    final String refine = mood == 'confused'
        ? 'Increase clarity and step-by-step guidance'
        : 'Keep concise';

    return ReasoningTrace(
      plan: plan,
      evaluate: evaluate,
      refine: refine,
      notes: <AgentNote>[
        AgentNote(agent: 'planner', note: plan),
        AgentNote(agent: 'critic', note: evaluate),
        AgentNote(agent: 'helper', note: refine),
        const AgentNote(
          agent: 'memory_agent',
          note: 'Check recent memory relevance and recency',
        ),
        const AgentNote(
          agent: 'ui_agent',
          note: 'Select UI component priority for current intent',
        ),
      ],
    );
  }
}
