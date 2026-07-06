// lib/engine/si/si_cognitive_field_theory_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class CognitiveField {
  const CognitiveField({
    required this.name,
    required this.strength,
    required this.polarity,
  });

  final String name;
  final double strength;
  final String polarity;
}

class FieldTheoryResult {
  const FieldTheoryResult({
    required this.fields,
    required this.dominantField,
    required this.netForce,
    required this.guidance,
  });

  final List<CognitiveField> fields;
  final String dominantField;
  final double netForce;
  final String guidance;
}

class SICognitiveFieldTheoryLayer {
  const SICognitiveFieldTheoryLayer();

  FieldTheoryResult calculate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
  }) {
    final List<CognitiveField> fields =
        <CognitiveField>[
          CognitiveField(
            name: 'intent',
            strength: intent.confidence,
            polarity: 'forward',
          ),
          CognitiveField(
            name: 'stress',
            strength: context.userState.stress,
            polarity: 'resistance',
          ),
          CognitiveField(
            name: 'load',
            strength: context.userState.cognitiveLoad,
            polarity: 'resistance',
          ),
          CognitiveField(
            name: 'motivation',
            strength: context.userState.motivation,
            polarity: 'forward',
          ),
          CognitiveField(
            name: 'instinct',
            strength: instinct.safetyFirst ? 0.85 : 0.55,
            polarity: instinct.safetyFirst ? 'stabilize' : 'forward',
          ),
        ]..sort(
          (CognitiveField a, CognitiveField b) =>
              b.strength.compareTo(a.strength),
        );

    double force = 0;
    for (final CognitiveField f in fields) {
      if (f.polarity == 'forward') force += f.strength;
      if (f.polarity == 'resistance') force -= f.strength;
      if (f.polarity == 'stabilize') force -= f.strength * 0.4;
    }

    final double net = siClamp01((force + 2) / 4);

    return FieldTheoryResult(
      fields: List<CognitiveField>.unmodifiable(fields),
      dominantField: fields.first.name,
      netForce: net,
      guidance: net >= 0.65
          ? 'Proceed with one action.'
          : net <= 0.35
          ? 'Reduce scope and stabilize.'
          : 'Proceed carefully with compact guidance.',
    );
  }
}
