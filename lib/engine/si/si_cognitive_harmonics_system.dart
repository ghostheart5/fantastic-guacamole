// lib/engine/si/si_cognitive_harmonics_system.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_compression_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_load_balancer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_temperature_controller.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_dreamspace_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_imagination_core.dart';

class HarmonicBlend {
  const HarmonicBlend({
    required this.creativity,
    required this.clarity,
    required this.safety,
    required this.actionability,
    required this.maxChars,
  });

  final double creativity;
  final double clarity;
  final double safety;
  final double actionability;
  final int maxChars;
}

class HarmonicsResult {
  const HarmonicsResult({
    required this.blend,
    required this.message,
    required this.memory,
    required this.guidance,
  });

  final HarmonicBlend blend;
  final String message;
  final SIMemoryStore memory;
  final String guidance;
}

class SICognitiveHarmonicsSystem {
  const SICognitiveHarmonicsSystem({
    this.compressionEngine = const SICognitiveCompressionEngine(),
  });

  final SICognitiveCompressionEngine compressionEngine;

  HarmonicsResult harmonize({
    required String message,
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    CognitiveTemperature? temperature,
    CognitiveLoadPlan? loadPlan,
    DreamspaceArtifact? dream,
    ImaginationVariation? imagination,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final HarmonicBlend blend = _blend(
      context: context,
      intent: intent,
      instinct: instinct,
      temperature: temperature,
      loadPlan: loadPlan,
    );

    String out = siClean(message, fallback: 'Choose one small next step.');
    if (blend.creativity >= 0.45 && dream != null && dream.safeForOutput) {
      out = '$out\n\n${dream.reframe}';
    }
    if (blend.creativity >= 0.5 &&
        imagination != null &&
        imagination.safeForOutput) {
      out = '$out\n\n${imagination.text}';
    }

    out = _soften(out);
    out = compressionEngine
        .compress(
          out,
          maxChars: blend.maxChars,
          instinct: instinct,
          context: context,
        )
        .text;

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'harmonics|creativity=${blend.creativity.toStringAsFixed(2)}|clarity=${blend.clarity.toStringAsFixed(2)}|message=$out',
            timestamp: timestamp,
            relevance: blend.actionability,
            confidence: blend.clarity,
            emotionalWeight: 1 - blend.safety,
            reinforcement: blend.safety >= 0.7 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return HarmonicsResult(
      blend: blend,
      message: out,
      memory: nextMemory,
      guidance: _guidance(blend),
    );
  }

  HarmonicBlend _blend({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    CognitiveTemperature? temperature,
    CognitiveLoadPlan? loadPlan,
  }) {
    final bool constrained = instinct.safetyFirst || instinct.avoidOverwhelm;
    final double tempVariation = temperature?.variation ?? 0.35;
    final double creativity = constrained
        ? 0.12
        : siClamp01(tempVariation * 0.7 + 0.15);
    final double clarity = constrained
        ? 0.9
        : siClamp01(
            0.65 +
                intent.confidence * 0.2 -
                context.userState.cognitiveLoad * 0.1,
          );
    final double safety = constrained
        ? 0.95
        : siClamp01(0.7 + (1 - context.userState.stress) * 0.15);
    final double actionability = siClamp01(
      intent.primary.label == 'get_task' ||
              intent.primary.label == 'start_focus'
          ? 0.85
          : 0.65,
    );

    int maxChars = 360;
    if (loadPlan?.detailLevel == CognitiveDetailLevel.minimal || constrained) {
      maxChars = 180;
    }
    if (loadPlan?.detailLevel == CognitiveDetailLevel.compact) maxChars = 240;

    return HarmonicBlend(
      creativity: creativity,
      clarity: clarity,
      safety: safety,
      actionability: actionability,
      maxChars: maxChars,
    );
  }

  String _soften(String text) {
    return text
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could');
  }

  String _guidance(HarmonicBlend blend) {
    if (blend.safety >= 0.9) return 'Safety and clarity dominate.';
    if (blend.creativity >= 0.5) {
      return 'Creative tone is allowed, but keep action clear.';
    }
    if (blend.clarity >= 0.8) return 'Direct guidance is preferred.';
    return 'Balance clarity with gentle support.';
  }
}
