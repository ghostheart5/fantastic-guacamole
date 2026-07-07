// lib/engine/si/si_synthetic_modality_fusion_layer.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIModalityFusion {
  const SIModalityFusion({
    required this.fusedText,
    required this.modalities,
    required this.confidence,
    required this.memory,
  });
  final String fusedText;
  final List<String> modalities;
  final double confidence;
  final SIMemoryStore memory;
}

class SISyntheticModalityFusionLayer {
  const SISyntheticModalityFusionLayer();

  SIModalityFusion fuse({
    required SIInputPacket input,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final parts = <String>[
      input.text,
      if (input.nonText.voiceToText != null) input.nonText.voiceToText!,
      ...input.nonText.imageLabels,
      ...input.nonText.timeTriggers,
      ...input.nonText.behaviorPatterns,
    ].map(siClean).where((x) => x.isNotEmpty).toList();
    final modalities = <String>[
      if (input.text.trim().isNotEmpty) 'text',
      if (input.nonText.voiceToText != null) 'voice',
      if (input.nonText.imageLabels.isNotEmpty) 'image',
      if (input.nonText.timeTriggers.isNotEmpty) 'time',
      if (input.nonText.behaviorPatterns.isNotEmpty) 'behavior',
    ];
    final confidence = siClamp01(.35 + modalities.length * .12);
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content: 'modality_fusion|modalities=${modalities.join(",")}',
            timestamp: t,
            relevance: confidence,
            confidence: confidence,
            emotionalWeight: .35,
          ),
        )
        .dedupe()
        .decay(t);
    return SIModalityFusion(
      fusedText: parts.join(' '),
      modalities: List.unmodifiable(modalities),
      confidence: confidence,
      memory: next,
    );
  }
}
