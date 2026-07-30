// lib/engine/si/si_cognitive_dreamspace_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_entropy_controller.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_load_balancer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_resonance_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_temperature_controller.dart';

class DreamspaceArtifact {
  const DreamspaceArtifact({
    required this.symbol,
    required this.metaphor,
    required this.reframe,
    required this.creativity,
    required this.safeForOutput,
  });

  final String symbol;
  final String metaphor;
  final String reframe;
  final double creativity;
  final bool safeForOutput;
}

class DreamspaceResult {
  const DreamspaceResult({
    required this.artifacts,
    required this.primary,
    required this.memory,
    required this.styleHint,
  });

  final List<DreamspaceArtifact> artifacts;
  final DreamspaceArtifact primary;
  final SIMemoryStore memory;
  final String styleHint;
}

class SICognitiveDreamspaceEngine {
  const SICognitiveDreamspaceEngine();

  DreamspaceResult transform({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    CognitiveTemperature? temperature,
    CognitiveLoadPlan? loadPlan,
    ResonanceProfile? resonance,
    EntropyProfile? entropy,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final double creativity = _creativity(
      context: context,
      instinct: instinct,
      temperature: temperature,
      loadPlan: loadPlan,
      entropy: entropy,
    );

    final bool safe =
        !instinct.safetyFirst &&
        !instinct.avoidOverwhelm &&
        (loadPlan?.detailLevel != CognitiveDetailLevel.minimal);

    final List<DreamspaceArtifact> artifacts = <DreamspaceArtifact>[
      _artifact(
        symbol: _symbol(intent, context),
        metaphor: _metaphor(intent, context, safe),
        reframe: _reframe(intent, context, resonance),
        creativity: creativity,
        safe: safe,
      ),
      _artifact(
        symbol: 'compass',
        metaphor: 'a compass choosing the next useful direction',
        reframe: 'Focus on the next true direction, not the whole map.',
        creativity: creativity * 0.85,
        safe: true,
      ),
    ];

    final DreamspaceArtifact primary = artifacts.first;
    final SIMemoryStore nextMemory = _write(memory, primary, timestamp);

    return DreamspaceResult(
      artifacts: List<DreamspaceArtifact>.unmodifiable(artifacts),
      primary: primary,
      memory: nextMemory,
      styleHint: safe ? 'use_light_metaphor' : 'keep_literal_and_simple',
    );
  }

  String influenceMessage(String message, DreamspaceArtifact artifact) {
    final String clean = siClean(message);
    if (!artifact.safeForOutput ||
        artifact.creativity < 0.35 ||
        clean.isEmpty) {
      return clean;
    }
    return '$clean\n\nThink of it like ${artifact.metaphor}.';
  }

  double _creativity({
    required SIContext context,
    required InstinctGuidance instinct,
    CognitiveTemperature? temperature,
    CognitiveLoadPlan? loadPlan,
    EntropyProfile? entropy,
  }) {
    double value = 0.35;
    value += (temperature?.variation ?? 0.35) * 0.25;
    value += (entropy?.variation ?? 0.35) * 0.25;
    if (context.userState.emotion == 'excited') value += 0.12;
    if (instinct.safetyFirst || instinct.avoidOverwhelm) value -= 0.25;
    if (loadPlan?.detailLevel == CognitiveDetailLevel.minimal) value -= 0.2;
    return siClamp01(value);
  }

  DreamspaceArtifact _artifact({
    required String symbol,
    required String metaphor,
    required String reframe,
    required double creativity,
    required bool safe,
  }) {
    return DreamspaceArtifact(
      symbol: symbol,
      metaphor: metaphor,
      reframe: reframe,
      creativity: siClamp01(creativity),
      safeForOutput: safe,
    );
  }

  String _symbol(SIIntent intent, SIContext context) {
    if (intent.primary.label == 'start_focus') return 'lens';
    if (intent.primary.label == 'get_task') return 'compass';
    if (intent.primary.label == 'reflect') return 'mirror';
    if (intent.primary.label == 'insight_request') return 'constellation';
    if (context.userState.stress >= 0.65) return 'anchor';
    return 'spark';
  }

  String _metaphor(SIIntent intent, SIContext context, bool safe) {
    if (!safe) return 'a small step on solid ground';
    switch (intent.primary.label) {
      case 'start_focus':
        return 'a lens narrowing scattered light into one beam';
      case 'get_task':
        return 'a compass pointing toward the next useful move';
      case 'reflect':
        return 'a mirror showing the pattern without judgment';
      case 'insight_request':
        return 'a constellation connecting separate signals';
      default:
        return context.userState.motivation >= 0.65
            ? 'a spark turning into a controlled flame'
            : 'a lantern lighting the next few steps';
    }
  }

  String _reframe(
    SIIntent intent,
    SIContext context,
    ResonanceProfile? resonance,
  ) {
    if (context.userState.cognitiveLoad >= 0.7) {
      return 'Shrink the field until only the next action remains.';
    }
    if (resonance?.stateLabel == 'momentum') {
      return 'Use the current momentum, but keep the scope contained.';
    }
    if (intent.primary.label == 'reflect') {
      return 'Treat the result as information, not judgment.';
    }
    return 'Translate the situation into one practical next move.';
  }

  SIMemoryStore _write(
    SIMemoryStore memory,
    DreamspaceArtifact artifact,
    DateTime timestamp,
  ) {
    return memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'dreamspace|${artifact.symbol}|${artifact.metaphor}|${artifact.reframe}',
            timestamp: timestamp,
            relevance: artifact.creativity,
            confidence: artifact.safeForOutput ? 0.72 : 0.45,
            emotionalWeight: artifact.safeForOutput ? 0.35 : 0.55,
            reinforcement: artifact.safeForOutput ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);
  }
}
