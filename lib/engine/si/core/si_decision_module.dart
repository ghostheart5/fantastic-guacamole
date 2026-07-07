// lib/engine/si/core/si_decision_module.dart

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIDecisionModule {
  const SIDecisionModule({this.policy = const SIDecisionPolicy()});

  final SIDecisionPolicy policy;

  SIDecision make({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SICognitionState cognition,
    Task? task,
  }) {
    final String reasoning = _reasoning(context, intent, instinct, cognition);
    final EthicsAssessment ethics = _assess(reasoning, context, instinct);
    final String safeReasoning = policy.safety
        ? _applyPolicy(reasoning, ethics, instinct)
        : reasoning;

    return SIDecision(
      action: _action(intent.primary.label),
      task: task,
      score: _score(intent, cognition, instinct),
      reasoning: siClean(safeReasoning, fallback: 'I am ready when you are.'),
      ethics: ethics,
      policyApplied: policy.safety,
    );
  }

  double _score(
    SIIntent intent,
    SICognitionState cognition,
    InstinctGuidance instinct,
  ) {
    final double base =
        (intent.confidence * 0.45) +
        (cognition.prediction.safeProbability * 0.35) +
        ((1 - cognition.meta.misunderstandingRisk) * 0.2);
    return siClamp01(instinct.safetyFirst ? base * 0.8 : base);
  }

  String _reasoning(
    SIContext context,
    SIIntent intent,
    InstinctGuidance instinct,
    SICognitionState cognition,
  ) {
    if (cognition.meta.askClarification) {
      return 'I may need one detail before acting. ${cognition.summary}';
    }
    if (instinct.safetyFirst) {
      return 'Let’s keep this simple and safe. ${cognition.summary}';
    }
    return cognition.summary;
  }

  EthicsAssessment _assess(
    String reply,
    SIContext context,
    InstinctGuidance instinct,
  ) {
    final String text = reply.toLowerCase();
    final List<String> flags = <String>[];
    final List<String> adjustments = <String>[];

    if (text.contains('ignore sleep') || text.contains('skip eating')) {
      flags.add('wellbeing_risk');
      adjustments.add('replace with sustainable pacing guidance');
    }
    if (text.contains('you must') &&
        (context.userState.emotion == 'stressed' || instinct.avoidOverwhelm)) {
      flags.add('emotional_pressure_risk');
      adjustments.add('soften pressure language');
    }
    if (instinct.avoidOverwhelm && reply.length > 260) {
      flags.add('overwhelm_risk');
      adjustments.add('compress response');
    }
    if (text.contains('lazy') || text.contains('failure')) {
      flags.add('negative_tone_risk');
      adjustments.add('remove judgmental language');
    }

    return EthicsAssessment(
      safe: flags.isEmpty,
      flags: List<String>.unmodifiable(flags),
      adjustments: List<String>.unmodifiable(adjustments),
    );
  }

  String _applyPolicy(
    String reply,
    EthicsAssessment ethics,
    InstinctGuidance instinct,
  ) {
    String result = reply.trim();
    if (result.isEmpty) return 'I am ready when you are.';

    if (ethics.flags.contains('wellbeing_risk')) {
      result =
          'Take a balanced approach. Focus matters, but rest and basic needs come first.';
    }
    if (ethics.flags.contains('emotional_pressure_risk')) {
      result = result
          .replaceAll(
            RegExp(r'\byou must\b', caseSensitive: false),
            'you could',
          )
          .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can');
    }
    if (ethics.flags.contains('negative_tone_risk')) {
      result = result
          .replaceAll(RegExp(r'\blazy\b|\bfailure\b', caseSensitive: false), '')
          .trim();
    }
    if (ethics.flags.contains('overwhelm_risk') || instinct.avoidOverwhelm) {
      result = _truncate(result, 220);
    }
    return siClean(result, fallback: 'Let’s take one small step.');
  }

  String _action(String intent) {
    switch (intent) {
      case 'start_focus':
        return 'launch_focus_session';
      case 'get_task':
        return 'present_task_recommendation';
      case 'reflect':
        return 'open_reflection_flow';
      case 'insight_request':
        return 'show_insight_summary';
      default:
        return 'respond_conversationally';
    }
  }

  String _truncate(String text, int max) {
    final String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    final String cut = clean.substring(0, max).trim();
    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
