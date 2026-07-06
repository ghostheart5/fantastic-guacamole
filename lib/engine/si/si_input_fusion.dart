// lib/engine/si/si_input_fusion.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIInputFusionResult {
  const SIInputFusionResult({
    required this.packet,
    required this.fusedText,
    required this.signalCount,
    required this.confidence,
  });

  final SIInputPacket packet;
  final String fusedText;
  final int signalCount;
  final double confidence;
}

class SIInputFusionEngine {
  const SIInputFusionEngine();

  SIInputFusionResult fuse(SIInputPacket input) {
    final List<String> parts = <String>[
      input.text,
      if (input.nonText.voiceToText != null) input.nonText.voiceToText!,
      ...input.nonText.imageLabels,
      ...input.nonText.timeTriggers,
      ...input.nonText.behaviorPatterns,
    ].map(siClean).where((String s) => s.isNotEmpty).toList();

    final String fused = parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final int count =
        parts.length + input.metadata.length + input.context.length;

    return SIInputFusionResult(
      packet: SIInputPacket(
        text: fused.isEmpty ? input.text : fused,
        history: input.history,
        metadata: input.metadata,
        context: input.context,
        nonText: input.nonText,
        latent: input.latent,
      ),
      fusedText: fused,
      signalCount: count,
      confidence: siClamp01(.35 + count * .06),
    );
  }
}
