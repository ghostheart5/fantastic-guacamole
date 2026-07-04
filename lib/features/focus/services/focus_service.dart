import 'package:fantastic_guacamole/core/services/si_engine_service.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/engine/optimizer/optimization_config.dart';

class FocusService {
  FocusService({
    SIEngineService? siEngine,
    OptimizationConfig? optimizationConfig,
  })  : _siEngine = siEngine, // ignore: prefer_initializing_formals
        _optimizationConfig = optimizationConfig; // ignore: prefer_initializing_formals

  final SIEngineService? _siEngine;
  final OptimizationConfig? _optimizationConfig;

  Future<int> recommendedSessionMinutes() async {
    final SIEngineService? engine = _siEngine;
    final int base;
    if (engine == null) {
      base = 25;
    } else {
      final SiDecisionEntity decision = await engine.think(
        'start focus session',
      );
      base = decision.recommendedFocusMinutes;
    }
    final double multiplier =
        _optimizationConfig?.focusDurationMultiplier ?? 1.0;
    return (base * multiplier).round().clamp(10, 90);
  }

  int defaultSessionMinutes(int level) {
    if (level < 3) return 10;
    if (level < 6) return 20;
    return 45;
  }
}
