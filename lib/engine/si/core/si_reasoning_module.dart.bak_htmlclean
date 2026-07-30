// lib/engine/si/core/si_reasoning_module.dart

import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/engine/si/prediction_engine.dart';

class SIReasoningModule {
  SIReasoningModule({PredictionEngine? predictionEngine})
    : _predictionEngine = predictionEngine ?? const PredictionEngine();

  final PredictionEngine _predictionEngine;

  SICognitionState process({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    List<NeuralEntry> history = const <NeuralEntry>[],
    String task = '',
  }) {
    final String label = intent.primary.label;
    final String input = context.input.text.trim();
    final double confidence = siClamp01(intent.confidence);

    final ReasoningTrace trace = ReasoningTrace(
      plan: _plan(label, instinct),
      evaluate: _evaluate(input, confidence, context, instinct),
      refine: _refine(context, instinct, confidence),
      notes: <AgentNote>[
        AgentNote(agent: 'planner', note: _plan(label, instinct)),
        AgentNote(
          agent: 'critic',
          note: _evaluate(input, confidence, context, instinct),
        ),
        AgentNote(
          agent: 'helper',
          note: _refine(context, instinct, confidence),
        ),
        AgentNote(agent: 'instinct_guard', note: instinct.primaryInstinct),
      ],
    );

    final MetaReasoning meta = _meta(context, intent, instinct, confidence);
    final SIPrediction prediction = _predict(history: history, task: task);
    final String summary = _compress(
      '${trace.plan}. ${trace.evaluate}. ${trace.refine}. Prediction: ${prediction.outcome}.',
    );

    return SICognitionState(
      trace: trace,
      meta: meta,
      prediction: prediction,
      summary: summary,
    );
  }

  String _plan(String intent, InstinctGuidance instinct) {
    if (instinct.safetyFirst) return 'Stabilize before recommending action';
    switch (intent) {
      case 'start_focus':
        return 'Prepare one clear focus-session starting step';
      case 'get_task':
        return 'Recommend the most useful next task';
      case 'reflect':
        return 'Guide a short reflection on recent activity';
      case 'insight_request':
        return 'Surface one practical pattern or insight';
      default:
        return 'Answer conversationally and guide toward one next action';
    }
  }

  String _evaluate(
    String input,
    double confidence,
    SIContext context,
    InstinctGuidance instinct,
  ) {
    if (input.isEmpty) return 'Input is empty, clarification is needed';
    if (confidence < 0.55 || instinct.reduceConfusion) {
      return 'Intent confidence is limited, verify before acting';
    }
    if (instinct.avoidOverwhelm ||
        context.userState.cognitiveLoad >= 0.7 ||
        context.userState.stress >= 0.65) {
      return 'User state suggests overload risk, reduce complexity';
    }
    return 'Context is sufficient for concise guidance';
  }

  String _refine(
    SIContext context,
    InstinctGuidance instinct,
    double confidence,
  ) {
    if (confidence < 0.5 || instinct.reduceConfusion) {
      return 'Ask one short clarification question or offer a safe default';
    }
    if (instinct.avoidOverwhelm) return 'Use one small step';
    if (context.userState.emotion == 'confused') {
      return 'Use step-by-step language';
    }
    return 'Keep it concise, supportive, and action-focused';
  }

  MetaReasoning _meta(
    SIContext context,
    SIIntent intent,
    InstinctGuidance instinct,
    double confidence,
  ) {
    final double risk =
        ((1 - confidence) * 0.45 +
                (instinct.reduceConfusion ? 0.2 : 0) +
                (instinct.avoidOverwhelm ? 0.15 : 0) +
                siClamp01(context.userState.stress) * 0.1 +
                siClamp01(context.userState.cognitiveLoad) * 0.1)
            .clamp(0.0, 1.0)
            .toDouble();

    final bool ask = risk >= 0.62 || (confidence < 0.5 && intent.isComplex);
    final bool slow =
        instinct.safetyFirst ||
        instinct.avoidOverwhelm ||
        context.userState.stress >= 0.65 ||
        context.userState.cognitiveLoad >= 0.7;

    return MetaReasoning(
      misunderstandingRisk: risk,
      askClarification: ask,
      slowDown: slow,
      switchPersona:
          intent.primary.label == 'insight_request' &&
          (instinct.reduceConfusion || context.userState.emotion == 'confused'),
      adjustTone: ask || slow || instinct.maintainEmotionalSafety,
      rationale: ask
          ? 'Clarification improves precision.'
          : slow
          ? 'Slow down because overload risk is present.'
          : 'Confidence is adequate for direct guidance.',
    );
  }

  SIPrediction _predict({
    required List<NeuralEntry> history,
    required String task,
  }) {
    final Prediction p = _predictionEngine.predict(
      history: history,
      task: task,
    );
    return SIPrediction(
      outcome: siClean(p.outcome, fallback: 'Unknown outcome'),
      probability: siClamp01(p.probability),
      explanation: siClean(p.explanation, fallback: 'Prediction unavailable.'),
    );
  }

  String _compress(String text, {int maxChars = 220}) {
    final int limit = maxChars < 80 ? 80 : maxChars;
    final String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= limit) return clean;

    final StringBuffer out = StringBuffer();
    for (final RegExpMatch m in RegExp(r'[^.!?]+[.!?]?').allMatches(clean)) {
      final String sentence = m.group(0)?.trim() ?? '';
      if (sentence.isEmpty) continue;
      final String next = out.isEmpty
          ? sentence
          : '${out.toString()} $sentence';
      if (next.length > limit) break;
      if (out.isNotEmpty) out.write(' ');
      out.write(sentence);
    }

    if (out.toString().length >= 40) return out.toString();
    final String cut = clean.substring(0, limit).trim();
    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
