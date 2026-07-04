import 'package:fantastic_guacamole/core/services/si_engine_service.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';

class CreatorService {
  CreatorService({SIEngineService? siEngine})
      : _siEngine = siEngine; // ignore: prefer_initializing_formals

  final SIEngineService? _siEngine;

  Future<List<String>> decomposeGoal(String goal) async {
    final SIEngineService? engine = _siEngine;
    if (engine == null || goal.trim().isEmpty) return <String>[goal];
    final SiDecisionEntity decision = await engine.think(
      'decompose goal: $goal',
    );
    if (decision.orderedTaskIds.isNotEmpty) return decision.orderedTaskIds;
    return decision.shouldSimplify
        ? <String>['Start with the smallest part of: $goal']
        : <String>[
            'Define: $goal',
            'Plan the first action',
            'Execute one focused session',
          ];
  }
}
