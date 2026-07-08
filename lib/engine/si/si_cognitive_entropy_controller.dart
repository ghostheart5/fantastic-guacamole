// lib/engine/si/si_cognitive_entropy_controller.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class EntropyProfile {
  const EntropyProfile({
    required this.variation,
    required this.allowNovelty,
    required this.temperature,
    required this.seed,
  });

  final double variation;
  final bool allowNovelty;
  final double temperature;
  final int seed;
}

class SICognitiveEntropyController {
  const SICognitiveEntropyController();

  EntropyProfile profile({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SIMemoryStore memory = const SIMemoryStore(),
  }) {
    final bool safety = instinct.safetyFirst || instinct.avoidOverwhelm;
    final bool repeated = _recentRepeat(context.input.text, memory);

    double variation = 0.35;

    if (intent.primary.label == 'insight_request') variation += 0.15;
    if (intent.primary.label == 'start_focus') variation -= 0.08;
    if (safety) variation -= 0.2;
    if (repeated) variation += 0.12;
    if (context.userState.emotion == 'confused') variation -= 0.1;

    variation = siClamp01(variation, fallback: 0.35);

    return EntropyProfile(
      variation: variation,
      allowNovelty: !safety && variation >= 0.38,
      temperature: safety ? 0.15 : (0.2 + variation * 0.6),
      seed: _seed(context, intent),
    );
  }

  String chooseVariant({
    required List<String> variants,
    required EntropyProfile profile,
  }) {
    final List<String> usable = variants
        .map(siClean)
        .where((String v) => v.isNotEmpty)
        .toList();

    if (usable.isEmpty) return '';
    if (usable.length == 1 || profile.temperature <= 0.2) return usable.first;

    final int index = profile.seed.abs() % usable.length;
    return usable[index];
  }

  bool _recentRepeat(String text, SIMemoryStore memory) {
    final String clean = siClean(text).toLowerCase();
    if (clean.isEmpty) return false;

    return memory.tiered.shortTerm
        .take(5)
        .any(
          (MemoryRecord r) => siClean(r.content).toLowerCase().contains(clean),
        );
  }

  int _seed(SIContext context, SIIntent intent) {
    final String source =
        '${context.input.text}|${intent.primary.label}|${context.userState.emotion}|${context.input.history.length}';
    int hash = 17;
    for (final int unit in source.codeUnits) {
      hash = 37 * hash + unit;
    }
    return hash;
  }
}
