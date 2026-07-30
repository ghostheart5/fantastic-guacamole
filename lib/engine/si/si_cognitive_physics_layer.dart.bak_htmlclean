// lib/engine/si/si_cognitive_physics_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class CognitiveForce {
  const CognitiveForce({
    required this.name,
    required this.magnitude,
    required this.direction,
  });

  final String name;
  final double magnitude;
  final String direction;
}

class CognitiveMotion {
  const CognitiveMotion({
    required this.forces,
    required this.velocity,
    required this.friction,
    required this.resultant,
    required this.guidance,
  });

  final List<CognitiveForce> forces;
  final double velocity;
  final double friction;
  final double resultant;
  final String guidance;
}

class SICognitivePhysicsLayer {
  const SICognitivePhysicsLayer();

  CognitiveMotion simulate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
  }) {
    final List<CognitiveForce> forces = <CognitiveForce>[
      CognitiveForce(
        name: 'intent',
        magnitude: intent.confidence,
        direction: 'forward',
      ),
      CognitiveForce(
        name: 'motivation',
        magnitude: context.userState.motivation,
        direction: 'forward',
      ),
      CognitiveForce(
        name: 'stress',
        magnitude: context.userState.stress,
        direction: 'resist',
      ),
      CognitiveForce(
        name: 'load',
        magnitude: context.userState.cognitiveLoad,
        direction: 'resist',
      ),
      CognitiveForce(
        name: 'instinct',
        magnitude: instinct.safetyFirst ? 0.85 : 0.45,
        direction: instinct.safetyFirst ? 'stabilize' : 'forward',
      ),
      CognitiveForce(
        name: 'risk',
        magnitude: cognition?.meta.misunderstandingRisk ?? 0.35,
        direction: 'resist',
      ),
    ];

    double forward = 0;
    double resist = 0;
    for (final CognitiveForce f in forces) {
      if (f.direction == 'forward') forward += f.magnitude;
      if (f.direction == 'resist') resist += f.magnitude;
      if (f.direction == 'stabilize') resist += f.magnitude * 0.45;
    }

    final double friction = siClamp01(
      (context.userState.fatigue + context.userState.cognitiveLoad) / 2,
    );
    final double velocity = siClamp01(
      (forward / 3) - (resist / 4) - friction * 0.15 + 0.45,
    );
    final double resultant = siClamp01((velocity + (1 - friction)) / 2);

    return CognitiveMotion(
      forces: List<CognitiveForce>.unmodifiable(forces),
      velocity: velocity,
      friction: friction,
      resultant: resultant,
      guidance: resultant >= 0.68
          ? 'Proceed with one clear action.'
          : resultant <= 0.38
          ? 'Stabilize and reduce scope.'
          : 'Move carefully with compact guidance.',
    );
  }
}
