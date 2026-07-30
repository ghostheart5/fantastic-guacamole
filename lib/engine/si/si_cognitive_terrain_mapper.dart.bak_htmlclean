// lib/engine/si/si_cognitive_terrain_mapper.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum TerrainZone { clear, friction, overload, uncertainty, momentum }

class TerrainMap {
  const TerrainMap({
    required this.zone,
    required this.difficulty,
    required this.friction,
    required this.clarity,
    required this.path,
  });

  final TerrainZone zone;
  final double difficulty;
  final double friction;
  final double clarity;
  final String path;
}

class SICognitiveTerrainMapper {
  const SICognitiveTerrainMapper();

  TerrainMap map({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SICognitionState? cognition,
  }) {
    final double load = siClamp01(context.userState.cognitiveLoad);
    final double stress = siClamp01(context.userState.stress);
    final double risk = siClamp01(
      cognition?.meta.misunderstandingRisk ?? 1 - intent.confidence,
    );
    final double clarity = siClamp01((intent.confidence + (1 - risk)) / 2);
    final double friction = siClamp01(
      (load * 0.35) + (stress * 0.35) + (risk * 0.3),
    );
    final double difficulty = siClamp01((friction + (1 - clarity)) / 2);

    final TerrainZone zone = instinct.safetyFirst || load >= 0.75
        ? TerrainZone.overload
        : clarity < 0.5
        ? TerrainZone.uncertainty
        : friction >= 0.62
        ? TerrainZone.friction
        : context.userState.motivation >= 0.68
        ? TerrainZone.momentum
        : TerrainZone.clear;

    return TerrainMap(
      zone: zone,
      difficulty: difficulty,
      friction: friction,
      clarity: clarity,
      path: _path(zone),
    );
  }

  String _path(TerrainZone zone) {
    switch (zone) {
      case TerrainZone.overload:
        return 'Use one small stabilizing step.';
      case TerrainZone.uncertainty:
        return 'Ask for one clarifying detail.';
      case TerrainZone.friction:
        return 'Reduce scope and make the task easier.';
      case TerrainZone.momentum:
        return 'Use the focus window for one action.';
      case TerrainZone.clear:
        return 'Proceed with concise guidance.';
    }
  }
}
