import 'package:fantastic_guacamole/core/services/si_engine_service.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';

class CoachService {
  CoachService({SIEngineService? siEngine})
      : _siEngine = siEngine; // ignore: prefer_initializing_formals

  final SIEngineService? _siEngine;

  Future<String> nextAction() async {
    if (_siEngine == null) return 'Keep building momentum.';
    final SiDecisionEntity decision = await _siEngine.think(
      'what should user do next?',
    );
    return decision.action.isNotEmpty ? decision.action : decision.rationale;
  }
}
