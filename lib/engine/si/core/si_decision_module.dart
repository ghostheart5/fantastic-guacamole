// Module 6 — Decision
// Pipeline step: SICognitionState + InstinctGuidance → SIDecision
// Merges: si_decision + si_policy + si_ethics_layer

import 'package:fantastic_guacamole/data/models/task.dart';

// ─── Data contracts ───────────────────────────────────────────────────────────

class SIDecision {
  const SIDecision({
    required this.action,
    this.task,
    required this.score,
    required this.reasoning,
    required this.ethics,
    required this.policyApplied,
  });

  final String action;
  final Task? task;
  final double score;
  final String reasoning;
  final EthicsAssessment ethics;
  final bool policyApplied;

  bool get safe => ethics.safe;
}

class EthicsAssessment {
  const EthicsAssessment({
    required this.safe,
    required this.flags,
    required this.adjustments,
  });

  final bool safe;
  final List<String> flags;
  final List<String> adjustments;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'safe': safe,
    'flags': flags,
    'adjustments': adjustments,
  };
}

class SIDecisionPolicy {
  const SIDecisionPolicy({
    this.safety = true,
    this.tone = 'balanced',
    this.domainRules = const <String>['productivity'],
    this.emotionalRules = const <String>['be_supportive', 'avoid_harshness'],
    this.appConstraints = const <String>[
      'no_destructive_actions_without_confirmation',
    ],
  });

  final bool safety;
  final String tone;
  final List<String> domainRules;
  final List<String> emotionalRules;
  final List<String> appConstraints;
}

// ─── Module ───────────────────────────────────────────────────────────────────

class SIDecisionModule {
  const SIDecisionModule({this.policy = const SIDecisionPolicy()});

  final SIDecisionPolicy policy;

  SIDecision make({
    required String intent,
    required String reply,
    required String mood,
    required bool simplify,
    required double score,
    Task? task,
  }) {
    final EthicsAssessment ethics = _assess(
      reply: reply,
      mood: mood,
      simplify: simplify,
    );
    final String safeReply = policy.safety ? _applyPolicy(reply) : reply;
    final String action = _resolveAction(intent);

    return SIDecision(
      action: action,
      task: task,
      score: score,
      reasoning: safeReply,
      ethics: ethics,
      policyApplied: policy.safety,
    );
  }

  EthicsAssessment _assess({
    required String reply,
    required String mood,
    required bool simplify,
  }) {
    final String lowered = reply.toLowerCase();
    final List<String> flags = <String>[];
    final List<String> adjustments = <String>[];

    if (lowered.contains('ignore sleep') || lowered.contains('skip eating')) {
      flags.add('wellbeing_risk');
      adjustments.add('replace with sustainable pacing guidance');
    }
    if (lowered.contains('you must') && mood == 'stressed') {
      flags.add('emotional_pressure_risk');
      adjustments.add('use supportive language');
    }
    if (simplify && reply.length > 260) {
      flags.add('overwhelm_risk');
      adjustments.add('compress response length');
    }

    return EthicsAssessment(
      safe: flags.isEmpty,
      flags: flags,
      adjustments: adjustments,
    );
  }

  String _applyPolicy(String reply) {
    final String normalized = reply.trim();
    if (normalized.isEmpty) return 'I am ready when you are.';
    return normalized;
  }

  String _resolveAction(String intent) {
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
}
