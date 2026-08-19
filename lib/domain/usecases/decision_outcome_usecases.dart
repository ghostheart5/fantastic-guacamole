import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';

class GetDecisionOutcomes {
  const GetDecisionOutcomes(this.repository);

  final IDecisionOutcomeRepository repository;

  Future<List<DecisionOutcomeEntity>> call() => repository.load();
}

class RecordDecisionOutcome {
  const RecordDecisionOutcome(this.repository);

  final IDecisionOutcomeRepository repository;

  Future<void> call(DecisionOutcomeEntity outcome) {
    if (outcome.decisionId.trim().isEmpty || outcome.surface.trim().isEmpty) {
      throw ArgumentError('Decision outcome identity must not be empty.');
    }
    return repository.record(outcome);
  }
}
