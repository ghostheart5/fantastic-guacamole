// lib/engine/si/si_ritual_system.dart// lib/engine/si/si_ritual_system.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIRitualStep {
  const SIRitualStep({
    required this.title,
    required this.action,
    required this.minutes,
  });

  final String title;
  final String action;
  final int minutes;
}

class SIRitualPlan {
  const SIRitualPlan({
    required this.name,
    required this.trigger,
    required this.steps,
    required this.confidence,
    required this.memory,
  });

  final String name;
  final String trigger;
  final List<SIRitualStep> steps;
  final double confidence;
  final SIMemoryStore memory;
}

class SIRitualSystem {
  const SIRitualSystem();

  SIRitualPlan plan({
    required SIContext context,
    required SIMemoryStore memory,
    String? goal,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final bool recovery =
        context.userState.fatigue >= .68 || context.userState.stress >= .7;
    final String name = recovery ? 'recovery_reset' : 'focus_start';
    final List<SIRitualStep> steps = recovery
        ? const <SIRitualStep>[
            SIRitualStep(
              title: 'Lower pressure',
              action: 'Pick the smallest possible version.',
              minutes: 2,
            ),
            SIRitualStep(
              title: 'Reset scope',
              action: 'Choose one task or pause point.',
              minutes: 3,
            ),
          ]
        : const <SIRitualStep>[
            SIRitualStep(
              title: 'Choose target',
              action: 'Name the one task.',
              minutes: 1,
            ),
            SIRitualStep(
              title: 'Start block',
              action: 'Work for one short focus block.',
              minutes: 10,
            ),
          ];

    final double confidence = recovery
        ? siClamp01(context.userState.fatigue)
        : siClamp01(context.userState.engagement);

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.longTerm,
          MemoryRecord(
            content:
                'ritual_plan|$name|trigger=${recovery ? 'fatigue_or_stress' : 'focus_ready'}|goal=${siClean(goal)}',
            timestamp: t,
            relevance: confidence,
            confidence: .72,
            emotionalWeight: context.userState.stress,
            reinforcement: confidence >= .7 ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(t);

    return SIRitualPlan(
      name: name,
      trigger: recovery ? 'fatigue_or_stress' : 'focus_ready',
      steps: List<SIRitualStep>.unmodifiable(steps),
      confidence: confidence,
      memory: next,
    );
  }
}
