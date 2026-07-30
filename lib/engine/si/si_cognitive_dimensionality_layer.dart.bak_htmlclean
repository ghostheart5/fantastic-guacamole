// lib/engine/si/si_cognitive_dimensionality_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class CognitiveDimension {
  const CognitiveDimension({
    required this.name,
    required this.value,
    required this.reason,
  });

  final String name;
  final double value;
  final String reason;
}

class DimensionalityProfile {
  const DimensionalityProfile({
    required this.dimensions,
    required this.primaryDimension,
    required this.complexity,
    required this.recommendation,
  });

  final List<CognitiveDimension> dimensions;
  final String primaryDimension;
  final double complexity;
  final String recommendation;
}

class SICognitiveDimensionalityLayer {
  const SICognitiveDimensionalityLayer();

  DimensionalityProfile map({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
  }) {
    final List<CognitiveDimension> dims =
        <CognitiveDimension>[
          CognitiveDimension(
            name: 'clarity',
            value: siClamp01(intent.confidence),
            reason: 'Intent confidence.',
          ),
          CognitiveDimension(
            name: 'load',
            value: siClamp01(context.userState.cognitiveLoad),
            reason: 'Cognitive load.',
          ),
          CognitiveDimension(
            name: 'emotion',
            value: siClamp01(context.userState.stress),
            reason: 'Stress pressure.',
          ),
          CognitiveDimension(
            name: 'agency',
            value: instinct.safetyFirst ? 0.45 : 0.8,
            reason: 'Control preservation.',
          ),
          CognitiveDimension(
            name: 'momentum',
            value: siClamp01(context.userState.motivation),
            reason: 'Motivation signal.',
          ),
        ]..sort(
          (CognitiveDimension a, CognitiveDimension b) =>
              b.value.compareTo(a.value),
        );

    final double complexity = siClamp01(
      dims.fold<double>(0, (double s, CognitiveDimension d) => s + d.value) /
          dims.length,
    );

    return DimensionalityProfile(
      dimensions: List<CognitiveDimension>.unmodifiable(dims),
      primaryDimension: dims.first.name,
      complexity: complexity,
      recommendation: complexity >= 0.7 || instinct.avoidOverwhelm
          ? 'compress_to_one_step'
          : 'normal_action_guidance',
    );
  }
}
