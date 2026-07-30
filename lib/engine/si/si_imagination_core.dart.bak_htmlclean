// lib/engine/si/si_imagination_core.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_entropy_controller.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_temperature_controller.dart';

class ImaginationVariation {
  const ImaginationVariation({
    required this.text,
    required this.angle,
    required this.creativity,
    required this.safeForOutput,
  });

  final String text;
  final String angle;
  final double creativity;
  final bool safeForOutput;
}

class ImaginationResult {
  const ImaginationResult({
    required this.variations,
    required this.selected,
    required this.memory,
  });

  final List<ImaginationVariation> variations;
  final ImaginationVariation selected;
  final SIMemoryStore memory;
}

class SIImaginationCore {
  const SIImaginationCore();

  ImaginationResult generate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    String seedText = '',
    CognitiveTemperature? temperature,
    EntropyProfile? entropy,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final String base = siClean(seedText, fallback: context.input.text);
    final double creativity = _creativity(
      context,
      instinct,
      temperature,
      entropy,
    );
    final bool safe = !instinct.safetyFirst && !instinct.avoidOverwhelm;

    final List<ImaginationVariation> variations = <ImaginationVariation>[
      ImaginationVariation(
        text: _practical(base, intent),
        angle: 'practical',
        creativity: 0.2,
        safeForOutput: true,
      ),
      ImaginationVariation(
        text: safe ? _metaphoric(base, intent) : _practical(base, intent),
        angle: 'metaphoric',
        creativity: creativity,
        safeForOutput: safe,
      ),
      ImaginationVariation(
        text: _minimal(base),
        angle: 'minimal',
        creativity: 0.1,
        safeForOutput: true,
      ),
    ];

    final ImaginationVariation selected = _select(
      variations,
      entropy,
      instinct,
      creativity,
    );

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: 'imagination|${selected.angle}|${selected.text}',
            timestamp: timestamp,
            relevance: selected.creativity,
            confidence: selected.safeForOutput ? 0.7 : 0.45,
            emotionalWeight: instinct.safetyFirst ? 0.65 : 0.35,
            reinforcement: selected.safeForOutput ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return ImaginationResult(
      variations: List<ImaginationVariation>.unmodifiable(variations),
      selected: selected,
      memory: nextMemory,
    );
  }

  String applyVariation(String message, ImaginationVariation variation) {
    if (!variation.safeForOutput || variation.creativity < 0.3) {
      return siClean(message);
    }
    return '${siClean(message)}\n\n${variation.text}';
  }

  double _creativity(
    SIContext context,
    InstinctGuidance instinct,
    CognitiveTemperature? temperature,
    EntropyProfile? entropy,
  ) {
    double value =
        0.35 +
        (temperature?.variation ?? 0.3) * 0.3 +
        (entropy?.variation ?? 0.3) * 0.25;
    if (context.userState.emotion == 'excited') value += 0.1;
    if (instinct.safetyFirst || instinct.avoidOverwhelm) value -= 0.28;
    return siClamp01(value);
  }

  ImaginationVariation _select(
    List<ImaginationVariation> variations,
    EntropyProfile? entropy,
    InstinctGuidance instinct,
    double creativity,
  ) {
    if (instinct.safetyFirst || instinct.avoidOverwhelm || creativity < 0.28) {
      return variations.firstWhere(
        (ImaginationVariation v) => v.angle == 'minimal',
      );
    }
    final int index = (entropy?.seed.abs() ?? 0) % variations.length;
    return variations[index];
  }

  String _practical(String base, SIIntent intent) {
    if (intent.primary.label == 'get_task') {
      return 'Reframe it as: choose the next smallest useful task.';
    }
    if (intent.primary.label == 'start_focus') {
      return 'Reframe it as: protect one short focus block.';
    }
    return 'Reframe it as: turn the idea into one clear next action.';
  }

  String _metaphoric(String base, SIIntent intent) {
    if (intent.primary.label == 'insight_request') {
      return 'Creative frame: connect the signals like a small constellation.';
    }
    if (intent.primary.label == 'reflect') {
      return 'Creative frame: treat the moment like a mirror, not a verdict.';
    }
    return 'Creative frame: make the next step the doorway, not the whole journey.';
  }

  String _minimal(String base) => 'Simpler frame: one step, then reassess.';
}
