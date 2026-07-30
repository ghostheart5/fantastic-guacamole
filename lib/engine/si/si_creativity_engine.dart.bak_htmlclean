// lib/engine/si/si_creativity_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_harmonics_system.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_load_balancer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_temperature_controller.dart';
import 'package:fantastic_guacamole/engine/si/si_imagination_core.dart';
import 'package:fantastic_guacamole/engine/si/si_user_narrative_engine.dart';

class CreativityResult {
  const CreativityResult({
    required this.message,
    required this.creativity,
    required this.memory,
    required this.applied,
  });

  final String message;
  final double creativity;
  final SIMemoryStore memory;
  final bool applied;
}

class SICreativityEngine {
  const SICreativityEngine({
    this.imaginationCore = const SIImaginationCore(),
    this.harmonicsSystem = const SICognitiveHarmonicsSystem(),
  });

  final SIImaginationCore imaginationCore;
  final SICognitiveHarmonicsSystem harmonicsSystem;

  CreativityResult apply({
    required String message,
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    UserNarrative? narrative,
    CognitiveTemperature? temperature,
    CognitiveLoadPlan? loadPlan,
    DateTime? now,
  }) {
    final ImaginationResult imagination = imaginationCore.generate(
      context: context,
      intent: intent,
      instinct: instinct,
      memory: memory,
      seedText: message,
      temperature: temperature,
      now: now,
    );

    String out = message;
    final bool allowed =
        !instinct.safetyFirst &&
        !instinct.avoidOverwhelm &&
        (temperature?.variation ?? 0.35) >= 0.35;

    if (allowed) {
      out = imaginationCore.applyVariation(out, imagination.selected);
      if (narrative != null && !out.contains('Narrative frame')) {
        out = '$out\n\n${_narrativeHint(narrative)}';
      }
    }

    final HarmonicsResult harmonics = harmonicsSystem.harmonize(
      message: out,
      context: context,
      intent: intent,
      instinct: instinct,
      memory: imagination.memory,
      temperature: temperature,
      loadPlan: loadPlan,
      imagination: imagination.selected,
    );

    return CreativityResult(
      message: harmonics.message,
      creativity: harmonics.blend.creativity,
      memory: harmonics.memory,
      applied: allowed,
    );
  }

  String _narrativeHint(UserNarrative narrative) {
    if (narrative.archetype == 'builder') {
      return 'Narrative frame: turn this into one concrete action.';
    }
    if (narrative.archetype == 'restorer') {
      return 'Narrative frame: protect capacity and rebuild rhythm.';
    }
    return 'Narrative frame: keep the next step clear and grounded.';
  }
}
