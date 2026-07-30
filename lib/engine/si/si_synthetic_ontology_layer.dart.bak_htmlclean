// lib/engine/si/si_synthetic_ontology_layer.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIOntologyMap {
  const SIOntologyMap({
    required this.entities,
    required this.primaryEntity,
    required this.memory,
  });
  final Map<String, String> entities;
  final String primaryEntity;
  final SIMemoryStore memory;
}

class SISyntheticOntologyLayer {
  const SISyntheticOntologyLayer();

  SIOntologyMap map({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final e = <String, String>{
      'intent': intent.primary.label,
      'emotion': context.userState.emotion,
      'stability': context.userState.stability,
      'instinct': instinct.primaryInstinct,
    };
    final primary = instinct.safetyFirst ? 'instinct' : 'intent';
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'ontology|primary=$primary|${e.entries.map((x) => '${x.key}=${x.value}').join("|")}',
            timestamp: t,
            relevance: intent.confidence,
            confidence: .7,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SIOntologyMap(
      entities: Map.unmodifiable(e),
      primaryEntity: primary,
      memory: next,
    );
  }
}
