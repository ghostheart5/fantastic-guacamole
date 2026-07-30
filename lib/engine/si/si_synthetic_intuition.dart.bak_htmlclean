// lib/engine/si/si_synthetic_intuition.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_attention_system.dart';

class IntuitionSignal {
  const IntuitionSignal({
    required this.label,
    required this.score,
    required this.reason,
  });

  final String label;
  final double score;
  final String reason;
}

class SyntheticIntuitionResult {
  const SyntheticIntuitionResult({
    required this.score,
    required this.confidence,
    required this.signals,
    required this.recommendation,
    required this.memory,
  });

  final double score;
  final double confidence;
  final List<IntuitionSignal> signals;
  final String recommendation;
  final SIMemoryStore memory;
}

class SISyntheticIntuition {
  const SISyntheticIntuition();

  SyntheticIntuitionResult evaluate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    Prediction? prediction,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
    AttentionProfile? attention,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final List<IntuitionSignal> signals = <IntuitionSignal>[
      IntuitionSignal(
        label: 'intent_confidence',
        score: intent.confidence,
        reason: 'Confidence in detected intent.',
      ),
      IntuitionSignal(
        label: 'state_readiness',
        score: _readiness(context),
        reason: 'User state supports action.',
      ),
      IntuitionSignal(
        label: 'instinct_clearance',
        score: instinct.safetyFirst ? 0.25 : 0.72,
        reason: 'Instinct allows or limits movement.',
      ),
    ];

    if (prediction != null) {
      signals.add(
        IntuitionSignal(
          label: 'prediction_probability',
          score: prediction.safeProbability,
          reason: prediction.explanation,
        ),
      );
    }

    if (patterns != null) {
      signals.add(
        IntuitionSignal(
          label: 'pattern_strength',
          score: patterns.hasStrongPattern
              ? patterns.patterns.first.strength
              : 0.45,
          reason: patterns.summary,
        ),
      );
    }

    if (learning != null) {
      signals.add(
        IntuitionSignal(
          label: 'adaptive_focus',
          score: learning.focusReadiness,
          reason: 'Adaptive learning focus readiness.',
        ),
      );
    }

    if (attention != null) {
      signals.add(
        IntuitionSignal(
          label: 'attention_focus',
          score: attention.focusScore,
          reason: attention.primaryFocus,
        ),
      );
    }

    final double score = siClamp01(
      signals.fold<double>(
            0,
            (double sum, IntuitionSignal s) => sum + siClamp01(s.score),
          ) /
          signals.length,
    );

    final double confidence = siClamp01(
      0.35 + (signals.length.clamp(0, 6) * 0.08) + (score * 0.2),
    );

    final String recommendation = _recommendation(score, instinct, context);

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'synthetic_intuition|score=${score.toStringAsFixed(2)}|$recommendation',
            timestamp: timestamp,
            relevance: score,
            confidence: confidence,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: score >= 0.7 ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return SyntheticIntuitionResult(
      score: score,
      confidence: confidence,
      signals: List<IntuitionSignal>.unmodifiable(signals),
      recommendation: recommendation,
      memory: nextMemory,
    );
  }

  double _readiness(SIContext context) {
    final SIUserState u = context.userState;
    return siClamp01(
      (u.motivation + u.engagement + (1 - u.fatigue) + (1 - u.stress)) / 4,
    );
  }

  String _recommendation(
    double score,
    InstinctGuidance instinct,
    SIContext context,
  ) {
    if (instinct.safetyFirst || context.userState.stress >= 0.7) {
      return 'Use a safe, low-pressure response.';
    }
    if (score >= 0.72) return 'Proceed with concise action guidance.';
    if (score >= 0.5) return 'Proceed carefully with one clear next step.';
    return 'Ask for clarification or offer a safe default.';
  }
}
