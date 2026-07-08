// lib/engine/si/si_self_consistency_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIResponseCandidate {
  const SIResponseCandidate({
    required this.message,
    required this.action,
    required this.confidence,
    this.safe = true,
  });

  final String message;
  final String action;
  final double confidence;
  final bool safe;
}

class ConsistencyResult {
  const ConsistencyResult({
    required this.consistent,
    required this.score,
    required this.issues,
    required this.preferredMessage,
    required this.preferredAction,
  });

  final bool consistent;
  final double score;
  final List<String> issues;
  final String preferredMessage;
  final String preferredAction;
}

class SISelfConsistencyEngine {
  const SISelfConsistencyEngine();

  ConsistencyResult check({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SICognitionState cognition,
    SIDecision? decision,
    SIResponse? response,
  }) {
    final List<String> issues = <String>[];
    final String action =
        decision?.action ?? _expectedAction(intent.primary.label);
    final String message = siClean(response?.message ?? decision?.reasoning);

    if (decision != null &&
        action != _expectedAction(intent.primary.label) &&
        intent.confidence >= 0.7) {
      issues.add('action_does_not_match_high_confidence_intent');
    }

    if (instinct.safetyFirst &&
        action != 'respond_conversationally' &&
        cognition.meta.misunderstandingRisk >= 0.65) {
      issues.add('safety_first_with_risky_action');
    }

    if (message.isEmpty) issues.add('empty_message');

    if (message.toLowerCase().contains('high-energy') &&
        context.userState.fatigue >= 0.7) {
      issues.add('energy_language_conflicts_with_fatigue');
    }

    if ((context.userState.emotion == 'stressed' || instinct.avoidOverwhelm) &&
        message.length > 320) {
      issues.add('message_too_long_for_state');
    }

    final double score = siClamp01(1 - issues.length * 0.18);

    return ConsistencyResult(
      consistent: issues.isEmpty || score >= 0.72,
      score: score,
      issues: List<String>.unmodifiable(issues),
      preferredMessage: _preferredMessage(
        original: message,
        instinct: instinct,
        consistent: issues.isEmpty,
      ),
      preferredAction: score < 0.55 ? 'respond_conversationally' : action,
    );
  }

  SIResponseCandidate chooseBest(List<SIResponseCandidate> candidates) {
    final List<SIResponseCandidate> safe = candidates
        .where((SIResponseCandidate c) {
          return c.safe && siClean(c.message).isNotEmpty;
        })
        .toList(growable: false);

    if (safe.isEmpty) {
      return const SIResponseCandidate(
        message:
            'Tell me what you want to work on, and I’ll help with one next step.',
        action: 'respond_conversationally',
        confidence: 0.5,
      );
    }

    safe.sort((SIResponseCandidate a, SIResponseCandidate b) {
      return siClamp01(b.confidence).compareTo(siClamp01(a.confidence));
    });

    return safe.first;
  }

  String _expectedAction(String intent) {
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

  String _preferredMessage({
    required String original,
    required InstinctGuidance instinct,
    required bool consistent,
  }) {
    if (consistent && original.isNotEmpty) return original;

    if (instinct.safetyFirst) {
      return 'Let’s keep it simple: choose one small next step.';
    }

    return siClean(
      original,
      fallback: 'I need a little more context before acting.',
    );
  }
}
