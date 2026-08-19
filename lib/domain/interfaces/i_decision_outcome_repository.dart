import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';

abstract interface class IDecisionOutcomeRepository {
  Future<List<DecisionOutcomeEntity>> load();

  Future<void> record(DecisionOutcomeEntity outcome);
}
