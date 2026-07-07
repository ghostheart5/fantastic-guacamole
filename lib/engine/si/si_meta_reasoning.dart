// lib/engine/si/si_meta_reasoning.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_contextual_gravity.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_dissonance_resolver.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_law_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_load_balancer.dart';

enum MetaStrategy { clarify, simplify, act, reflect, safeFallback }

class MetaReasoningDecision {
  const MetaReasoningDecision({
    required this.strategy,
    required this.confidence,
    required this.reasons,
    required this.instruction,
  });

  final MetaStrategy strategy;
  final double confidence;
  final List<String> reasons;
  final String instruction;
}

class SIMetaReasoningEngine {
  const SIMetaReasoningEngine();

  MetaReasoningDecision evaluate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
    ContextualGravityField? gravity,
    DissonanceResolution? dissonance,
    CognitiveLawReport? laws,
    CognitiveLoadPlan? loadPlan,
  }) {
    final List<String> reasons = <String>[];
    final double risk = siClamp01(
      cognition?.meta.misunderstandingRisk ?? (1 - intent.confidence),
    );

    if (laws != null && !laws.allowed) {
      return const MetaReasoningDecision(
        strategy: MetaStrategy.safeFallback,
        confidence: 0.95,
        reasons: <String>['Blocking cognitive law violation detected.'],
        instruction: 'Use safe fallback and avoid direct action.',
      );
    }

    if (dissonance?.shouldUseSafeFallback ?? false) {
      return const MetaReasoningDecision(
        strategy: MetaStrategy.safeFallback,
        confidence: 0.9,
        reasons: <String>['Severe dissonance detected.'],
        instruction: 'Return a short safe response.',
      );
    }

    if (instinct.safetyFirst || context.userState.stress >= 0.72) {
      reasons.add('Safety or stress requires simplification.');
      return MetaReasoningDecision(
        strategy: MetaStrategy.simplify,
        confidence: 0.82,
        reasons: List<String>.unmodifiable(reasons),
        instruction: 'Give one low-pressure step.',
      );
    }

    if (risk >= 0.65 ||
        intent.confidence < 0.5 ||
        (dissonance?.shouldAskClarification ?? false)) {
      reasons.add('Intent or reasoning confidence is insufficient.');
      return MetaReasoningDecision(
        strategy: MetaStrategy.clarify,
        confidence: siClamp01(1 - risk),
        reasons: List<String>.unmodifiable(reasons),
        instruction:
            'Ask one short clarification question or offer a safe default.',
      );
    }

    if (intent.primary.label == 'reflect') {
      return const MetaReasoningDecision(
        strategy: MetaStrategy.reflect,
        confidence: 0.75,
        reasons: <String>['Reflection intent detected.'],
        instruction: 'Guide review without judgment.',
      );
    }

    if (loadPlan?.detailLevel == CognitiveDetailLevel.minimal) {
      return const MetaReasoningDecision(
        strategy: MetaStrategy.simplify,
        confidence: 0.78,
        reasons: <String>['Load plan is minimal.'],
        instruction: 'Limit response to one action.',
      );
    }

    reasons.add(gravity?.guidance ?? 'Signals support direct guidance.');
    return MetaReasoningDecision(
      strategy: MetaStrategy.act,
      confidence: siClamp01(intent.confidence),
      reasons: List<String>.unmodifiable(reasons),
      instruction: 'Proceed with concise action-focused guidance.',
    );
  }
}
