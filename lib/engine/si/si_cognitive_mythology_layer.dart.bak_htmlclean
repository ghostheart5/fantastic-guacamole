// lib/engine/si/si_cognitive_mythology_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_resonance_engine.dart';

enum SIArchetype { guide, builder, seeker, guardian, analyst, restorer }

class MythicConstruct {
  const MythicConstruct({
    required this.archetype,
    required this.symbol,
    required this.meaning,
    required this.safeNarrative,
    required this.intensity,
  });

  final SIArchetype archetype;
  final String symbol;
  final String meaning;
  final String safeNarrative;
  final double intensity;
}

class MythologyResult {
  const MythologyResult({
    required this.construct,
    required this.memory,
    required this.responsePrefix,
  });

  final MythicConstruct construct;
  final SIMemoryStore memory;
  final String responsePrefix;
}

class SICognitiveMythologyLayer {
  const SICognitiveMythologyLayer();

  MythologyResult build({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    ResonanceProfile? resonance,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final SIArchetype archetype = _archetype(context, intent, instinct);
    final bool constrained = instinct.safetyFirst || instinct.avoidOverwhelm;

    final MythicConstruct construct = MythicConstruct(
      archetype: archetype,
      symbol: _symbol(archetype),
      meaning: _meaning(archetype, resonance),
      safeNarrative: _narrative(archetype, constrained),
      intensity: constrained ? 0.25 : _intensity(context, resonance),
    );

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.midTerm,
          MemoryRecord(
            content:
                'mythology|${construct.archetype.name}|${construct.symbol}|${construct.meaning}',
            timestamp: timestamp,
            relevance: construct.intensity,
            confidence: 0.68,
            emotionalWeight: constrained ? 0.6 : 0.35,
            reinforcement: constrained ? 0 : 1,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return MythologyResult(
      construct: construct,
      memory: nextMemory,
      responsePrefix: constrained ? '' : construct.safeNarrative,
    );
  }

  SIArchetype _archetype(
    SIContext context,
    SIIntent intent,
    InstinctGuidance instinct,
  ) {
    if (instinct.safetyFirst) return SIArchetype.guardian;
    if (context.userState.fatigue >= 0.68) return SIArchetype.restorer;
    switch (intent.primary.label) {
      case 'get_task':
      case 'start_focus':
        return SIArchetype.builder;
      case 'reflect':
        return SIArchetype.seeker;
      case 'insight_request':
        return SIArchetype.analyst;
      default:
        return SIArchetype.guide;
    }
  }

  String _symbol(SIArchetype archetype) {
    switch (archetype) {
      case SIArchetype.guide:
        return 'lantern';
      case SIArchetype.builder:
        return 'forge';
      case SIArchetype.seeker:
        return 'mirror';
      case SIArchetype.guardian:
        return 'anchor';
      case SIArchetype.analyst:
        return 'constellation';
      case SIArchetype.restorer:
        return 'hearth';
    }
  }

  String _meaning(SIArchetype archetype, ResonanceProfile? resonance) {
    final String state = resonance?.stateLabel ?? 'steady';
    switch (archetype) {
      case SIArchetype.builder:
        return 'Turn intention into one useful action in the $state state.';
      case SIArchetype.guardian:
        return 'Protect clarity, agency, and emotional safety.';
      case SIArchetype.restorer:
        return 'Restore capacity before increasing output.';
      case SIArchetype.analyst:
        return 'Connect patterns without overwhelming the user.';
      case SIArchetype.seeker:
        return 'Reflect without judgment and find the next lesson.';
      case SIArchetype.guide:
        return 'Light the next step without forcing the path.';
    }
  }

  String _narrative(SIArchetype archetype, bool constrained) {
    if (constrained) return '';
    switch (archetype) {
      case SIArchetype.builder:
        return 'Builder mode: shape the next action.';
      case SIArchetype.guardian:
        return 'Guardian mode: protect the pace.';
      case SIArchetype.restorer:
        return 'Restorer mode: lower the load.';
      case SIArchetype.analyst:
        return 'Analyst mode: read the pattern.';
      case SIArchetype.seeker:
        return 'Seeker mode: learn from the moment.';
      case SIArchetype.guide:
        return 'Guide mode: follow the next clear signal.';
    }
  }

  double _intensity(SIContext context, ResonanceProfile? resonance) {
    return siClamp01(
      0.35 +
          context.userState.motivation * 0.25 +
          (resonance?.alignmentScore ?? 0.5) * 0.25,
    );
  }
}
