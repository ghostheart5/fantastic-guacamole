// lib/engine/si/si_cognitive_civilization_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class CivilizationNorm {
  const CivilizationNorm({
    required this.name,
    required this.weight,
    required this.description,
  });

  final String name;
  final double weight;
  final String description;
}

class CivilizationReport {
  const CivilizationReport({
    required this.norms,
    required this.alignment,
    required this.cultureMode,
    required this.memory,
  });

  final List<CivilizationNorm> norms;
  final double alignment;
  final String cultureMode;
  final SIMemoryStore memory;
}

class SICognitiveCivilizationLayer {
  const SICognitiveCivilizationLayer();

  CivilizationReport evaluate({
    required SIContext context,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final List<CivilizationNorm> norms = <CivilizationNorm>[
      const CivilizationNorm(
        name: 'agency',
        weight: 0.9,
        description: 'Preserve user control.',
      ),
      CivilizationNorm(
        name: 'clarity',
        weight: instinct.reduceConfusion ? 0.9 : 0.7,
        description: 'Reduce confusion.',
      ),
      CivilizationNorm(
        name: 'calm',
        weight: instinct.safetyFirst ? 0.95 : 0.65,
        description: 'Keep tone grounded.',
      ),
      CivilizationNorm(
        name: 'action',
        weight: instinct.encourageProgress ? 0.7 : 0.45,
        description: 'Favor one next step.',
      ),
    ];

    final double alignment = siClamp01(
      norms.fold<double>(
            0,
            (double s, CivilizationNorm n) => s + siClamp01(n.weight),
          ) /
          norms.length,
    );

    final String mode = instinct.safetyFirst || context.userState.stress >= 0.7
        ? 'guardian_culture'
        : context.userState.motivation >= 0.7
        ? 'builder_culture'
        : 'steady_culture';

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'civilization|mode=$mode|alignment=${alignment.toStringAsFixed(2)}',
            timestamp: t,
            relevance: alignment,
            confidence: 0.74,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement: alignment >= 0.75 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);

    return CivilizationReport(
      norms: List<CivilizationNorm>.unmodifiable(norms),
      alignment: alignment,
      cultureMode: mode,
      memory: next,
    );
  }
}
