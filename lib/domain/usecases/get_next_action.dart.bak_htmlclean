import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';

class GetNextAction {
  GetNextAction(this._siEngine);

  final SIEngineService _siEngine;

  Future<SiDecisionEntity> call() async {
    final output = await _siEngine.handleText('what should the user do next?');
    return SiDecisionEntity(
      selectedTaskId: output.decision.task?.id,
      rationale: output.decision.reasoning,
      action: output.decision.action,
      shouldTakeBreak: false,
      reasoningTrace: output.core.cognition.summary,
    );
  }
}
