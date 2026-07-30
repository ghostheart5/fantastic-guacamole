// lib/engine/si/si_cognitive_fractal_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

class FractalInsight {
  const FractalInsight({
    required this.scale,
    required this.insight,
    required this.action,
    required this.confidence,
  });

  final String scale;
  final String insight;
  final String action;
  final double confidence;
}

class FractalRefinement {
  const FractalRefinement({
    required this.insights,
    required this.primaryAction,
    required this.memory,
  });

  final List<FractalInsight> insights;
  final String primaryAction;
  final SIMemoryStore memory;
}

class SICognitiveFractalLayer {
  const SICognitiveFractalLayer();

  FractalRefinement refine({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    MicroPatternReport? patterns,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final bool simple = instinct.safetyFirst || instinct.avoidOverwhelm;

    final List<FractalInsight> insights = <FractalInsight>[
      FractalInsight(
        scale: 'micro',
        insight: _micro(context, intent),
        action: 'Choose one immediate action.',
        confidence: intent.confidence,
      ),
      if (!simple)
        FractalInsight(
          scale: 'meso',
          insight: _meso(patterns),
          action: 'Shape the next short block around the strongest pattern.',
          confidence: _patternConfidence(patterns),
        ),
      if (!simple)
        FractalInsight(
          scale: 'macro',
          insight: _macro(context),
          action:
              'Protect the broader planning loop without overloading today.',
          confidence: 0.55,
        ),
    ];

    final String primary = insights.first.action;

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'fractal|${insights.map((FractalInsight i) => '${i.scale}:${i.insight}').join('|')}',
            timestamp: timestamp,
            relevance: insights.first.confidence,
            confidence: 0.68,
            emotionalWeight: simple ? 0.6 : 0.35,
            reinforcement: simple ? 0 : 1,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return FractalRefinement(
      insights: List<FractalInsight>.unmodifiable(insights),
      primaryAction: primary,
      memory: nextMemory,
    );
  }

  String _micro(SIContext context, SIIntent intent) {
    if (intent.primary.label == 'get_task') {
      return 'The immediate need is task selection.';
    }
    if (intent.primary.label == 'start_focus') {
      return 'The immediate need is focus protection.';
    }
    if (context.userState.cognitiveLoad >= 0.7) {
      return 'The immediate need is simplification.';
    }
    return 'The immediate need is one clear next step.';
  }

  String _meso(MicroPatternReport? patterns) {
    if (patterns == null || patterns.patterns.isEmpty) {
      return 'No strong mid-scale pattern yet.';
    }
    return patterns.patterns.first.label;
  }

  String _macro(SIContext context) {
    if (context.userState.motivation >= 0.65) {
      return 'The broader loop supports momentum.';
    }
    if (context.userState.fatigue >= 0.65) {
      return 'The broader loop needs recovery pacing.';
    }
    return 'The broader loop is still stabilizing.';
  }

  double _patternConfidence(MicroPatternReport? patterns) {
    if (patterns == null || patterns.patterns.isEmpty) return 0.35;
    return siClamp01(patterns.patterns.first.confidence);
  }
}
