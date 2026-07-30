// lib/engine/si/si_cognitive_load_balancer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum CognitiveDetailLevel { minimal, compact, normal, expanded }

class CognitiveLoadPlan {
  const CognitiveLoadPlan({
    required this.detailLevel,
    required this.maxWords,
    required this.maxActions,
    required this.useSteps,
    required this.allowSecondarySuggestions,
    required this.reason,
  });

  final CognitiveDetailLevel detailLevel;
  final int maxWords;
  final int maxActions;
  final bool useSteps;
  final bool allowSecondarySuggestions;
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'detail_level': detailLevel.name,
    'max_words': maxWords,
    'max_actions': maxActions,
    'use_steps': useSteps,
    'allow_secondary_suggestions': allowSecondarySuggestions,
    'reason': reason,
  };
}

class SICognitiveLoadBalancer {
  const SICognitiveLoadBalancer();

  CognitiveLoadPlan balance({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
  }) {
    final double load = siClamp01(context.userState.cognitiveLoad);
    final double stress = siClamp01(context.userState.stress);
    final double risk = siClamp01(cognition?.meta.misunderstandingRisk ?? 0.35);
    final bool safety = instinct.safetyFirst || instinct.avoidOverwhelm;

    final double pressure = siClamp01(
      (load * 0.4) + (stress * 0.3) + (risk * 0.2) + (safety ? 0.1 : 0),
    );

    if (pressure >= 0.72) {
      return const CognitiveLoadPlan(
        detailLevel: CognitiveDetailLevel.minimal,
        maxWords: 38,
        maxActions: 1,
        useSteps: true,
        allowSecondarySuggestions: false,
        reason: 'High load or safety-first state detected.',
      );
    }

    if (pressure >= 0.52 || intent.confidence < 0.55) {
      return const CognitiveLoadPlan(
        detailLevel: CognitiveDetailLevel.compact,
        maxWords: 58,
        maxActions: 1,
        useSteps: true,
        allowSecondarySuggestions: false,
        reason: 'Moderate load or uncertainty detected.',
      );
    }

    if (intent.primary.label == 'insight_request' && !safety) {
      return const CognitiveLoadPlan(
        detailLevel: CognitiveDetailLevel.expanded,
        maxWords: 110,
        maxActions: 2,
        useSteps: false,
        allowSecondarySuggestions: true,
        reason: 'Insight request can tolerate more explanation.',
      );
    }

    return const CognitiveLoadPlan(
      detailLevel: CognitiveDetailLevel.normal,
      maxWords: 78,
      maxActions: 2,
      useSteps: false,
      allowSecondarySuggestions: true,
      reason: 'Normal guidance load.',
    );
  }

  String enforceWordLimit(String message, CognitiveLoadPlan plan) {
    final List<String> words = message
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ');
    if (words.length <= plan.maxWords) return message.trim();

    final String trimmed = words.take(plan.maxWords).join(' ');
    return trimmed.endsWith('.') ? trimmed : '$trimmed...';
  }
}
