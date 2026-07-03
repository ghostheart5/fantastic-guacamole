import 'package:fantastic_guacamole/core/services/si_engine_service.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';

class FocusService {
  FocusService({SIEngineService? siEngine}) : _siEngine = siEngine;

  final SIEngineService? _siEngine;

  Future<int> recommendedSessionMinutes() async {
    final SIEngineService? engine = _siEngine;
    if (engine == null) return 25;
    final SiDecisionEntity decision =
        await engine.think('start focus session');
    return decision.recommendedFocusMinutes;
  }

  int defaultSessionMinutes(int level) {
    if (level < 3) return 10;
    if (level < 6) return 20;
    return 45;
  }
}
