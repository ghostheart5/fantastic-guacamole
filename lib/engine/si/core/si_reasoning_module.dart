// Module 5 — Reasoning
// Pipeline step: SIContext + SIIntent + InstinctGuidance → SICognitionState
// Merges: si_reasoning + si_meta_reasoning + prediction_engine + si_thought_compression

import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/core/si_instinct_module.dart';

// ─── Data contracts ───────────────────────────────────────────────────────────

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

class MetaReasoning {
  const MetaReasoning({
    required this.misunderstandingRisk,
    required this.askClarification,
    required this.slowDown,
    required this.switchPersona,
    required this.adjustTone,
    required this.rationale,
  });

  final double misunderstandingRisk;
  final bool askClarification;
  final bool slowDown;
  final bool switchPersona;
  final bool adjustTone;
  final String rationale;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'misunderstanding_risk': misunderstandingRisk,
    'ask_clarification': askClarification,
    'slow_down': slowDown,
    'switch_persona': switchPersona,
    'adjust_tone': adjustTone,
    'rationale': rationale,
  };
}

class SIPrediction {
  const SIPrediction({
    required this.outcome,
    required this.probability,
    required this.explanation,
  });

  final String outcome;
  final double probability;
  final String explanation;
}

class SICognitionState {
  const SICognitionState({
    required this.trace,
    required this.meta,
    required this.prediction,
    required this.summary,
  });

  final ReasoningTrace trace;
  final MetaReasoning meta;
  final SIPrediction prediction;
  final String summary;
}

// ─── Module ───────────────────────────────────────────────────────────────────

class SIReasoningModule {
  const SIReasoningModule();

  SICognitionState process({
    required String intent,
    required String mood,
    required String input,
    required bool anticipatesConfusion,
    required double confidence,
    List<NeuralEntry> history = const <NeuralEntry>[],
    String task = '',
  }) {
    final ReasoningTrace trace = _reason(
      intent: intent,
      mood: mood,
      input: input,
    );
    final MetaReasoning meta = _metaReason(
      confidence: confidence,
      anticipatesConfusion: anticipatesConfusion,
      mood: mood,
      intent: intent,
    );
    final SIPrediction prediction = _predict(history: history, task: task);
    final String summary = _compress(
      '${trace.plan}. ${trace.evaluate}. ${trace.refine}.',
    );

    return SICognitionState(
      trace: trace,
      meta: meta,
      prediction: prediction,
      summary: summary,
    );
  }

  ReasoningTrace _reason({
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

  MetaReasoning _metaReason({
    required double confidence,
    required bool anticipatesConfusion,
    required String mood,
    required String intent,
  }) {
    final double risk =
        ((1 - confidence) * 0.7 + (anticipatesConfusion ? 0.3 : 0.0)).clamp(
          0.0,
          1.0,
        );
    final bool ask = risk > 0.45;
    final bool slow = mood == 'stressed' || mood == 'confused';
    final bool switchPersona =
        intent == 'insight_request' && mood == 'confused';

    return MetaReasoning(
      misunderstandingRisk: risk,
      askClarification: ask,
      slowDown: slow,
      switchPersona: switchPersona,
      adjustTone: slow || ask,
      rationale: ask
          ? 'High ambiguity detected; clarification improves precision.'
          : 'Reasoning confidence is adequate for direct guidance.',
    );
  }

  SIPrediction _predict({
    required List<NeuralEntry> history,
    required String task,
  }) {
    if (history.isEmpty) {
      return const SIPrediction(
        outcome: 'Unknown outcome',
        probability: 0.5,
        explanation: 'Not enough data yet.',
      );
    }

    final List<NeuralEntry> matches =
        history.where((NeuralEntry e) => e.task == task).toList();

    if (matches.isEmpty) {
      return const SIPrediction(
        outcome: 'No past data for this task',
        probability: 0.5,
        explanation: 'First time attempting this.',
      );
    }

    final double avgQuality =
        matches.map((NeuralEntry e) => e.quality).reduce((a, b) => a + b) /
        matches.length;

    return SIPrediction(
      outcome: avgQuality > 0.7
          ? 'High chance of successful focus'
          : 'Moderate difficulty expected',
      probability: avgQuality.clamp(0.0, 1.0),
      explanation: 'Based on previous sessions with this task.',
    );
  }

  String _compress(String reasoning, {int maxChars = 220}) {
    final String text = reasoning.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= maxChars) return text;
    final String shortened = text.substring(0, maxChars);
    final int lastPeriod = shortened.lastIndexOf('.');
    if (lastPeriod > 80) return shortened.substring(0, lastPeriod + 1);
    return '$shortened...';
  }

  // ─── Task decomposition ────────────────────────────────────────────────────

  List<String> decomposeGoal(String goal, InstinctGuidance instinct) {
    if (instinct.avoidOverwhelm) {
      return <String>['Start with the smallest part of: $goal'];
    }
    return <String>[
      'Define the scope of: $goal',
      'Identify the first concrete action',
      'Complete one focused session on it',
    ];
  }
}
