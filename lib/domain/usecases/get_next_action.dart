import 'package:fantastic_guacamole/core/services/si_engine_service.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';

class GetNextAction {
  GetNextAction(this._siEngine);

  final SIEngineService _siEngine;

  Future<SiDecisionEntity> call() =>
      _siEngine.think('what should the user do next?');
}
