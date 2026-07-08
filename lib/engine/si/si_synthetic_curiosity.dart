// lib/engine/si/si_synthetic_curiosity.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_attention_system.dart';

class CuriosityPrompt {
  const CuriosityPrompt({
    required this.text,
    required this.reason,
    required this.confidence,
    required this.safeToShow,
  });

  final String text;
  final String reason;
  final double confidence;
  final bool safeToShow;
}

class SyntheticCuriosityResult {
  const SyntheticCuriosityResult({required this.prompt, required this.memory});

  final CuriosityPrompt? prompt;
  final SIMemoryStore memory;
}

class SISyntheticCuriosity {
  const SISyntheticCuriosity();

  SyntheticCuriosityResult suggest({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
    AttentionProfile? attention,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();

    if (instinct.safetyFirst ||
        instinct.avoidOverwhelm ||
        context.userState.cognitiveLoad >= 0.72) {
      return SyntheticCuriosityResult(
        prompt: null,
        memory: _write(
          memory,
          'curiosity_suppressed|load_or_safety',
          0.3,
          timestamp,
        ),
      );
    }

    final CuriosityPrompt prompt = _buildPrompt(
      context: context,
      intent: intent,
      patterns: patterns,
      learning: learning,
      attention: attention,
    );

    final SIMemoryStore nextMemory = _write(
      memory,
      'synthetic_curiosity|${prompt.text}|${prompt.reason}',
      prompt.confidence,
      timestamp,
    );

    return SyntheticCuriosityResult(
      prompt: prompt.safeToShow ? prompt : null,
      memory: nextMemory,
    );
  }

  CuriosityPrompt _buildPrompt({
    required SIContext context,
    required SIIntent intent,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
    AttentionProfile? attention,
  }) {
    if (patterns != null && patterns.patterns.isNotEmpty) {
      final MicroPattern p = patterns.patterns.first;
      return CuriosityPrompt(
        text: 'Want to use that pattern for the next step?',
        reason: p.label,
        confidence: siClamp01(p.confidence),
        safeToShow: p.confidence >= 0.45,
      );
    }

    if ((learning?.resistance ?? 0) >= 0.65) {
      return const CuriosityPrompt(
        text: 'Want me to shrink this into an easier version?',
        reason: 'Adaptive resistance is elevated.',
        confidence: 0.7,
        safeToShow: true,
      );
    }

    if (intent.primary.label == 'get_task' ||
        intent.primary.label == 'start_focus') {
      return const CuriosityPrompt(
        text: 'Want a shorter focus version?',
        reason: 'Action intent detected.',
        confidence: 0.62,
        safeToShow: true,
      );
    }

    if ((attention?.focusScore ?? 0) >= 0.7) {
      return CuriosityPrompt(
        text: 'Want me to keep following this signal?',
        reason: attention!.primaryFocus,
        confidence: attention.focusScore,
        safeToShow: true,
      );
    }

    return const CuriosityPrompt(
      text: 'Want one simple next step?',
      reason: 'Default micro-curiosity prompt.',
      confidence: 0.52,
      safeToShow: true,
    );
  }

  SIMemoryStore _write(
    SIMemoryStore memory,
    String content,
    double confidence,
    DateTime timestamp,
  ) {
    return memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: content,
            timestamp: timestamp,
            relevance: confidence,
            confidence: confidence,
            emotionalWeight: 0.35,
            reinforcement: confidence >= 0.65 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);
  }
}
